@echo off
setlocal enabledelayedexpansion enableextensions
chcp 65001 > nul

set "ROOT_DIR=%~dp0.."
set "INSTALL_PATH=%ROOT_DIR%\bin"
set "FFMPEG_URL=https://www.gyan.dev/ffmpeg/builds/ffmpeg-release-essentials.zip"
set "DOWNLOAD_PATH=%TEMP%\ffmpeg_%RANDOM%.zip"
set "EXTRACT_PATH=%TEMP%\ffmpeg_temp_%RANDOM%"

echo.
echo FFmpeg will be downloaded from:
echo %FFMPEG_URL%
echo And installed to:
echo %INSTALL_PATH%
echo.

:PROMPT_INSTALL
set /p "CONFIRM=Proceed with installation? (Y/N): "
if /i "!CONFIRM!"=="Y" goto :START_INSTALL
if /i "!CONFIRM!"=="N" (
    endlocal
    exit /b 2
)
echo Invalid input. Please enter Y or N.
goto :PROMPT_INSTALL

:START_INSTALL
echo Starting FFmpeg installation...

if not exist "%INSTALL_PATH%" mkdir "%INSTALL_PATH%"

if exist "%INSTALL_PATH%\ffmpeg.exe" (
    echo FFmpeg is already installed.
    endlocal
    exit /b 0
)

echo Downloading FFmpeg...
powershell -Command "Invoke-WebRequest '%FFMPEG_URL%' -OutFile '%DOWNLOAD_PATH%'"

if not exist "%DOWNLOAD_PATH%" (
    echo Download failed.
    goto :ERROR
)

echo.
echo Extracting FFmpeg...
if not exist "%EXTRACT_PATH%" mkdir "%EXTRACT_PATH%"

powershell -Command "Expand-Archive '%DOWNLOAD_PATH%' -DestinationPath '%EXTRACT_PATH%'"

echo.
echo Finding FFmpeg binaries...
set "FOUND_FFMPEG="
set "FOUND_FFPROBE="

for /r "%EXTRACT_PATH%" %%F in (ffmpeg.exe) do (
    if not defined FOUND_FFMPEG (
        set "FOUND_FFMPEG=%%F"
    ) else (
        for %%T in ("!FOUND_FFMPEG!") do (
            for %%U in ("%%F") do (
                if %%~tU gtr %%~tT set "FOUND_FFMPEG=%%F"
            )
        )
    )
)

for /r "%EXTRACT_PATH%" %%F in (ffprobe.exe) do (
    if not defined FOUND_FFPROBE (
        set "FOUND_FFPROBE=%%F"
    ) else (
        for %%T in ("!FOUND_FFPROBE!") do (
            for %%U in ("%%F") do (
                if %%~tU gtr %%~tT set "FOUND_FFPROBE=%%F"
            )
        )
    )
)

if not defined FOUND_FFMPEG (
    echo Could not find ffmpeg.exe
    goto :ERROR
)

if not defined FOUND_FFPROBE (
    echo Could not find ffprobe.exe
    goto :ERROR
)

echo Copying binaries...
echo Copying %FOUND_FFMPEG% to %INSTALL_PATH%
copy "%FOUND_FFMPEG%" "%INSTALL_PATH%" > nul
echo Copying %FOUND_FFPROBE% to %INSTALL_PATH%
copy "%FOUND_FFPROBE%" "%INSTALL_PATH%" > nul

echo.
echo Cleaning up temporary files...
if exist "%DOWNLOAD_PATH%" del "%DOWNLOAD_PATH%" 2>nul
if exist "%EXTRACT_PATH%" rmdir /s /q "%EXTRACT_PATH%" 2>nul

echo.
echo FFmpeg installation completed successfully.
echo.
echo Installation directory structure:
echo.
echo - bin/
echo    - ffmpeg.exe
echo    - ffprobe.exe
echo.

endlocal
exit /b 0

:ERROR
echo.
echo An error occurred during installation.
if exist "%DOWNLOAD_PATH%" del "%DOWNLOAD_PATH%" 2>nul
if exist "%EXTRACT_PATH%" rmdir /s /q "%EXTRACT_PATH%" 2>nul
endlocal
exit /b 1