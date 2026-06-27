#!/bin/bash

# start-proxy-node - Iniciar proxy con Node.js
# Requiere: Node.js 18+ y dependencias (fastify, @fastify/http-proxy)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Cargar configuración
CONFIG_PATH="$SCRIPT_DIR/config.json"

# Valores por defecto
LISTEN_IP="0.0.0.0"
LISTEN_PORT="8010"

if [ -f "$CONFIG_PATH" ]; then
    if command -v jq &> /dev/null; then
        LISTEN_IP=$(jq -r '.listen_ip // "0.0.0.0"' "$CONFIG_PATH")
        LISTEN_PORT=$(jq -r '.listen_port // 8010' "$CONFIG_PATH")
    else
        echo "Warning: jq not found. Install with: brew install jq (macOS) or apt install jq (Linux)"
    fi
fi

echo "Starting Claude vLLM Proxy (Node.js)..."
echo "Listening on: $LISTEN_IP:$LISTEN_PORT"

# Verificar Node.js
if ! command -v node &> /dev/null; then
    echo "Error: Node.js not found"
    exit 1
fi

echo "Node version:"
node --version

# Verificar si package.json existe
if [ ! -f "package.json" ]; then
    echo "Creating package.json..."
    npm init -y
fi

# Verificar e instalar dependencias
if [ ! -d "node_modules" ]; then
    echo "Installing dependencies..."
    npm install fastify @fastify/http-proxy
fi

# Iniciar el proxy
export LISTEN_IP="$LISTEN_IP"
export LISTEN_PORT="$LISTEN_PORT"

node app.js
