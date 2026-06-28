# start-proxy-python - Iniciar proxy con Python

param(
    [string]$ConfigPath = ""
)

Write-Host "Starting Claude vLLM Proxy (Python)..." -ForegroundColor Green

# Usar el directorio donde se encuentra el script
$scriptDir = Split-Path -Parent -Path $MyInvocation.MyCommand.Path
$projectRoot = Split-Path -Parent -Path $scriptDir
$pythonDir = Join-Path $projectRoot "src/python"

# Buscar config.json en múltiples ubicaciones
if (-not $ConfigPath) {
    $searchPaths = @(
        (Join-Path $projectRoot "config.json"),
        (Join-Path $pythonDir "config.json"),
        (Join-Path $projectRoot "src/python/config.json")
    )
    foreach ($p in $searchPaths) {
        if (Test-Path $p) {
            $ConfigPath = $p
            break
        }
    }
}

# Cargar configuración si existe
$config = $null
if ($ConfigPath -and (Test-Path $ConfigPath)) {
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

Write-Host "Listening on ${listenIp}:${listenPort}..." -ForegroundColor Cyan

# Verificar Python
$pythonExe = "python.exe"
if (!(Get-Command $pythonExe -ErrorAction SilentlyContinue)) {
    Write-Host "Error: Python not found in PATH" -ForegroundColor Red
    exit 1
}

# Verificar dependencias
$requirementsPath = Join-Path $pythonDir "requirements.txt"
if (Test-Path $requirementsPath) {
    try {
        & $pythonExe -m pip install -r $requirementsPath
    } catch {
        Write-Host "Warning: Could not install dependencies from requirements.txt" -ForegroundColor Yellow
    }
}

# Iniciar el proxy
Set-Location $pythonDir
& $pythonExe -m uvicorn app:app --host $listenIp --port $listenPort

Write-Host "Proxy started!" -ForegroundColor Green
Write-Host "Configure Claude Code with:" -ForegroundColor Yellow
Write-Host "  ANTHROPIC_BASE_URL=http://localhost:$listenPort" -ForegroundColor Cyan
