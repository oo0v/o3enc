@echo off
chcp 65001 > nul
setlocal

set "SCRIPT_DIR=%~dp0"

python --version > nul 2>&1
if errorlevel 1 (
    echo Python is not installed or not in PATH
    echo Please install the latest version of Python from https://www.python.org/
    pause
    endlocal
    exit /b 1
)

if "%~1"=="" (
    python "%SCRIPT_DIR%src\core.py" --init
) else (
    python "%SCRIPT_DIR%src\core.py" "%~1"
)

endlocal