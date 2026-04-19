param(
  [string]$Platforms = 'windows,linux,macos'
)

$ErrorActionPreference = 'Stop'

if (-not (Get-Command flutter -ErrorAction SilentlyContinue)) {
  Write-Error 'Flutter SDK is not installed or not on PATH. Install Flutter first, then rerun this script.'
}

Write-Host 'Bootstrapping Flutter project in place...' -ForegroundColor Cyan
flutter create . --platforms=$Platforms --project-name ftune_flutter --org com.ftune.pro
flutter pub get
Write-Host 'Done. You can now run: flutter run -d windows' -ForegroundColor Green
