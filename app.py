from __future__ import annotations

import socket
import json
import logging
import os
import sys
from contextlib import asynccontextmanager
from typing import Any

import httpx
import uvicorn
from fastapi import FastAPI, Request
from fastapi.responses import JSONResponse, StreamingResponse
from starlette.background import BackgroundTask


def env_csv(name: str, default: str = "") -> set[str]:
    return {
        item.strip()
        for item in os.getenv(name, default).split(",")
        if item.strip()
    }


def env_bool(name: str, default: bool = False) -> bool:
    value = os.getenv(name)
    if value is None:
        return default
    return value.strip().lower() in {"1", "true", "yes", "on"}


def get_config_dir() -> str:
    """Get the directory where config.json is located."""
    if getattr(sys, "frozen", False):
        return sys._MEIPASS
    return os.path.dirname(os.path.abspath(__file__))


def load_config_from_json() -> dict:
    """Load configuration from config.json file."""
    config_path = os.path.join(get_config_dir(), "config.json")

    if not os.path.exists(config_path):
        logger.warning(f"config.json not found at: {config_path}")
        return {}

    try:
        with open(config_path, "r", encoding="utf-8") as f:
            config_data = json.load(f)

        if not isinstance(config_data, dict):
            logger.warning(f"config.json must contain a JSON object, got: {type(config_data).__name__}")
            return {}

        # Log loaded config values (excluding sensitive fields)
        loaded_keys = [k for k in config_data.keys() if not k.lower().endswith("key")]
        logger.info(f"Loaded config from config.json: {loaded_keys}")

        return config_data

    except json.JSONDecodeError as e:
        logger.error(f"Failed to parse config.json: {e}")
    except Exception as e:
        logger.error(f"Failed to load config.json: {e}")

    return {}


# Initialize logging first (before load_config_from_json)
logging.basicConfig(
    level=os.getenv("LOG_LEVEL", "INFO").upper(),
    format="%(asctime)s %(levelname)s %(name)s: %(message)s",
)
logger = logging.getLogger("claude-vllm-proxy")

# Load config first to set environment variables
config = load_config_from_json()

# Now read environment variables (with config values taking precedence)
# Fall back to config.json values if env vars not set
UPSTREAM_URL = os.getenv("UPSTREAM_URL") or config.get("forward_url", "http://localhost:8000").rstrip("/")
UPSTREAM_API_KEY = os.getenv("UPSTREAM_API_KEY", "").strip()
FORCE_MODEL = os.getenv("FORCE_MODEL") or config.get("model", "").strip()

# "hoist": mueve system/developer al campo system superior.
# "user": conserva la posición convirtiéndolo a un mensaje user etiquetado.
SYSTEM_MODE = os.getenv("SYSTEM_MODE") or config.get("system_mode", "hoist").strip().lower()

DROP_TOP_LEVEL_FIELDS = env_csv(
    "DROP_TOP_LEVEL_FIELDS",
    config.get("drop_top_level_fields", "context_management,output_config,thinking"),
)
DROP_TOOL_FIELDS = env_csv(
    "DROP_TOOL_FIELDS",
    config.get("drop_tool_fields", "strict,defer_loading"),
)
STRIP_CACHE_CONTROL = env_bool("STRIP_CACHE_CONTROL", config.get("strip_cache_control", True))

# Proxy server settings
LISTEN_IP = os.getenv("LISTEN_IP", config.get("listen_ip", "0.0.0.0"))
LISTEN_PORT = int(os.getenv("LISTEN_PORT", config.get("listen_port", 8010)))

HOP_BY_HOP_HEADERS = {
    "connection",
    "keep-alive",
    "proxy-authenticate",
    "proxy-authorization",
    "te",
    "trailer",
    "transfer-encoding",
    "upgrade",
}


def content_to_text(content: Any) -> str:
    """Convierte contenido Anthropic a texto sin imprimirlo en logs."""
    if content is None:
        return ""

    if isinstance(content, str):
        return content

    if isinstance(content, list):
        parts: list[str] = []
        for block in content:
            if isinstance(block, str):
                parts.append(block)
            elif isinstance(block, dict):
                if isinstance(block.get("text"), str):
                    parts.append(block["text"])
                else:
                    # Fallback conservador para bloques no textuales.
                    parts.append(json.dumps(block, ensure_ascii=False))
            else:
                parts.append(str(block))
        return "\n".join(part for part in parts if part)

    if isinstance(content, dict):
        if isinstance(content.get("text"), str):
            return content["text"]
        return json.dumps(content, ensure_ascii=False)

    return str(content)


def merge_system(existing: Any, additions: list[str]) -> str:
    parts: list[str] = []

    existing_text = content_to_text(existing)
    if existing_text:
        parts.append(existing_text)

    parts.extend(text for text in additions if text)
    return "\n\n".join(parts)


def drop_key_recursive(value: Any, key_to_drop: str) -> Any:
    if isinstance(value, dict):
        return {
            key: drop_key_recursive(child, key_to_drop)
            for key, child in value.items()
            if key != key_to_drop
        }

    if isinstance(value, list):
        return [drop_key_recursive(child, key_to_drop) for child in value]

    return value


def normalize_anthropic_request(body: dict[str, Any]) -> tuple[dict[str, Any], dict[str, Any]]:
    messages = body.get("messages")

    if not isinstance(messages, list):
        raise ValueError("'messages' debe ser una lista")

    normalized_messages: list[dict[str, Any]] = []
    hoisted_system: list[str] = []
    original_roles: list[str] = []

    for index, message in enumerate(messages):
        if not isinstance(message, dict):
            raise ValueError(f"messages[{index}] debe ser un objeto")

        role = message.get("role")
        original_roles.append(str(role))

        if role in {"system", "developer"}:
            text = content_to_text(message.get("content"))

            if SYSTEM_MODE == "hoist":
                if text:
                    hoisted_system.append(text)
                continue

            if SYSTEM_MODE == "user":
                normalized_messages.append(
                    {
                        "role": "user",
                        "content": f"<system-update>\n{text}\n</system-update>",
                    }
                )
                continue

            raise ValueError("SYSTEM_MODE debe ser 'hoist' o 'user'")

        if role not in {"user", "assistant"}:
            raise ValueError(
                f"Rol no compatible en messages[{index}]: {role!r}. "
                "Solo se corrigen system/developer; los demás roles se rechazan."
            )

        normalized_messages.append(message)

    body["messages"] = normalized_messages

    if hoisted_system:
        body["system"] = merge_system(body.get("system"), hoisted_system)

    removed_top_level: list[str] = []
    for field in DROP_TOP_LEVEL_FIELDS:
        if field in body:
            body.pop(field, None)
            removed_top_level.append(field)

    removed_tool_fields: set[str] = set()
    tools = body.get("tools")
    if isinstance(tools, list):
        for tool in tools:
            if not isinstance(tool, dict):
                continue
            for field in DROP_TOOL_FIELDS:
                if field in tool:
                    tool.pop(field, None)
                    removed_tool_fields.add(field)

    if STRIP_CACHE_CONTROL:
        body = drop_key_recursive(body, "cache_control")

    if FORCE_MODEL:
        body["model"] = FORCE_MODEL

    stats = {
        "model": body.get("model"),
        "stream": body.get("stream"),
        "message_count_before": len(messages),
        "message_count_after": len(normalized_messages),
        "original_roles": original_roles,
        "normalized_roles": [m.get("role") for m in normalized_messages],
        "hoisted_system_messages": len(hoisted_system),
        "removed_top_level": sorted(removed_top_level),
        "removed_tool_fields": sorted(removed_tool_fields),
    }
    return body, stats


def get_local_ip() -> str:
    try:
        s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        s.settimeout(0)
        s.connect(("8.8.8.8", 80))
        return s.getsockname()[0]
    except Exception:
        return "localhost"
    finally:
        s.close()


@asynccontextmanager
async def lifespan(app: FastAPI):
    timeout = httpx.Timeout(
        connect=10.0,
        read=None,   # Las generaciones y streams pueden ser largos.
        write=120.0,
        pool=10.0,
    )
    limits = httpx.Limits(
        max_connections=100,
        max_keepalive_connections=20,
        keepalive_expiry=30.0,
    )
    app.state.http = httpx.AsyncClient(
        timeout=timeout,
        limits=limits,
        follow_redirects=False,
    )
    local_ip = get_local_ip()
    port = LISTEN_PORT
    logger.info("Proxy iniciado: http://%s:%d -> %s", local_ip, port, UPSTREAM_URL)
    try:
        yield
    finally:
        await app.state.http.aclose()


app = FastAPI(
    title="Claude Code → vLLM compatibility proxy",
    version="1.0.0",
    lifespan=lifespan,
)


@app.get("/healthz")
async def healthz() -> dict[str, Any]:
    return {
        "status": "ok",
        "upstream": UPSTREAM_URL,
        "force_model": FORCE_MODEL or None,
        "system_mode": SYSTEM_MODE,
    }


@app.get("/readyz")
async def readyz(request: Request):
    client: httpx.AsyncClient = request.app.state.http
    try:
        response = await client.get(f"{UPSTREAM_URL}/v1/models")
        return JSONResponse(
            status_code=200 if response.is_success else 503,
            content={
                "ready": response.is_success,
                "upstream_status": response.status_code,
            },
        )
    except httpx.RequestError as exc:
        return JSONResponse(
            status_code=503,
            content={"ready": False, "error": str(exc)},
        )


@app.api_route(
    "/{path:path}",
    methods=["GET", "POST", "PUT", "PATCH", "DELETE", "OPTIONS", "HEAD"],
)
async def proxy(path: str, request: Request):
    client: httpx.AsyncClient = request.app.state.http

    target_url = f"{UPSTREAM_URL}/{path}"
    if request.url.query:
        target_url = f"{target_url}?{request.url.query}"

    raw_body = await request.body()

    if (
        request.method == "POST"
        and path.rstrip("/") == "v1/messages"
        and raw_body
    ):
        try:
            payload = json.loads(raw_body)
            if not isinstance(payload, dict):
                raise ValueError("El cuerpo JSON debe ser un objeto")

            payload, stats = normalize_anthropic_request(payload)
            raw_body = json.dumps(
                payload,
                ensure_ascii=False,
                separators=(",", ":"),
            ).encode("utf-8")

            logger.info(
                "Solicitud normalizada model=%s stream=%s "
                "roles=%s->%s system_hoisted=%s dropped=%s tool_fields=%s",
                stats["model"],
                stats["stream"],
                stats["original_roles"],
                stats["normalized_roles"],
                stats["hoisted_system_messages"],
                stats["removed_top_level"],
                stats["removed_tool_fields"],
            )
        except (json.JSONDecodeError, ValueError) as exc:
            logger.warning("Solicitud rechazada por el proxy: %s", exc)
            return JSONResponse(
                status_code=400,
                content={
                    "type": "error",
                    "error": {
                        "type": "invalid_request_error",
                        "message": str(exc),
                    },
                },
            )

    headers = {
        key: value
        for key, value in request.headers.items()
        if key.lower() not in HOP_BY_HOP_HEADERS
        and key.lower() not in {"host", "content-length"}
    }

    if request.client:
        forwarded_for = headers.get("x-forwarded-for")
        client_ip = request.client.host
        headers["x-forwarded-for"] = (
            f"{forwarded_for}, {client_ip}" if forwarded_for else client_ip
        )

    headers["x-forwarded-proto"] = request.url.scheme
    headers["x-forwarded-host"] = request.headers.get("host", "")

    if UPSTREAM_API_KEY:
        headers["authorization"] = f"Bearer {UPSTREAM_API_KEY}"
        headers["x-api-key"] = UPSTREAM_API_KEY

    upstream_request = client.build_request(
        method=request.method,
        url=target_url,
        headers=headers,
        content=raw_body,
    )

    try:
        upstream_response = await client.send(
            upstream_request,
            stream=True,
        )
    except httpx.RequestError as exc:
        logger.error("No se pudo conectar con vLLM: %s", exc)
        return JSONResponse(
            status_code=502,
            content={
                "type": "error",
                "error": {
                    "type": "upstream_connection_error",
                    "message": str(exc),
                },
            },
        )

    response_headers = {
        key: value
        for key, value in upstream_response.headers.items()
        if key.lower() not in HOP_BY_HOP_HEADERS
        and key.lower() != "content-length"
    }

    # aiter_raw() retransmite SSE/JSON sin traducir ni acumular la respuesta.
    return StreamingResponse(
        upstream_response.aiter_raw(),
        status_code=upstream_response.status_code,
        headers=response_headers,
        background=BackgroundTask(upstream_response.aclose),
    )


if __name__ == "__main__":
    uvicorn.run(app, host=LISTEN_IP, port=LISTEN_PORT)
