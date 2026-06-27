#!/bin/bash

# claudevllmd - ejecuta con modo permisivo bypassPermissions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/claude-local.sh"
claude --permission-mode bypassPermissions
