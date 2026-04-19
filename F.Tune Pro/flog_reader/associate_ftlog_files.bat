@echo off
REM F.Tune Log Reader - File Association Setup
REM This script registers .ftlog and .flog file types to open with F.Tune Log Reader

setlocal
cd /d "%~dp0"

REM Try to find the executable in different possible locations
set "EXE_PATH="

if exist "build\windows\x64\runner\Release\ftune_log_reader.exe" (
    set "EXE_PATH=%CD%\build\windows\x64\runner\Release\ftune_log_reader.exe"
) else if exist "ftune_log_reader.exe" (
    set "EXE_PATH=%CD%\ftune_log_reader.exe"
)

if "%EXE_PATH%"=="" (
    echo.
    echo Error: ftune_log_reader.exe not found!
    echo.
    echo Please locate ftune_log_reader.exe and enter its full path:
    set /p "EXE_PATH=Full path to ftune_log_reader.exe: "
)

if not exist "%EXE_PATH%" (
    echo.
    echo Error: File not found at "%EXE_PATH%"
    echo.
    pause
    exit /b 1
)

echo.
echo Found executable at: %EXE_PATH%
echo.
echo Registering F.Tune Log Files with Windows...
echo.

REM Register .ftlog extension
reg add "HKCU\Software\Classes\.ftlog" /ve /d "FTuneLogFile" /f
if errorlevel 1 goto error

REM Register .flog extension
reg add "HKCU\Software\Classes\.flog" /ve /d "FTuneLogFile" /f
if errorlevel 1 goto error

REM Register the FTuneLogFile class description
reg add "HKCU\Software\Classes\FTuneLogFile" /ve /d "F.Tune Log File" /f
if errorlevel 1 goto error

REM Set the icon
reg add "HKCU\Software\Classes\FTuneLogFile\DefaultIcon" /ve /d "%EXE_PATH%" /f
if errorlevel 1 goto error

REM Create the shell open command
reg add "HKCU\Software\Classes\FTuneLogFile\shell\open\command" /ve /d "\"%EXE_PATH%\" \"%%1\"" /f
if errorlevel 1 goto error

echo.
echo ===== SUCCESS =====
echo.
echo .ftlog and .flog files are now associated with F.Tune Log Reader.
echo You can now double-click any .ftlog or .flog file to open it with this app.
echo.
pause
exit /b 0

:error
echo.
echo ===== ERROR =====
echo.
echo Registration failed. You may need to run this script as Administrator.
echo.
echo Try right-clicking this .bat file and selecting "Run as administrator"
echo.
pause
exit /b 1
