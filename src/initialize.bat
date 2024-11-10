@echo off
setlocal enabledelayedexpansion enableextensions
chcp 65001 > nul

for %%i in ("%~dp0..\bin") do set "LONG_PATH=%%~fi"
for %%i in ("!LONG_PATH!") do set "INSTALL_PATH=%%~si"

set "FFMPEG_URL=https://www.gyan.dev/ffmpeg/builds/ffmpeg-release-essentials.zip"
set "DOWNLOAD_PATH=%TEMP%\ffmpeg_%RANDOM%.zip"

echo.
echo FFmpeg will be downloaded from:
echo %FFMPEG_URL%
echo And installed to:
echo %LONG_PATH%
echo (Internal path: %INSTALL_PATH%)
echo.
set /p "CONFIRM=Proceed with installation? (Y/N): "
if /i not "!CONFIRM!"=="Y" (
    echo Installation cancelled by user.
    endlocal
    exit /b 1
)

echo Starting FFmpeg installation...

if not exist "!INSTALL_PATH!" (
    mkdir "!INSTALL_PATH!"
    echo Created bin directory: !LONG_PATH!
)

if exist "!INSTALL_PATH!\ffmpeg.exe" (
    echo FFmpeg is already installed.
    endlocal
    goto :EOF
)

echo Downloading FFmpeg...

powershell -Command ^
    "Invoke-WebRequest -Uri '%FFMPEG_URL%' -OutFile '%DOWNLOAD_PATH%'"

if not exist "!DOWNLOAD_PATH!" (
    echo Download failed.
    goto :ERROR
)

echo Extracting FFmpeg...

set "TEMP_EXTRACT_DIR=%TEMP%\ffmpeg_temp_%RANDOM%"
powershell -Command ^
    "Expand-Archive -Path '%DOWNLOAD_PATH%' -DestinationPath '%TEMP_EXTRACT_DIR%' -Force"

for /r "%TEMP_EXTRACT_DIR%" %%F in (ffmpeg.exe ffprobe.exe ffplay.exe) do (
    copy "%%F" "!INSTALL_PATH!" > nul
)

del "!DOWNLOAD_PATH!"
rmdir /s /q "!TEMP_EXTRACT_DIR!"

echo FFmpeg installation completed successfully.
echo.
echo Installation directory structure:
echo.
echo - bin/
echo    - ffmpeg.exe
echo    - ffprobe.exe
echo    - ffplay.exe
echo.

endlocal
goto :EOF

:ERROR
echo An error occurred during installation.
endlocal
pause
exit /b 1