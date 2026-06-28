# 🦙 Claude vLLM Proxy

A proxy that enables Claude Code to work with vLLM (NVIDIA NGC or local server).

[![License](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
[![Python](https://img.shields.io/badge/python-3.10+-blue.svg)](https://www.python.org/)
[![Node.js](https://img.shields.io/badge/node.js-18+-green.svg)](https://nodejs.org/)
[![vLLM](https://img.shields.io/badge/vLLM-compatible-green.svg)](https://github.com/vllm-project/vllm)

---

## Table of Contents

- [How It Works](#how-it-works)
- [Architecture](#architecture)
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

## How It Works

The Claude vLLM Proxy acts as a translation layer between Claude Code and vLLM:

1. **Claude Code** sends API requests to the proxy (port 8010 by default)
2. The proxy **normalizes** the request:
   - Converts system/developer messages to the top-level `system` field (or user messages)
   - Removes incompatible fields like `context_management`, `output_config`, `thinking`
   - Drops tool fields like `strict`, `defer_loading`
   - Strips `cache_control` from requests
   - Forces a specific model if configured
3. The proxy **forwards** the normalized request to vLLM
4. The response is streamed back to Claude Code

This allows Claude Code to work with any vLLM-compatible server without requiring modifications to Claude itself.

---

## Architecture

```
┌─────────────┐      ┌─────────────────────┐      ┌──────────────┐
│             │      │                     │      │              │
│  Claude     │─────▶│   Claude vLLM       │─────▶│    vLLM      │
│   Code      │      │      Proxy          │      │   Server     │
│             │      │   (Port 8010)       │      │              │
└─────────────┘      └─────────────────────┘      └──────────────┘
     │                        │                         │
     │                         └─────────────────────────┘
     │                                      │
     │                              Normalizes requests:
     │                              - System message hoisting
     │                              - Field removal
     │                              - Model enforcement
     │                                      │
     │                                      ▼
     │                         ┌──────────────────────┐
     │                         │   Forwards to vLLM   │
     │                         └──────────────────────┘
     │                                      │
     │                                      ▼
     │                         ┌──────────────────────┐
     │                         │   Streams back to    │
     │                         │    Claude Code       │
     └─────────────────────────┘
```

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
.\scripts\install.ps1
```

### Linux/macOS
```bash
chmod +x scripts/install.sh && ./scripts/install.sh
```

The installation script:
- ✅ Adds the scripts directory to PATH permanently
- ✅ Creates `claudevllm`, `claudevllmd`, `spcvp`, `spcvn` commands
- ✅ Sets up both stacks (Python and Node.js)
- ✅ Uses relative paths (works from any directory)

**Restart your terminal** after installation for changes to take effect.

---

## Configuration

### 1. Copy example config file

**Python:**
```bash
# Windows
copy src\python\config.example.json src\python\config.json

# Linux/macOS
cp src/python/config.example.json src/python/config.json
```

**Node.js:**
```bash
# Windows
copy src\node\config.example.json src\node\config.json

# Linux/macOS
cp src/node/config.example.json src/node/config.json
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
- `drop_top_level_fields`: Fields to drop from requests (comma-separated)
- `drop_tool_fields`: Tool fields to drop (comma-separated)

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
.\start\start-proxy-python.ps1    # Windows - Python
.\start\start-proxy-node.ps1      # Windows - Node.js
./start/start-proxy-python.sh     # Unix - Python
./start/start-proxy-node.sh       # Unix - Node.js
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
| `claudevllm` | Run Claude with proxy (uses config.json) |
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
.\start\start-proxy-python.ps1    # Windows
./start/start-proxy-python.sh     # Unix
```

**Node.js:**
```bash
cd src/node
.\start\start-proxy-node.ps1    # Windows
./start/start-proxy-node.sh     # Unix
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
.\start\start-proxy-python.ps1

# Linux/macOS
./start/start-proxy-python.sh

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
├── scripts/
│   ├── install.ps1          # Windows installer
│   ├── install.sh           # Unix installer
│   └── claude-local/        # Claude configuration helpers
│       ├── ps1/             # PowerShell scripts
│       └── sh/              # Bash scripts
├── start/                   # Proxy startup scripts
│   ├── start-proxy-python.ps1
│   ├── start-proxy-python.sh
│   ├── start-proxy-node.ps1
│   └── start-proxy-node.sh
├── docs/                    # Documentation
│   ├── config.example.json
│   └── config.schema.json
├── install.ps1              # Windows installer (deprecated)
├── install.sh               # Unix installer (deprecated)
└── README.md                # This file
```

---

## License

MIT

---

## Credits

- [Claude Code](https://claude.ai/)
- [vLLM](https://github.com/vllm-project/vllm)
- [FastAPI](https://fastapi.tiangolo.com/)
- [Fastify](https://www.fastify.io/)
