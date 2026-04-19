@echo off
setlocal
cd /d "%~dp0"

echo [1/2] Building portable package...
powershell -NoProfile -ExecutionPolicy Bypass -File "tool\build_portable.ps1"
if errorlevel 1 goto :fail

echo.
echo [2/2] Building installer package...
powershell -NoProfile -ExecutionPolicy Bypass -File "tool\build_installer.ps1"
if errorlevel 1 goto :fail

echo.
echo Done. Output folder: dist
pause
exit /b 0

:fail
echo.
echo Build failed.
pause
exit /b 1
