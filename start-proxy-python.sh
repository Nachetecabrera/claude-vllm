#!/bin/bash

# start-proxy-python - Iniciar proxy con Python
# Requiere: Python 3.10+ y dependencias (fastapi, httpx, uvicorn)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Cargar configuración
CONFIG_PATH="$SCRIPT_DIR/config.json"

# Valores por defecto
LISTEN_IP="0.0.0.0"
LISTEN_PORT="8010"
LOG_LEVEL="INFO"
SYSTEM_MODE="hoist"

if [ -f "$CONFIG_PATH" ]; then
    if command -v jq &> /dev/null; then
        LISTEN_IP=$(jq -r '.listen_ip // "0.0.0.0"' "$CONFIG_PATH")
        LISTEN_PORT=$(jq -r '.listen_port // 8010' "$CONFIG_PATH")
        LOG_LEVEL=$(jq -r '.log_level // "INFO"' "$CONFIG_PATH")
        SYSTEM_MODE=$(jq -r '.system_mode // "hoist"' "$CONFIG_PATH")
    else
        echo "Warning: jq not found. Install with: brew install jq (macOS) or apt install jq (Linux)"
    fi
fi

echo "Starting Claude vLLM Proxy (Python)..."
echo "Listening on: $LISTEN_IP:$LISTEN_PORT"

# Verificar Python
if ! command -v python3 &> /dev/null; then
    echo "Error: Python 3 not found"
    exit 1
fi

# Verificar dependencias
python3 -c "import fastapi, httpx, uvicorn" 2>/dev/null
if [ $? -ne 0 ]; then
    echo "Installing dependencies..."
    python3 -m pip install fastapi httpx uvicorn
fi

# Iniciar el proxy
export LISTEN_IP="$LISTEN_IP"
export LISTEN_PORT="$LISTEN_PORT"
export LOG_LEVEL="$LOG_LEVEL"
export SYSTEM_MODE="$SYSTEM_MODE"

python3 -m uvicorn app:app --host "$LISTEN_IP" --port "$LISTEN_PORT"
