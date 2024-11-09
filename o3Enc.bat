@echo off
chcp 65001 > nul
setlocal enabledelayedexpansion

echo ===============================================
echo                        o3Enc 1.1.2
echo             NVEnc Encoding Utility
echo      https://github.com/oo0v/o3enc
echo ===============================================
echo.

if "%~1"=="" (
    python "%~dp0src\core.py" --init
    endlocal
    pause
    exit /b 0
)

python "%~dp0src\core.py" "%~1"
if errorlevel 1 (
    echo.
    endlocal
    pause
    exit /b 1
)

exit /b 0