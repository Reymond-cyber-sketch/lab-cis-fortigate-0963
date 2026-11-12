#requires -Version 5.1
$ErrorActionPreference='Stop'
# Solo prepara Windows. No conecta ni cambia el FortiGate.
[Net.ServicePointManager]::SecurityProtocol=[Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
if (-not (Get-PackageProvider -Name NuGet -ListAvailable -ErrorAction SilentlyContinue)) {
    Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Scope CurrentUser -Force | Out-Null
}
if (-not (Get-Module -ListAvailable -Name Posh-SSH | Where-Object Version -eq ([version]'4.0.0'))) {
    Install-Module -Name Posh-SSH -RequiredVersion 4.0.0 -Repository PSGallery -Scope CurrentUser -Force -AllowClobber
}
Import-Module Posh-SSH -RequiredVersion 4.0.0
Write-Host 'Posh-SSH 4.0.0 disponible. Ejecuta primero Auditar-FortiGate.ps1 -Modo Auditar.'
