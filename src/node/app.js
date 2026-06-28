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
const proxy = require('@fastify/http-proxy');

fastify.register(proxy, {
    upstream: FORWARD_URL,
    prefix: '/',  // Prefix vacío para hacer proxy de todo
    http: {
        // Opciones de conexión
    }
});

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
