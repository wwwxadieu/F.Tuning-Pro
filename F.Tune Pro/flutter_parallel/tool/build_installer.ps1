param(
  [string]$ProjectRoot = (Resolve-Path "$PSScriptRoot\..\").Path,
  [string]$InnoPath = "C:\Program Files (x86)\Inno Setup 6\ISCC.exe"
)

$ErrorActionPreference = 'Stop'
Set-Location $ProjectRoot

Write-Host '[1/4] flutter clean' -ForegroundColor Cyan
flutter clean | Out-Host

Write-Host '[2/4] flutter pub get' -ForegroundColor Cyan
flutter pub get | Out-Host

Write-Host '[3/4] flutter build windows --release' -ForegroundColor Cyan
flutter build windows --release | Out-Host

if (-not (Test-Path $InnoPath)) {
  throw "Inno Setup not found at: $InnoPath"
}

$issPath = Join-Path $ProjectRoot 'tool\build_installer.iss'

Write-Host '[4/4] Build installer by Inno Setup' -ForegroundColor Cyan
& $InnoPath $issPath | Out-Host

Write-Host ''
Write-Host 'Installer ready:' -ForegroundColor Green
Write-Host "- $ProjectRoot\dist\installer"
