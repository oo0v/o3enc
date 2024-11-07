@echo off
setlocal enabledelayedexpansion

for %%i in ("%~dp0..\bin") do set "INSTALL_PATH=%%~fi"
set "FFMPEG_URL=https://www.gyan.dev/ffmpeg/builds/ffmpeg-release-essentials.zip"
set "DOWNLOAD_PATH=%TEMP%\ffmpeg.zip"

echo.
echo FFmpeg will be downloaded from:
echo %FFMPEG_URL%
echo And installed to:
echo %INSTALL_PATH%
echo.
set /p "CONFIRM=Proceed with installation? (Y/N): "
if /i not "%CONFIRM%"=="Y" (
    echo Installation cancelled by user.
    endlocal
    exit /b 1
)

echo Starting FFmpeg installation...

if not exist "%INSTALL_PATH%" (
    mkdir "%INSTALL_PATH%"
    echo Created bin directory: %INSTALL_PATH%
)

if exist "%INSTALL_PATH%\ffmpeg.exe" (
    echo FFmpeg is already installed.
    endlocal
    goto :EOF
)

echo Downloading FFmpeg...

powershell -Command ^
    "Invoke-WebRequest -Uri '%FFMPEG_URL%' -OutFile '%DOWNLOAD_PATH%'"

if not exist "%DOWNLOAD_PATH%" (
    echo Download failed.
    goto :ERROR
)

echo Extracting FFmpeg...

powershell -Command ^
    "Expand-Archive -Path '%DOWNLOAD_PATH%' -DestinationPath '%TEMP%\ffmpeg_temp' -Force"

for /r "%TEMP%\ffmpeg_temp" %%F in (ffmpeg.exe ffprobe.exe ffplay.exe) do (
    copy "%%F" "%INSTALL_PATH%" > nul
)

del "%DOWNLOAD_PATH%"
rmdir /s /q "%TEMP%\ffmpeg_temp"

echo FFmpeg installation completed successfully.
echo.
echo Installation directory structure:
echo - bin/
echo    - ffmpeg.exe
echo    - ffprobe.exe
echo    - ffplay.exe

endlocal
goto :EOF

:ERROR
echo An error occurred during installation.
endlocal
pause
exit /b 1