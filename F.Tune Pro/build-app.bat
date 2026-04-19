@echo off
title F.Tuning Pro - Build Tool
color 0b
cd /d "%~dp0"

set "BUILD_LOG=dist\build.log"

echo [1/4] Dang don dep thu muc cu...
if exist dist rd /s /q dist
mkdir dist >nul 2>&1

echo [2/4] Dang build Electron (Vui long cho)...
echo Build log: %BUILD_LOG%
powershell -NoProfile -ExecutionPolicy Bypass -Command "& { npm run build 2>&1 | Tee-Object -FilePath '%BUILD_LOG%'; exit $LASTEXITCODE }"

:: Kiem tra neu build loi thi dung lai
if %errorlevel% neq 0 (
    color 0c
    echo.
    echo [!] LOI: Qua trinh build that bai. Thu muc 'dist' se khong duoc tao.
    echo [!] Vui long kiem tra log tai: %BUILD_LOG%
    pause
    exit /b
)

echo [3/4] Dang nen UPX...
for /r "dist" %%f in (*.exe) do (
    if exist "upx.exe" (
        echo [UPX] Compressing %%f
        upx.exe --ultra-brute "%%f"
    )
)

echo.
echo [4/4] HOAN THANH!
echo [i] Log file: %BUILD_LOG%
start "" notepad "%BUILD_LOG%"
start "" "dist"
pause
