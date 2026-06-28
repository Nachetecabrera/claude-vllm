# Install claude-vllm-proxy - Configura PATH y comandos permanentemente

# Usar el directorio donde se encuentra el script
$scriptDir = Split-Path -Parent -Path $MyInvocation.MyCommand.Path
$projectRoot = Split-Path -Parent -Path $scriptDir

Write-Host "Installing claude-vllm-proxy..." -ForegroundColor Green

# Agregar directorio de scripts al PATH del usuario (persistente)
$currentPath = [Environment]::GetEnvironmentVariable("Path", "User")
if ($currentPath -notlike "*$scriptDir*") {
    [Environment]::SetEnvironmentVariable("Path", "$currentPath;$scriptDir", "User")
    Write-Host "Added to PATH: $scriptDir" -ForegroundColor Green
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
`$projectDir = "$projectRoot"

function claudevllm {
    & `"$(Join-Path $projectDir 'scripts\claude-local\ps1\claudevllm.ps1')`"
}

function claudevllmd {
    & `"$(Join-Path $projectDir 'scripts\claude-local\ps1\claudevllmd.ps1')`"
}

function spcvp {
    & `"$(Join-Path $projectDir 'start\start-proxy-python.ps1')`"
}

function spcvn {
    & `"$(Join-Path $projectDir 'start\start-proxy-node.ps1')`"
}
"@

# Agregar aliases al profile
Add-Content -Path $profilePath -Value "`n$profileContent"
Write-Host "Added aliases to PowerShell profile" -ForegroundColor Green

Write-Host ""
Write-Host "Installation complete!" -ForegroundColor Green
Write-Host "Restart your terminal and run:"
Write-Host "  claudevllm / claudevllmd - Run claude with proxy"
Write-Host "  spcvp / spcvn - Start proxy (Python / Node.js)"
Write-Host ""
Write-Host "If command not found, run: `\$env:Path = [Environment]::GetEnvironmentVariable('Path', 'User')" -ForegroundColor Yellow
