# Configuración para Claude Code
# Lee config.json para obtener la URL del proxy local

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

# Buscar config.json en múltiples ubicaciones
$projectRoot = Resolve-Path (Join-Path $scriptDir "../../..")
$configSearchPaths = @(
    (Join-Path $projectRoot "config.json"),
    (Join-Path $projectRoot "src/python/config.json"),
    (Join-Path $scriptDir "config.json")
)
$configPath = $null
foreach ($p in $configSearchPaths) {
    if (Test-Path $p) {
        $configPath = $p
        break
    }
}

# Valores por defecto
$proxyUrl = "http://localhost:8010"
$model = "qwen3-coder-next"

# Cargar configuración si existe
if ($configPath) {
    try {
        $config = Get-Content $configPath -Raw | ConvertFrom-Json
        if ($config.listen_port) {
            $proxyUrl = "http://localhost:$($config.listen_port)"
        }
        if ($config.model) {
            $model = $config.model
        }
    } catch {
        Write-Host "Warning: Could not parse config.json. Using defaults." -ForegroundColor Yellow
    }
}

# Configurar variables de entorno
$env:ANTHROPIC_BASE_URL = $proxyUrl
$env:ANTHROPIC_API_KEY = "dummy"
$env:ANTHROPIC_AUTH_TOKEN = "dummy"

$env:ANTHROPIC_MODEL = $model
$env:ANTHROPIC_DEFAULT_OPUS_MODEL = $model
$env:ANTHROPIC_DEFAULT_SONNET_MODEL = $model
$env:ANTHROPIC_DEFAULT_HAIKU_MODEL = $model

# Reduce campos beta incompatibles antes de llegar al proxy.
$env:CLAUDE_CODE_DISABLE_EXPERIMENTAL_BETAS = "1"
$env:CLAUDE_CODE_DISABLE_THINKING = "1"

$env:API_TIMEOUT_MS = "1200000"
$env:API_FORCE_IDLE_TIMEOUT = "0"

Write-Host "Claude config loaded: $proxyUrl" -ForegroundColor Cyan
