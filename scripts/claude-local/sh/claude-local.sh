#!/bin/bash

# Configuración para Claude Code
# Lee config.json para obtener la URL del proxy local

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_PATH="$SCRIPT_DIR/config.json"

# Valores por defecto
PROXY_URL="http://localhost:8010"
MODEL="qwen3-coder-next"

# Cargar configuración si existe
if [ -f "$CONFIG_PATH" ]; then
    if command -v jq &> /dev/null; then
        PROXY_URL="http://localhost:$(jq -r '.listen_port // 8010' "$CONFIG_PATH")"
        MODEL=$(jq -r '.model // "qwen3-coder-next"' "$CONFIG_PATH")
    else
        echo "Warning: jq not found. Install with: brew install jq (macOS) or apt install jq (Linux)"
    fi
fi

# Configurar variables de entorno
export ANTHROPIC_BASE_URL="$PROXY_URL"
export ANTHROPIC_API_KEY="dummy"
export ANTHROPIC_AUTH_TOKEN="dummy"
export ANTHROPIC_MODEL="$MODEL"
export ANTHROPIC_DEFAULT_OPUS_MODEL="$MODEL"
export ANTHROPIC_DEFAULT_SONNET_MODEL="$MODEL"
export ANTHROPIC_DEFAULT_HAIKU_MODEL="$MODEL"
export CLAUDE_CODE_DISABLE_EXPERIMENTAL_BETAS="1"
export CLAUDE_CODE_DISABLE_THINKING="1"
export API_TIMEOUT_MS="1200000"
export API_FORCE_IDLE_TIMEOUT="0"

echo "Claude config loaded: $PROXY_URL"
