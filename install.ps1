# Install claude-vllm-proxy - Configura PATH y comandos permanentemente

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$projectDir = "C:\Users\ignac\OneDrive\Documents\claude-vllm-proxy"

Write-Host "Installing claude-vllm-proxy..." -ForegroundColor Green

# Agregar directorio al PATH del usuario (persistente)
$currentPath = [Environment]::GetEnvironmentVariable("Path", "User")
if ($currentPath -notlike "*$projectDir*") {
    [Environment]::SetEnvironmentVariable("Path", "$currentPath;$projectDir", "User")
    Write-Host "Added to PATH: $projectDir" -ForegroundColor Green
} else {
    Write-Host "Directory already in PATH" -ForegroundColor Cyan
}

# Crear aliases en el perfil de PowerShell si no existen
$profilePath = $PROFILE
if (!(Test-Path $profilePath)) {
    New-Item -ItemType File -Path $profilePath -Force | Out-Null
}

$profileContent = @"
# claude-vllm-proxy aliases (auto-generated)
function claudevllm { . "$projectDir\claude-local.ps1"; claude }
function claudevllmd { . "$projectDir\claude-local.ps1"; claude --permission-mode bypassPermissions }
"@

# Leer contenido actual
if (Test-Path $profilePath) {
    $currentProfile = Get-Content $profilePath -Raw
} else {
    $currentProfile = ""
}

# Agregar solo si no existe
if ($currentProfile -notlike "*claudevllm*") {
    Add-Content -Path $profilePath -Value "`n$profileContent"
    Write-Host "Added aliases to PowerShell profile" -ForegroundColor Green
} else {
    Write-Host "Aliases already in PowerShell profile" -ForegroundColor Cyan
}

Write-Host ""
Write-Host "Installation complete!" -ForegroundColor Green
Write-Host "Restart your terminal and run: claudevllm or claudevllmd"
Write-Host ""
Write-Host "If command not found, run: `\$env:Path = [Environment]::GetEnvironmentVariable('Path', 'User')" -ForegroundColor Yellow
