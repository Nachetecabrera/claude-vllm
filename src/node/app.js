// Claude vLLM Proxy - Node.js
// Requiere: npm install fastify @fastify/http-proxy

const fs = require('fs');
const path = require('path');

// Buscar config.json en múltiples ubicaciones
const scriptDir = __dirname;
const possiblePaths = [
    path.join(scriptDir, 'config.json'),          // Same dir as app.js
    path.join(scriptDir, '..', 'config.json'),    // Parent dir
    path.join(scriptDir, '..', '..', 'config.json'), // Two dirs up
];

let config = {};
for (const configPath of possiblePaths) {
    if (fs.existsSync(configPath)) {
        try {
            config = JSON.parse(fs.readFileSync(configPath, 'utf8'));
            console.log('Loaded config.json:', Object.keys(config));
            break; // Use first found config
        } catch (e) {
            console.warn('Failed to parse config.json:', e.message);
        }
    }
}

// Configuración
const LISTEN_IP = config.listen_ip || '0.0.0.0';
const LISTEN_PORT = parseInt(config.listen_port || 8010, 10);
const FORWARD_URL = config.forward_url || 'http://localhost:8000';
const LOG_LEVEL = config.log_level || 'INFO';

// Iniciar servidor con Fastify
const fastify = require('fastify')({ logger: true });
const http = require('http');

const HOP_BY_HOP_HEADERS = new Set([
    'connection',
    'keep-alive',
    'proxy-authenticate',
    'proxy-authorization',
    'te',
    'trailer',
    'transfer-encoding',
    'upgrade',
]);

// Configuración de system_mode
const SYSTEM_MODE = config.system_mode || 'hoist';

function forwardToUpstream(upstream, path, method, headers, bodyStr) {
    return new Promise((resolve, reject) => {
        const options = {
            hostname: upstream.hostname,
            port: upstream.port || 80,
            path: path,
            method: method,
            headers: headers,
        };
        if (bodyStr) {
            options.headers['content-length'] = Buffer.byteLength(bodyStr);
        }
        const req = http.request(options, (res) => resolve(res));
        req.on('error', reject);
        req.setTimeout(120000, () => {
            req.destroy();
            reject(new Error('Upstream timeout'));
        });
        if (bodyStr) {
            req.write(bodyStr);
        }
        req.end();
    });
}

// Catch-all proxy route (como app.py)
fastify.route({
    method: ['GET', 'POST', 'PUT', 'PATCH', 'DELETE', 'OPTIONS', 'HEAD'],
    url: '/*',
    handler: async function (request, reply) {
        const upstream = new URL(FORWARD_URL);
        const targetPath = request.raw.url;

        const proxyHeaders = {};
        for (const [key, value] of Object.entries(request.headers)) {
            if (HOP_BY_HOP_HEADERS.has(key) || key === 'content-length') continue;
            if (value !== undefined && value !== null) {
                proxyHeaders[key] = value;
            }
        }

        proxyHeaders['x-forwarded-proto'] = request.protocol;
        proxyHeaders['x-forwarded-host'] = request.hostname;
        if (request.ip) {
            const existing = proxyHeaders['x-forwarded-for'];
            proxyHeaders['x-forwarded-for'] = existing ? existing + ', ' + request.ip : request.ip;
        }

        let bodyStr = null;
        if (request.body) {
            let payload = request.body;

            if (request.method === 'POST' && request.url.startsWith('/v1/messages')) {
                try {
                    if (typeof payload !== 'object' || payload === null) {
                        throw new Error("El cuerpo JSON debe ser un objeto");
                    }
                    const { body: normalizedBody, stats } = normalizeAnthropicRequest(payload);
                    payload = normalizedBody;

                    if (LOG_LEVEL !== 'ERROR') {
                        console.log(
                            'Solicitud normalizada model=' + normalizedBody.model +
                            ' stream=' + normalizedBody.stream +
                            ' roles=' + JSON.stringify(stats.originalRoles) +
                            '->' + JSON.stringify(stats.normalizedRoles) +
                            ' system_hoisted=' + stats.hoistedSystemMessages +
                            ' dropped=' + JSON.stringify(stats.removedTopLevel) +
                            ' tool_fields=' + JSON.stringify(stats.removedToolFields)
                        );
                    }
                } catch (e) {
                    console.warn('Solicitud rechazada por el proxy:', e.message);
                    return reply.code(400).send({
                        type: 'error',
                        error: {
                            type: 'invalid_request_error',
                            message: e.message
                        }
                    });
                }
            }

            bodyStr = JSON.stringify(payload);
            proxyHeaders['content-type'] = 'application/json';
        }

        let proxyRes;
        try {
            proxyRes = await forwardToUpstream(upstream, targetPath, request.method, proxyHeaders, bodyStr);
        } catch (e) {
            console.error('No se pudo conectar con vLLM:', e.message);
            return reply.code(502).send({
                type: 'error',
                error: {
                    type: 'upstream_connection_error',
                    message: e.message
                }
            });
        }

        const responseHeaders = {};
        for (const [key, value] of Object.entries(proxyRes.headers)) {
            if (HOP_BY_HOP_HEADERS.has(key.toLowerCase()) || key.toLowerCase() === 'content-length') continue;
            if (value) {
                if (Array.isArray(value)) {
                    responseHeaders[key] = value.join(', ');
                } else {
                    responseHeaders[key] = value;
                }
            }
        }

        reply.hijack();
        const rawRes = reply.raw;
        rawRes.writeHead(proxyRes.statusCode, responseHeaders);
        proxyRes.on('error', (err) => {
            if (!rawRes.headersSent) {
                rawRes.writeHead(502, { 'content-type': 'application/json' });
                rawRes.end(JSON.stringify({
                    type: 'error',
                    error: { type: 'upstream_stream_error', message: err.message }
                }));
            } else {
                rawRes.end();
            }
        });
        proxyRes.pipe(rawRes);
    }
});

function contentToText(content) {
    if (content === null || content === undefined) {
        return '';
    }

    if (typeof content === 'string') {
        return content;
    }

    if (Array.isArray(content)) {
        const parts = [];
        for (const block of content) {
            if (typeof block === 'string') {
                parts.push(block);
            } else if (block && typeof block === 'object') {
                if (typeof block.text === 'string') {
                    parts.push(block.text);
                } else {
                    parts.push(JSON.stringify(block));
                }
            } else {
                parts.push(String(block));
            }
        }
        return parts.filter(p => p).join('\n');
    }

    if (typeof content === 'object') {
        if (typeof content.text === 'string') {
            return content.text;
        }
        return JSON.stringify(content);
    }

    return String(content);
}

function mergeSystem(existing, additions) {
    const parts = [];

    const existingText = contentToText(existing);
    if (existingText) {
        parts.push(existingText);
    }

    for (const text of additions) {
        if (text) {
            parts.push(text);
        }
    }
    return parts.join('\n\n');
}

function dropKeyRecursive(value, keyToDrop) {
    if (Array.isArray(value)) {
        return value.map(item => dropKeyRecursive(item, keyToDrop));
    }

    if (value && typeof value === 'object') {
        const result = {};
        for (const key in value) {
            if (Object.prototype.hasOwnProperty.call(value, key) && key !== keyToDrop) {
                result[key] = dropKeyRecursive(value[key], keyToDrop);
            }
        }
        return result;
    }

    return value;
}

function normalizeAnthropicRequest(body) {
    const messages = body.messages;

    if (!Array.isArray(messages)) {
        throw new Error("'messages' debe ser una lista");
    }

    const normalizedMessages = [];
    const hoistedSystem = [];
    const originalRoles = [];

    for (let index = 0; index < messages.length; index++) {
        const message = messages[index];

        if (!message || typeof message !== 'object') {
            throw new Error(`messages[${index}] debe ser un objeto`);
        }

        const role = message.role;
        originalRoles.push(String(role));

        if (role === 'system' || role === 'developer') {
            const text = contentToText(message.content);

            if (SYSTEM_MODE === 'hoist') {
                if (text) {
                    hoistedSystem.push(text);
                }
                continue;
            }

            if (SYSTEM_MODE === 'user') {
                normalizedMessages.push({
                    role: 'user',
                    content: `<system-update>\n${text}\n</system-update>`
                });
                continue;
            }

            throw new Error("SYSTEM_MODE debe ser 'hoist' o 'user'");
        }

        if (role !== 'user' && role !== 'assistant') {
            throw new Error(
                `Rol no compatible en messages[${index}]: ${role}. ` +
                "Solo se corrigen system/developer; los demás roles se rechazan."
            );
        }

        normalizedMessages.push(message);
    }

    body.messages = normalizedMessages;

    if (hoistedSystem.length > 0) {
        body.system = mergeSystem(body.system, hoistedSystem);
    }

    // Drop top-level fields
    const dropTopLevelFields = (config.drop_top_level_fields || 'context_management,output_config,thinking')
        .split(',')
        .map(f => f.trim())
        .filter(f => f);

    for (const field of dropTopLevelFields) {
        delete body[field];
    }

    // Drop tool fields
    const dropToolFields = (config.drop_tool_fields || 'strict,defer_loading')
        .split(',')
        .map(f => f.trim())
        .filter(f => f);

    if (Array.isArray(body.tools)) {
        for (const tool of body.tools) {
            if (tool && typeof tool === 'object') {
                for (const field of dropToolFields) {
                    delete tool[field];
                }
            }
        }
    }

    // Strip cache_control
    if (config.strip_cache_control !== false) {
        body = dropKeyRecursive(body, 'cache_control');
    }

    // Force model
    if (config.model && config.model.trim()) {
        body.model = config.model.trim();
    }

    const stats = {
        model: body.model,
        stream: body.stream,
        messageCountBefore: messages.length,
        messageCountAfter: normalizedMessages.length,
        originalRoles: originalRoles,
        normalizedRoles: normalizedMessages.map(m => m.role),
        hoistedSystemMessages: hoistedSystem.length,
        removedTopLevel: dropTopLevelFields.filter(f => messages.some(m => m[f] !== undefined)),
        removedToolFields: dropToolFields
    };

    return { body, stats };
}

// Ruta de health check
fastify.get('/healthz', async (request, reply) => {
    return {
        status: 'ok',
        upstream: FORWARD_URL,
        force_model: config.model || null,
        system_mode: config.system_mode || null
    };
});

// Ruta de ready check
fastify.get('/readyz', async (request, reply) => {
    // Verificar conexión con upstream
    try {
        const http = require('http');
        const url = new URL(FORWARD_URL);
        const p = new Promise((resolve) => {
            const req = http.request({
                hostname: url.hostname,
                port: url.port || 80,
                path: '/v1/models',
                timeout: 5000
            }, (res) => {
                res.on('end', () => resolve(res.statusCode === 200));
            });
            req.on('error', () => resolve(false));
            req.on('timeout', () => {
                req.destroy();
                resolve(false);
            });
            req.end();
        });
        const ready = await p;
        reply.code(ready ? 200 : 503).send({
            ready,
            upstream: FORWARD_URL
        });
    } catch (e) {
        reply.code(503).send({ ready: false, error: e.message });
    }
});

// Manejo de errores
fastify.setErrorHandler((error, request, reply) => {
    if (error.code === 'FST_ERR_REQUEST_BODY_TIMEOUT') {
        return reply.code(408).send({ error: 'Request timeout' });
    }
    reply.code(500).send({ error: error.message });
});

// Iniciar servidor
fastify.listen({ host: LISTEN_IP, port: LISTEN_PORT }, (err) => {
    if (err) {
        console.error(err);
        process.exit(1);
    }
    console.log(`Proxy started: http://${LISTEN_IP}:${LISTEN_PORT} -> ${FORWARD_URL}`);
});
