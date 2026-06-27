#!/bin/bash

# Install claude-vllm-proxy - Configura PATH y comandos permanentemente

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$SCRIPT_DIR"

echo "Installing claude-vllm-proxy..."

# Detectar shell
if [ -n "$ZSH_VERSION" ]; then
    SHELL_TYPE="zsh"
    PROFILE_FILE="$HOME/.zshrc"
elif [ -n "$BASH_VERSION" ]; then
    SHELL_TYPE="bash"
    PROFILE_FILE="$HOME/.bashrc"
fi

# Verificar si el directorio ya está en PATH
if echo "$PATH" | grep -q "$PROJECT_DIR"; then
    echo "Directory already in PATH"
else
    # Agregar al PATH en el archivo de perfil
    if [ -f "$PROFILE_FILE" ]; then
        # Evitar duplicados
        if ! grep -q "claude-vllm-proxy" "$PROFILE_FILE"; then
            echo "" >> "$PROFILE_FILE"
            echo "# claude-vllm-proxy (auto-added)" >> "$PROFILE_FILE"
            echo "export PATH=\"\$PATH:$PROJECT_DIR\"" >> "$PROFILE_FILE"
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
        cat >> "$PROFILE_FILE" << 'EOF'

# claude-vllm-proxy aliases (auto-generated)
claudevllm() {
    source "$PROJECT_DIR/claude-local.sh"
    claude
}

claudevllmd() {
    source "$PROJECT_DIR/claude-local.sh"
    claude --permission-mode bypassPermissions
}
EOF
        echo "Added aliases to $PROFILE_FILE"
    else
        echo "Aliases already in $PROFILE_FILE"
    fi
fi

echo ""
echo "Installation complete!"
echo "Restart your terminal and run: claudevllm or claudevllmd"
echo ""
echo "To reload now, run: source $PROFILE_FILE"
