#!/bin/bash

# start-proxy-node - Iniciar proxy con Node.js
# Requiere: Node.js 18+ y dependencias (fastify, @fastify/http-proxy)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
NODE_DIR="$PROJECT_ROOT/src/node"

# Cargar configuración
CONFIG_PATH="$NODE_DIR/config.json"

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
if [ ! -f "$NODE_DIR/package.json" ]; then
    echo "Creating package.json..."
    cd "$NODE_DIR"
    npm init -y
fi

# Verificar e instalar dependencias
if [ ! -d "$NODE_DIR/node_modules" ]; then
    echo "Installing dependencies..."
    cd "$NODE_DIR"
    npm install fastify @fastify/http-proxy
    cd "$PROJECT_ROOT"
fi

# Iniciar el proxy
export LISTEN_IP="$LISTEN_IP"
export LISTEN_PORT="$LISTEN_PORT"

cd "$NODE_DIR"
node app.js
