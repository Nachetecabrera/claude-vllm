#!/bin/bash

# Install claude-vllm-proxy - Configura PATH y comandos permanentemente

# Usar el directorio donde se encuentra el script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

echo "Installing claude-vllm-proxy..."

# Detectar shell
if [ -n "$ZSH_VERSION" ]; then
    SHELL_TYPE="zsh"
    PROFILE_FILE="$HOME/.zshrc"
elif [ -n "$BASH_VERSION" ]; then
    SHELL_TYPE="bash"
    PROFILE_FILE="$HOME/.bashrc"
else
    echo "Warning: Could not detect shell. Profile may not be updated."
    PROFILE_FILE="$HOME/.bashrc"
fi

# Verificar si el directorio ya está en PATH
if echo "$PATH" | grep -q "$SCRIPT_DIR"; then
    echo "Directory already in PATH"
else
    # Agregar al PATH en el archivo de perfil
    if [ -f "$PROFILE_FILE" ]; then
        # Evitar duplicados
        if ! grep -q "claude-vllm-proxy" "$PROFILE_FILE"; then
            echo "" >> "$PROFILE_FILE"
            echo "# claude-vllm-proxy (auto-added)" >> "$PROFILE_FILE"
            echo "export PATH=\"\$PATH:$SCRIPT_DIR\"" >> "$PROFILE_FILE"
            echo "Added to PATH in $PROFILE_FILE"
        else
            echo "Directory already in PATH (found in $PROFILE_FILE)"
        fi
    else
        echo "Warning: $PROFILE_FILE not found. Please add manually to your profile."
    fi
fi

# Crear aliases si no existen
if [ -f "$PROFILE_FILE" ]; then
    if ! grep -q "claudevllm" "$PROFILE_FILE"; then
        cat >> "$PROFILE_FILE" << EOF

# claude-vllm-proxy aliases (auto-generated)
claudevllm() {
    source "$SCRIPT_DIR/claude-local/sh/claude-local.sh"
    claude
}

claudevllmd() {
    source "$SCRIPT_DIR/claude-local/sh/claude-local.sh"
    claude --permission-mode bypassPermissions
}

# Start proxy shortcuts
spcvp() {
    source "$SCRIPT_DIR/claude-local/sh/claude-local.sh"
    "$SCRIPT_DIR/../start/start-proxy-python.sh"
}

spcvn() {
    source "$SCRIPT_DIR/claude-local/sh/claude-local.sh"
    "$SCRIPT_DIR/../start/start-proxy-node.sh"
}
EOF
        echo "Added aliases to $PROFILE_FILE"
    else
        echo "Aliases already in $PROFILE_FILE"
    fi
fi

echo ""
echo "Installation complete!"
echo "Restart your terminal and run:"
echo "  claudevllm / claudevllmd - Run claude with proxy"
echo "  spcvp / spcvn - Start proxy (Python / Node.js)"
echo ""
echo "To reload now, run: source $PROFILE_FILE"
