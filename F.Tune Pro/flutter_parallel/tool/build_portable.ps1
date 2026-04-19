param(
  [string]$ProjectRoot = (Resolve-Path "$PSScriptRoot\..\").Path
)

$ErrorActionPreference = 'Stop'
Set-Location $ProjectRoot

Write-Host '[1/4] flutter clean' -ForegroundColor Cyan
flutter clean | Out-Host

Write-Host '[2/4] flutter pub get' -ForegroundColor Cyan
flutter pub get | Out-Host

Write-Host '[3/4] flutter build windows --release' -ForegroundColor Cyan
flutter build windows --release | Out-Host

$releaseDir = Join-Path $ProjectRoot 'build\windows\x64\runner\Release'
if (-not (Test-Path $releaseDir)) {
  throw 'Release output not found.'
}

$distRoot = Join-Path $ProjectRoot 'dist'
$portableRoot = Join-Path $distRoot 'portable'
$portableDir = Join-Path $portableRoot 'F.Tune Pro Portable'
$zipPath = Join-Path $portableRoot 'F.Tune-Pro-Portable.zip'

if (Test-Path $portableDir) { Remove-Item $portableDir -Recurse -Force }
if (Test-Path $zipPath) { Remove-Item $zipPath -Force }
New-Item -ItemType Directory -Path $portableDir -Force | Out-Null

Write-Host '[4/4] Copy release files + zip portable' -ForegroundColor Cyan
Copy-Item (Join-Path $releaseDir '*') $portableDir -Recurse -Force
Compress-Archive -Path (Join-Path $portableDir '*') -DestinationPath $zipPath -Force

Write-Host ''
Write-Host 'Portable ready:' -ForegroundColor Green
Write-Host "- Folder: $portableDir"
Write-Host "- Zip   : $zipPath"
