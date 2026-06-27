# 🦙 Claude vLLM Proxy

Proxy para usar Claude Code con vLLM (NVIDIA NGC).

[![License](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
[![Python](https://img.shields.io/badge/python-3.10+-blue.svg)](https://www.python.org/)
[![Node.js](https://img.shields.io/badge/node.js-18+-green.svg)](https://nodejs.org/)


## Características

- ✅ Proxy entre Claude Code y vLLM
- ✅ Configuración vía `config.json`
- ✅ Cross-platform: Windows, Linux, macOS
- ✅ Transformación de requests (system messages, fields dropping)
- ✅ Health checks (`/healthz`, `/readyz`)
- ✅ **Doble stack**: Python y Node.js disponibles

## Requisitos

- **Python**: 3.10 o superior (para el proxy)
- **Node.js**: 18 o superior (opcional, para alternativa Node)
- **vLLM**: Servidor vLLM en NGC o local

### Dependencias

| Stack | Comando |
|-------|---------|
| Python | `pip install -r requirements.txt` |
| Node.js | `npm install` |

## Instalación

### Windows
```powershell
.\install.ps1
```

### Linux/macOS
```bash
chmod +x install.sh && ./install.sh
```

Este script:
- ✅ Agrega el directorio al PATH permanentemente
- ✅ Crea los comandos `claudevllm` y `claudevllmd`
- ✅ Configura ambos stacks (Python y Node.js)

**Reinicia tu terminal** después de instalar para que los cambios surtan efecto.

## Configuración

Edita `config.json` para configurar el proxy:

```json
{
  "listen_ip": "0.0.0.0",
  "listen_port": 8010,
  "forward_url": "http://100.85.253.101:8000",
  "model": "qwen3-coder-next",
  "log_level": "INFO",
  "system_mode": "hoist",
  "drop_top_level_fields": "context_management,output_config,thinking",
  "drop_tool_fields": "strict,defer_loading",
  "strip_cache_control": true
}
```

### Configuración de Claude Code

En tu `claude_desktop.toml` o variables de entorno:

```toml
[anthropic]
base_url = "http://localhost:8010"
api_key = "dummy"
```

O en variables de entorno:

```bash
# Windows (PowerShell)
$env:ANTHROPIC_BASE_URL = "http://localhost:8010"
$env:ANTHROPIC_API_KEY = "dummy"

# Linux/macOS
export ANTHROPIC_BASE_URL="http://localhost:8010"
export ANTHROPIC_API_KEY="dummy"
```

## Uso

### Iniciar el proxy

```bash
# Windows
.\start-proxy-python.ps1    # Python
.\start-proxy-node.ps1      # Node.js

# Linux/macOS
./start-proxy-python.sh     # Python
./start-proxy-node.sh       # Node.js
```

### Comandos disponibles (después de instalar)

```bash
claudevllm        # Ejecuta normal con config.json
claudevllmd       # Ejecuta con --permission-mode bypassPermissions
```

Ambos comandos funcionan en Windows, Linux y macOS después de instalar.

## Variables de Entorno

| Variable | Descripción | Default |
|----------|-------------|---------|
| `UPSTREAM_URL` | URL del servidor vLLM | `http://localhost:8000` |
| `FORCE_MODEL` | Forzar modelo específico | `""` (usa config.json) |
| `SYSTEM_MODE` | Cómo manejar system messages | `hoist` |
| `LOG_LEVEL` | Nivel de logging | `INFO` |
| `LISTEN_IP` | IP del proxy | `0.0.0.0` |
| `LISTEN_PORT` | Puerto del proxy | `8010` |

### Configuración en `config.json`

```json
{
  "listen_ip": "0.0.0.0",
  "listen_port": 8010,
  "forward_url": "http://localhost:8000",
  "model": "qwen3-coder-next",
  "log_level": "INFO",
  "system_mode": "hoist"
}
```

## Health Checks

- `/healthz` - Verifica que el proxy esté funcionando
- `/readyz` - Verifica que el proxy y el servidor upstream estén listos

## Estructura del Proyecto

```
claude-vllm-proxy/
├── app.py                 # Código principal (FastAPI - Python)
├── app.js                 # Código principal (Fastify - Node.js)
├── config.json            # Configuración
├── config.schema.json     # Schema JSON para validación
├── requirements.txt       # Dependencias Python
├── package.json           # Dependencias Node.js
├── install.ps1           # Instalación Windows (PATH + aliases)
├── install.sh            # Instalación Unix (PATH + aliases)
├── start-proxy-python.ps1 # Iniciar proxy Python Windows
├── start-proxy-python.sh # Iniciar proxy Python Unix
├── start-proxy-node.ps1  # Iniciar proxy Node.js Windows
├── start-proxy-node.sh   # Iniciar proxy Node.js Unix
├── claude-local.ps1      # Config claude Windows
├── claude-local.sh       # Config claude Unix
├── claudevllm.ps1        # Alias claude normal Windows
├── claudevllm.sh         # Alias claude normal Unix
├── claudevllmd.ps1       # Alias claude bypass Windows
├── claudevllmd.sh        # Alias claude bypass Unix
├── README.md             # Este archivo
└── .gitignore           # Archivos a ignorar
```

## Desarrollo

### Correr en modo desarrollo

```bash
# Windows - Python
.\start-proxy-python.ps1

# Windows - Node.js
.\start-proxy-node.ps1

# Unix - Python
./start-proxy-python.sh

# Unix - Node.js
./start-proxy-node.sh
```

### Build (empaquetar como executable)

**Python:**
```bash
pip install pyinstaller
pyinstaller claude-vllm-proxy.spec
```

**Node.js:**
```bash
npm install -g @vercel/ncc
ncc build app.js -o dist
```

## Troubleshooting

### Comando no encontrado después de instalar
```bash
# Windows - Reiniciar terminal o ejecutar:
$env:Path = [Environment]::GetEnvironmentVariable('Path', 'User')

# Linux/macOS
source ~/.bashrc  # o ~/.zshrc
```

### Puerto en uso
```bash
# Windows
netstat -ano | findstr :8010
taskkill /F /PID <PID>

# Linux/macOS
lsof -i :8010
kill -9 <PID>
```

## Licencia

MIT
