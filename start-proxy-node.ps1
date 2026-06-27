# start-proxy-node - Iniciar proxy con Node.js

param(
    [string]$ConfigPath = ".\config.json"
)

Write-Host "Starting Claude vLLM Proxy (Node.js)..." -ForegroundColor Green

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
    } catch {
        Write-Host "Warning: Could not parse config.json" -ForegroundColor Yellow
    }
}

# Usar valores por defecto
$listenIp = if ($env:LISTEN_IP) { $env:LISTEN_IP } else { "0.0.0.0" }
$listenPort = if ($env:LISTEN_PORT) { $env:LISTEN_PORT } else { 8010 }

Write-Host "Listening on $listenIp:$listenPort..." -ForegroundColor Cyan

# Verificar Node.js
$nodeExe = "node"
if (!(Get-Command $nodeExe -ErrorAction SilentlyContinue)) {
    Write-Host "Error: Node.js not found in PATH" -ForegroundColor Red
    exit 1
}

# Verificar e instalar dependencias
if (!(Test-Path "node_modules")) {
    Write-Host "Installing dependencies..." -ForegroundColor Yellow
    npm install fastify @fastify/http-proxy
}

# Verificar si package.json existe
if (!(Test-Path "package.json")) {
    Write-Host "Creating package.json..." -ForegroundColor Yellow
    npm init -y
}

# Iniciar el proxy
$env:LISTEN_IP = $listenIp
$env:LISTEN_PORT = $listenPort

node app.js

Write-Host "Proxy started!" -ForegroundColor Green
Write-Host "Configure Claude Code with:" -ForegroundColor Yellow
Write-Host "  ANTHROPIC_BASE_URL=http://localhost:$listenPort" -ForegroundColor Cyan
