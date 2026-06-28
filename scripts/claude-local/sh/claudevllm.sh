#!/bin/bash

# claudevllm - ejecuta con configuración del config.json
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/claude-local.sh"
claude
