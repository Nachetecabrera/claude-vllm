# 🦙 Claude vLLM Proxy

A proxy that enables Claude Code to work with vLLM (NVIDIA NGC or local server).

[![License](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
[![Python](https://img.shields.io/badge/python-3.10+-blue.svg)](https://www.python.org/)
[![Node.js](https://img.shields.io/badge/node.js-18+-green.svg)](https://nodejs.org/)
[![vLLM](https://img.shields.io/badge/vLLM-compatible-green.svg)](https://github.com/vllm-project/vllm)

---

## Table of Contents

- [Requirements](#requirements)
- [Quick Start Installation](#quick-start-installation)
- [Configuration](#configuration)
- [Usage](#usage)
- [Available Commands](#available-commands)
- [Health Endpoints](#health-endpoints)
- [Environment Variables](#environment-variables)
- [Development](#development)
- [Troubleshooting](#troubleshooting)

---

## Requirements

| Component | Version | Notes |
|-----------|---------|-------|
| **Claude Code** | 2.1.140+ | CLI client |
| **Python** | 3.10+ | For Python proxy (FastAPI) |
| **Node.js** | 18+ | For Node.js proxy (Fastify) |
| **vLLM** | latest | Server on NVIDIA NGC or local |

### Dependencies

| Stack | Command |
|-------|---------|
| Python | `pip install -r requirements.txt` |
| Node.js | `npm install` |

---

## Quick Start Installation

### Windows
```powershell
.\install.ps1
```

### Linux/macOS
```bash
chmod +x install.sh && ./install.sh
```

The installation script:
- ✅ Adds the directory to PATH permanently
- ✅ Creates `claudevllm`, `claudevllmd`, `spcvp`, `spcvn` commands
- ✅ Sets up both stacks (Python and Node.js)

**Restart your terminal** after installation for changes to take effect.

---

## Configuration

### 1. Copy example config file

**Windows (Python):**
```powershell
copy docs\config.example.json src\python\config.json
```

**Linux/macOS (Python):**
```bash
cp docs/config.example.json src/python/config.json
```

**Windows (Node.js):**
```powershell
copy docs\config.example.json src\node\config.json
```

**Linux/macOS (Node.js):**
```bash
cp docs/config.example.json src/node/config.json
```

### 2. Edit `config.json`

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

**Key configuration:**
- `forward_url`: Your vLLM server URL (NGC or local)
- `model`: Model to enforce (optional, defaults to vLLM's default)
- `system_mode`: `"hoist"` (recommended) or `"user"`
- `drop_top_level_fields`: Fields to drop from requests (default: `context_management,output_config,thinking`)

### 3. Claude Code Configuration

Add to your `claude_desktop.toml`:

```toml
[anthropic]
base_url = "http://localhost:8010"
api_key = "dummy"
```

Or use environment variables:

```bash
# Windows (PowerShell)
$env:ANTHROPIC_BASE_URL = "http://localhost:8010"
$env:ANTHROPIC_API_KEY = "dummy"

# Linux/macOS
export ANTHROPIC_BASE_URL="http://localhost:8010"
export ANTHROPIC_API_KEY="dummy"
```

---

## Usage

### Start the proxy

```bash
# Using shortcuts (recommended)
spcvp    # Start proxy with Python
spcvn    # Start proxy with Node.js

# Or directly (without installation)
.\start-proxy-python.ps1    # Windows - Python
.\start-proxy-node.ps1      # Windows - Node.js
./start-proxy-python.sh     # Unix - Python
./start-proxy-node.sh       # Unix - Node.js
```

### Run Claude with the proxy

```bash
claudevllm        # Run Claude normal with config.json
claudevllmd       # Run Claude with --permission-mode bypassPermissions
```

Both commands work on Windows, Linux, and macOS after installation.

---

## Available Commands

| Command | Description |
|---------|-------------|
| `claudevllm` | Run Claude with proxy (Python by default) |
| `claudevllmd` | Run Claude with `--permission-mode bypassPermissions` |
| `spcvp` | Start proxy with Python |
| `spcvn` | Start proxy with Node.js |

---

## Health Endpoints

### `/healthz` - Proxy status
```bash
curl http://localhost:8010/healthz
```

Success response:
```json
{
  "status": "ok",
  "upstream": "http://100.85.253.101:8000",
  "force_model": "qwen3-coder-next",
  "system_mode": "hoist"
}
```

### `/readyz` - Proxy + upstream status
```bash
curl http://localhost:8010/readyz
```

Success response:
```json
{
  "ready": true,
  "upstream_status": 200
}
```

Error response:
```json
{
  "ready": false,
  "error": "Connection refused"
}
```

---

## Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `UPSTREAM_URL` | URL of the vLLM server | `http://localhost:8000` |
| `UPSTREAM_API_KEY` | API Key for vLLM server | (empty) |
| `FORCE_MODEL` | Force specific model | (empty, uses config.json) |
| `SYSTEM_MODE` | How to handle system messages | `"hoist"` |
| `LOG_LEVEL` | Logging level | `"INFO"` |
| `LISTEN_IP` | Proxy IP address | `"0.0.0.0"` |
| `LISTEN_PORT` | Proxy port | `8010` |
| `DROP_TOP_LEVEL_FIELDS` | Fields to drop (CSV) | `context_management,output_config,thinking` |
| `DROP_TOOL_FIELDS` | Tool fields to drop (CSV) | `strict,defer_loading` |
| `STRIP_CACHE_CONTROL` | Remove cache_control | `true` |

### System Modes

- **`hoist`** (recommended): Moves `system`/`developer` messages to the top-level `system` field
- **`user`**: Converts system messages to `user` messages with `<system-update>` tag

---

## Development

### Run in development mode

**Python:**
```bash
cd src/python
.\start-proxy-python.ps1    # Windows
./start-proxy-python.sh     # Unix
```

**Node.js:**
```bash
cd src/node
.\start-proxy-node.ps1    # Windows
./start-proxy-node.sh     # Unix
```

### Build (packaging)

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

---

## Troubleshooting

### Command not found after installation

```bash
# Windows - Restart terminal or run:
$env:Path = [Environment]::GetEnvironmentVariable('Path', 'User')

# Linux/macOS
source ~/.bashrc  # or ~/.zshrc
```

### Port already in use

```bash
# Windows
netstat -ano | findstr :8010
taskkill /F /PID <PID>

# Linux/macOS
lsof -i :8010
kill -9 <PID>
```

### Connection error to vLLM

Verify:
1. vLLM server is running: `curl http://<vllm-host>:8000/v1/models`
2. The URL in `config.json` is correct
3. No firewall or network issues

### Verbose logging

```bash
# View logs in real-time
# Windows
.\start-proxy-python.ps1

# Linux/macOS
./start-proxy-python.sh

# Then check logs in console output
```

---

## Project Structure

```
claude-vllm-proxy/
├── src/
│   ├── python/              # Python proxy (FastAPI)
│   │   ├── app.py           # Main application
│   │   ├── requirements.txt # Dependencies
│   │   └── config.json      # Configuration
│   └── node/                # Node.js proxy (Fastify)
│       ├── app.js           # Main application
│       ├── package.json     # Dependencies
│       └── config.json      # Configuration
├── scripts/                 # Installation scripts
│   ├── install.ps1
│   ├── install.sh
│   └── claude-local/        # Claude configuration
├── start/                   # Proxy startup scripts
│   ├── start-proxy-python.ps1
│   ├── start-proxy-python.sh
│   ├── start-proxy-node.ps1
│   └── start-proxy-node.sh
├── docs/                    # Documentation
│   ├── config.example.json
│   └── config.schema.json
├── install.ps1              # Windows installer
├── install.sh               # Unix installer
└── README.md                # This file
```

See [PROJECT_STRUCTURE.md](PROJECT_STRUCTURE.md) for detailed structure information.

---

## License

MIT

---

## Credits

- [Claude Code](https://claude.ai/)
- [vLLM](https://github.com/vllm-project/vllm)
- [FastAPI](https://fastapi.tiangolo.com/)
- [Fastify](https://www.fastify.io/)
