# start-proxy-python - Iniciar proxy con Python

param(
    [string]$ConfigPath = ".\config.json"
)

Write-Host "Starting Claude vLLM Proxy (Python)..." -ForegroundColor Green

# Cargar configuración si existe
$config = $null
if (Test-Path $ConfigPath) {
    try {
        $config = Get-Content $ConfigPath -Raw | ConvertFrom-Json
        if ($config.listen_ip) {
            $env:LISTEN_IP = $config.listen_ip
        }
        if ($config.listen_port) {
            $env:LISTEN_PORT = $config.listen_port
        }
        if ($config.log_level) {
            $env:LOG_LEVEL = $config.log_level
        }
        if ($config.system_mode) {
            $env:SYSTEM_MODE = $config.system_mode
        }
    } catch {
        Write-Host "Warning: Could not parse config.json" -ForegroundColor Yellow
    }
}

# Usar valores por defecto
$listenIp = if ($env:LISTEN_IP) { $env:LISTEN_IP } else { "0.0.0.0" }
$listenPort = if ($env:LISTEN_PORT) { $env:LISTEN_PORT } else { 8010 }

Write-Host "Listening on $listenIp:$listenPort..." -ForegroundColor Cyan

# Verificar Python
$pythonExe = "python.exe"
if (!(Get-Command $pythonExe -ErrorAction SilentlyContinue)) {
    Write-Host "Error: Python not found in PATH" -ForegroundColor Red
    exit 1
}

# Verificar dependencias
try {
    & $pythonExe -c "import fastapi, httpx, uvicorn" 2>$null
    if ($LASTEXITCODE -ne 0) {
        Write-Host "Installing dependencies..." -ForegroundColor Yellow
        & $pythonExe -m pip install fastapi httpx uvicorn
    }
} catch {
    Write-Host "Installing dependencies..." -ForegroundColor Yellow
    & $pythonExe -m pip install fastapi httpx uvicorn
}

# Iniciar el proxy
& $pythonExe -m uvicorn app:app --host $listenIp --port $listenPort

Write-Host "Proxy started!" -ForegroundColor Green
Write-Host "Configure Claude Code with:" -ForegroundColor Yellow
Write-Host "  ANTHROPIC_BASE_URL=http://localhost:$listenPort" -ForegroundColor Cyan
