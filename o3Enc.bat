@echo off
chcp 65001 > nul
setlocal enabledelayedexpansion

set "TEMP_FILES="

goto :main

REM ===================================================================
REM Main
REM ===================================================================
:main
cls
echo ============================================================
echo                        o3Enc 1.0.1
echo             NVEnc Encoding Utility
echo      https://github.com/oo0v/o3enc
echo ============================================================
echo.

call :initialize_environment || exit /b 1

if "%~1"=="" (
    endlocal
    pause
    exit /b 0
)

call :validate_input_file "%~1" || exit /b 1
call :load_presets || exit /b 1
call :analyze_input_video "%~1" || exit /b 1
call :analyze_color_settings || exit /b 1
call :process_queue "%~1" || exit /b 1
call :analyze_volume || exit /b 1
call :encode_presets || exit /b 1
call :show_results || exit /b 1

call :cleanup
echo Processing completed.
endlocal
pause
exit /b 0

REM ===================================================================
REM Core infrastructure
REM ===================================================================
:error_exit
set "error_message=%~1"
call :cleanup
echo.
echo.
echo      ERROR
echo.
echo %error_message%
endlocal
pause
exit /b 1

:cleanup
for %%f in (%TEMP_FILES%) do (
    if exist "%%f" del /f /q "%%f"
)
del /f /q ffmpeg2pass-*.log* 2>nul
exit /b 0

REM ===================================================================
REM Initialization
REM ===================================================================
:initialize_environment
echo Initializing system environment...

set "TEMP_DIR=%temp%\o3enc_%random%\\"
mkdir "%TEMP_DIR%" 2>nul || (
    call :error_exit "Failed to create temporary directory"
    exit /b 1
)
set "TEMP_FILES=%TEMP_FILES% %TEMP_DIR%"

REM Initialize core variables
set "BIN_DIR=%~dp0bin"
set "TOOLS_DIR=%~dp0tools"
set "FFCMD="%BIN_DIR%\ffmpeg""
set "PROBECMD="%BIN_DIR%\ffprobe""

set "INPUT_OPTIONS=-hwaccel cuda"
set "AUDIO_OPTIONS=-c:a aac -b:a 128k -ac 2"
set "LOG_OPTIONS=-loglevel warning -stats"

echo Checking required components in bin directory...
REM Verify required tools and install if missing
for %%t in (ffmpeg ffprobe) do (
    if not exist "%BIN_DIR%\%%t.exe" (
        echo %%t.exe not found in bin directory.
        if exist "%TOOLS_DIR%\initialize.bat" (
            echo Running initialization script...
            pushd "%TOOLS_DIR%"
            call initialize.bat
            popd
            if not exist "%BIN_DIR%\%%t.exe" (
                call :error_exit "Failed to install %%t.exe"
                exit /b 1
            )
        ) else (
            call :error_exit "initialize.bat not found in tools directory"
            exit /b 1
        )
        echo %%t.exe installation completed.
    )
)

echo Testing CUDA functionality...
%FFCMD% -hwaccel cuda -f lavfi -i color=black:s=1280x720 -frames:v 1 -an -f null - >nul 2>&1 || (
    call :error_exit "NVIDIA CUDA acceleration not available on this system"
    exit /b 1
)

echo Initialization completed successfully.
echo.
exit /b 0

REM ===================================================================
REM Validation
REM ===================================================================
:validate_input_file
set "input_file=%~1"

if not defined input_file (
    call :error_exit "No input file specified. Usage: Drag and drop a video file onto this script."
    exit /b 1
)

if not exist "%input_file%" (
    call :error_exit "Input file not found: '%input_file%'"
    exit /b 1
)

REM Verify video format
set "probe_output=%TEMP_DIR%probe_output.txt"
set "TEMP_FILES=%TEMP_FILES% %probe_output%"

ffprobe -v error -select_streams v:0 -show_entries stream=codec_type,duration -of default=noprint_wrappers=1:nokey=1 "%input_file%" > "%probe_output%" 2>&1 || (
    call :error_exit "Failed to analyze input file"
    exit /b 1
)

for /f "tokens=*" %%i in (%probe_output%) do (
    set /a "count+=1"
    if !count!==1 set "codec_type=%%i"
    if !count!==2 set "duration=%%i"
)

if /i not "%codec_type%"=="video" (
    call :error_exit "The input file is not a valid video file"
    exit /b 1
)

if "%duration%"=="" (
    call :error_exit "The input file appears to be an image or unsupported format"
    exit /b 1
)

if "%duration%"=="N/A" (
    call :error_exit "The input file appears to be an image or unsupported format"
    exit /b 1
)

exit /b 0

REM ===================================================================
REM Load Presets
REM ===================================================================
:load_presets
echo.

set "preset_file=%~dp0presets.ini"
if not exist "%preset_file%" (
    echo Preset file not found. Creating default configuration...
    call :create_default_presets
)

set "preset_count=0"
set "presets="

echo Reading preset configurations...

set "current_preset="
set "preset_section=0"

REM Read file line
for /f "usebackq tokens=1,* delims==" %%a in ("%preset_file%") do (
    set "line=%%a"
    set "value=%%b"
    
    if "!line!"=="preset_start:" (
        set "preset_section=1"
    ) else if "!preset_section!"=="1" (
        if "!line:~0,1!"=="[" (
            if defined current_preset (
                if not defined preset[!current_preset!].encoder (
                    call :error_exit "Invalid configuration in preset [!current_preset!]"
                    exit /b 1
                )
            )
            
            set "current_preset=!line:~1,-1!"
            set /a "preset_count+=1"
            set "presets=!presets!!current_preset! "
        ) else if defined current_preset (
            set "preset[!current_preset!].!line!=!value!"
        )
    )
)

echo Successfully loaded %preset_count% encoding presets.
echo.
exit /b 0

:create_default_presets
echo Creating default encoding presets...
(
    echo =====================================================
    echo o3Enc Encoding Presets
    echo Custom presets can be added to this file.
    echo [Preset-Name]
    echo encoder=^<encoder_name^>     : nvenc encoder (h264_nvenc/hevc_nvenc/av1_nvenc^)
    echo container=^<container_name^> : output format (mp4/mkv/mov/webm..^)
    echo height=^<height^>            : output height (empty for source^)
    echo fps=^<fps^>                  : output fps (empty for source^)
    echo pixfmt=^<pixel_format^>      : yuv420p/yuv444p (yuv422p is not recommended^)
    echo scale_flags=^<flags^>        : scaling algorithm (neighbor/bilinear/bicubic/lanczos/spline/area/etc..^)
    echo options=^<ffmpeg_options^>   : specific options (For advanced users^)
    echo =====================================================
    echo.
    echo preset_start:
    echo [Archive-HEVC-yuv444]
    echo encoder=hevc_nvenc
    echo container=mp4
    echo height=
    echo fps=
    echo pixfmt=yuv444p
    echo scale_flags=bilinear
    echo options=-preset p7 -rc:v constqp -init_qpI 18 -init_qpP 18 -init_qpB 20 -rc-lookahead 53 -bf 2 -refs 16 -b_ref_mode each
    echo.
    echo [Archive-HEVC-yuv420]
    echo encoder=hevc_nvenc
    echo container=mp4
    echo height=
    echo fps=
    echo pixfmt=yuv420p
    echo scale_flags=bilinear
    echo options=-preset p7 -rc:v constqp -init_qpI 18 -init_qpP 18 -init_qpB 20 -rc-lookahead 53 -bf 2 -refs 16 -b_ref_mode each
    echo.
    echo [Archive-HEVC-yuv444-1440p]
    echo encoder=hevc_nvenc
    echo container=mp4
    echo height=1440
    echo fps=
    echo pixfmt=yuv444p
    echo scale_flags=bilinear
    echo options=-preset p7 -rc:v constqp -init_qpI 18 -init_qpP 18 -init_qpB 20 -rc-lookahead 53 -bf 2 -refs 16 -b_ref_mode each
    echo.
    echo [Archive-HEVC-yuv420-1440p]
    echo encoder=hevc_nvenc
    echo container=mp4
    echo height=1440
    echo fps=
    echo pixfmt=yuv420p
    echo scale_flags=bilinear
    echo options=-preset p7 -rc:v constqp -init_qpI 18 -init_qpP 18 -init_qpB 20 -rc-lookahead 53 -bf 2 -refs 16 -b_ref_mode each
    echo.
    echo [Archive-H264-yuv444]
    echo encoder=h264_nvenc
    echo container=mp4
    echo height=
    echo fps=
    echo pixfmt=yuv444p
    echo scale_flags=bilinear
    echo options=-preset p7 -rc:v constqp -init_qpI 18 -init_qpP 18 -init_qpB 20 -rc-lookahead 53 -bf 2 -refs 16 -b_ref_mode each
    echo.
    echo [Archive-H264-yuv420]
    echo encoder=h264_nvenc
    echo container=mp4
    echo height=
    echo fps=
    echo pixfmt=yuv420p
    echo scale_flags=bilinear
    echo options=-preset p7 -rc:v constqp -init_qpI 18 -init_qpP 18 -init_qpB 20 -rc-lookahead 53 -bf 2 -refs 16 -b_ref_mode each
    echo.
    echo [Archive-H264-yuv444-1440p]
    echo encoder=h264_nvenc
    echo container=mp4
    echo height=1440
    echo fps=
    echo pixfmt=yuv444p
    echo scale_flags=bilinear
    echo options=-preset p7 -rc:v constqp -init_qpI 18 -init_qpP 20 -init_qpB 22 -rc-lookahead 53 -bf 2 -refs 16 -b_ref_mode each
    echo.
    echo [Archive-H264-yuv420-1440p]
    echo encoder=h264_nvenc
    echo container=mp4
    echo height=1440
    echo fps=
    echo pixfmt=yuv420p
    echo scale_flags=bilinear
    echo options=-preset p7 -rc:v constqp -init_qpI 18 -init_qpP 20 -init_qpB 22 -rc-lookahead 53 -bf 2 -refs 16 -b_ref_mode each
    echo.
    echo [Iwara-2160p60fps]
    echo encoder=h264_nvenc
    echo container=mp4
    echo height=2160
    echo fps=60
    echo pixfmt=yuv420p
    echo scale_flags=bilinear
    echo options=-preset p7 -b:v 23600k -maxrate:v 23800k -bufsize:v 47600k -rc-lookahead 32 -bf 2 -refs 16 -b_ref_mode each
    echo.
    echo [Iwara-2160p30fps]
    echo encoder=h264_nvenc
    echo container=mp4
    echo height=2160
    echo fps=30
    echo pixfmt=yuv420p
    echo scale_flags=bilinear
    echo options=-preset p7 -b:v 16800k -maxrate:v 17000k -bufsize:v 34000k -rc-lookahead 32 -bf 2 -refs 16 -b_ref_mode each
    echo.
    echo [Iwara-1440p60fps]
    echo encoder=h264_nvenc
    echo container=mp4
    echo height=1440
    echo fps=60
    echo pixfmt=yuv420p
    echo scale_flags=bilinear
    echo options=-preset p7 -b:v 15900k -maxrate:v 16100k -bufsize:v 32200k -rc-lookahead 32 -bf 2 -refs 16 -b_ref_mode each
    echo.
    echo [Iwara-1440p30fps]
    echo encoder=h264_nvenc
    echo container=mp4
    echo height=1440
    echo fps=30
    echo pixfmt=yuv420p
    echo scale_flags=bilinear
    echo options=-preset p7 -b:v 11300k -maxrate:v 11500k -bufsize:v 23000k -rc-lookahead 32 -bf 2 -refs 16 -b_ref_mode each
    echo.
    echo [Iwara-1080p60fps]
    echo encoder=h264_nvenc
    echo container=mp4
    echo height=1080
    echo fps=60
    echo pixfmt=yuv420p
    echo scale_flags=bilinear
    echo options=-preset p7 -b:v 10300k -maxrate:v 10500k -bufsize:v 21000k -rc-lookahead 32 -bf 2 -refs 16 -b_ref_mode each
    echo.
    echo [Iwara-1080p30fps]
    echo encoder=h264_nvenc
    echo container=mp4
    echo height=1080
    echo fps=30
    echo pixfmt=yuv420p
    echo scale_flags=bilinear
    echo options=-preset p7 -b:v 7300k -maxrate:v 7500k -bufsize:v 15000k -rc-lookahead 32 -bf 2 -refs 16 -b_ref_mode each
    echo.
    echo [Iwara-720p60fps]
    echo encoder=h264_nvenc
    echo container=mp4
    echo height=720
    echo fps=60
    echo pixfmt=yuv420p
    echo scale_flags=bilinear
    echo options=-preset p7 -b:v 6100k -maxrate:v 6300k -bufsize:v 12600k -rc-lookahead 32 -bf 2 -refs 16 -b_ref_mode each
    echo.
    echo [Iwara-720p30fps]
    echo encoder=h264_nvenc
    echo container=mp4
    echo height=720
    echo fps=30
    echo pixfmt=yuv420p
    echo scale_flags=bilinear
    echo options=-preset p7 -b:v 4300k -maxrate:v 4500k -bufsize:v 9000k -rc-lookahead 32 -bf 2 -refs 16 -b_ref_mode each
) > "%preset_file%" || (
    call :error_exit "Failed to create default presets file"
    exit /b 1
)
echo Default presets created successfully.
echo.
exit /b 0

REM ===================================================================
REM Video analysis and preparation
REM ===================================================================
:analyze_input_video
echo.

set "width="
set "height="
set "frames="
set "fps="
set "codec="
set "duration="
set "bitrate="
set "pixfmt="
set "colorspace="
set "colortrc="
set "colorprim="
set "colorrange="
set "r_frame_rate="
set "chroma_location="
set "field_order="

echo Analyzing input video file...

REM Get video stream info
for /f "tokens=1,2 delims==" %%a in ('ffprobe -v quiet -select_streams v:0 -print_format flat -show_entries stream^=width^,height^,r_frame_rate^,nb_frames^,codec_name^,duration^,bit_rate^,pix_fmt^,color_space^,color_transfer^,color_primaries^,color_range^,field_order^,chroma_location "%~1" 2^>^&1') do (
    set "line=%%a"
    set "value=%%~b"
    set "line=!line:streams.stream.0.=!"
    
    if "!line!"=="width" set "width=!value!"
    if "!line!"=="height" set "height=!value!"
    if "!line!"=="r_frame_rate" set "r_frame_rate=!value!"
    if "!line!"=="nb_frames" set "frames=!value!"
    if "!line!"=="codec_name" set "codec=!value!"
    if "!line!"=="duration" set "duration=!value!"
    if "!line!"=="bit_rate" set "bitrate=!value!"
    if "!line!"=="pix_fmt" set "pixfmt=!value!"
    if "!line!"=="color_space" set "colorspace=!value!"
    if "!line!"=="color_transfer" set "colortrc=!value!"
    if "!line!"=="color_primaries" set "colorprim=!value!"
    if "!line!"=="color_range" set "colorrange=!value!"
    if "!line!"=="chroma_location" set "chroma_location=!value!"
    if "!line!"=="field_order" set "field_order=!value!"
)

REM Calculate FPS from frame rate
if defined r_frame_rate (
    for /f "tokens=1,2 delims=/" %%a in ("!r_frame_rate!") do (
        set /a "fps=%%a/%%b"
    )
)

REM Calculate file size in MB
for %%A in ("%~1") do set "size_bytes=%%~zA"
set "size_mb=0"
set "remainder_bytes=%size_bytes%"

:divide_loop
if "%remainder_bytes%"=="" goto :end_divide
if "%remainder_bytes%"=="0" goto :end_divide
set /a "size_mb=(size_mb * 1024) + (remainder_bytes >> 20)"
set /a "remainder_bytes=(remainder_bytes & 1048575)"
if %remainder_bytes% GTR 0 (
    set /a "size_mb+=1"
)
goto :end_divide

:end_divide

echo Video Properties:
echo  ---------------------------------------
echo   Resolution     : %width% x %height%
echo   Frame Rate     : %fps% fps
echo   Duration       : %duration% seconds
echo   Codec          : %codec%
echo   Pixel Format   : %pixfmt%
echo   Color Range    : %colorrange%
echo   Color Space    : %colorspace%
echo   Color Transfer : %colortrc%
echo   Color Primaries: %colorprim%
echo   Field Order    : %field_order%
echo   File Size      : %size_mb% MB
echo  ---------------------------------------
echo.

exit /b 0

REM ===================================================================
REM Color management and audio analysis
REM ===================================================================
:analyze_color_settings
echo.

set "color_filters="

REM Handle unknown colorspace
if "%colorspace%"=="unknown" (
    call :show_color_config_menu
    if errorlevel 1 exit /b 1
    
    if "!colorspace!"=="bt601-6-625" (
        set "color_filters=colorspace=all=bt709:iall=bt601-6-625"
    ) else if "!colorspace!"=="bt709" (
        set "color_filters=colorspace=all=bt709:iall=bt709"
    )
)

REM Handle unknown range
if "%colorrange%"=="unknown" (
    call :show_range_config_menu
    if errorlevel 1 exit /b 1
    
    if "!colorrange!"=="tv" (
        if defined color_filters (
            set "color_filters=%color_filters%:range=tv:irange=tv"
        ) else (
            set "color_filters=range=tv:irange=tv"
        )
    ) else if "!colorrange!"=="pc" (
        if defined color_filters (
            set "color_filters=%color_filters%:range=pc:irange=pc"
        ) else (
            set "color_filters=range=pc:irange=pc"
        )
    )
)

echo.
echo Color space conversion:
if defined color_filters (
    echo Filters: %color_filters%
) else (
    echo Metadata detected
    echo No conversion filters needed
)
echo.
exit /b 0

:show_color_config_menu
echo Please select color space standard:
echo   -----------------------------------------------
echo   [1] Standard Definition (BT.601-6-625)
echo       - Optimized for SD content
echo       - For raw video output from MMD, select this option
echo.
echo   [2] High Definition (BT.709)
echo       - Optimized for HD content
echo       - Recommended for modern HD/4K
echo   -----------------------------------------------
echo.

:get_color_config_choice
set /p "color_choice=Enter your selection (1-2): "

if "%color_choice%"=="1" (
    set "colorspace=bt601-6-625"
    exit /b 0
)
if "%color_choice%"=="2" (
    set "colorspace=bt709"
    exit /b 0
)

echo Error: Invalid selection. Please enter 1 or 2.
goto :get_color_config_choice

:show_range_config_menu
echo Please select color range:
echo   -----------------------------------------------
echo   [1] TV/Limited Range (16-235)
echo       - Standard for broadcast content
echo       - For raw video output from MMD, select this option
echo.
echo   [2] PC/Full Range (0-255)
echo       - Full dynamic range
echo       - Recommended for modern HD/4K
echo   -----------------------------------------------
echo.

:get_range_config_choice
set /p "range_choice=Enter your selection (1-2): "

if "%range_choice%"=="1" (
    set "colorrange=tv"
    exit /b 0
)
if "%range_choice%"=="2" (
    set "colorrange=pc"
    exit /b 0
)

echo Error: Invalid selection. Please enter 1 or 2.
goto :get_range_config_choice

:analyze_volume
echo.

REM Check for audio track
ffprobe -v error -select_streams a -show_entries stream=codec_name -of csv=p=0 "%input_file%" > nul 2>&1
if %errorlevel% neq 0 (
    echo No audio track detected in the input file.
    echo Skipping audio normalization process.
    set "VOLUME_NORM=anull"
    exit /b 0
)

echo Analyzing audio levels...

set "temp_stats=%temp%\loudnorm_stats.txt"
set "TEMP_FILES=%TEMP_FILES% %temp_stats%"

ffmpeg %INPUT_OPTIONS% -i "%input_file%" -af "loudnorm=I=-18:LRA=7:print_format=json" -f null NUL 2>"%temp_stats%" || (
    call :error_exit "Audio analysis failed"
    exit /b 1
)

REM Parse loudnorm stats
for /f "tokens=2 delims=:," %%a in ('findstr "input_i" "%temp_stats%"') do set "input_i=%%a"
for /f "tokens=2 delims=:," %%a in ('findstr "input_lra" "%temp_stats%"') do set "input_lra=%%a"
for /f "tokens=2 delims=:," %%a in ('findstr "input_tp" "%temp_stats%"') do set "input_tp=%%a"
for /f "tokens=2 delims=:," %%a in ('findstr "input_thresh" "%temp_stats%"') do set "input_thresh=%%a"
for /f "tokens=2 delims=:," %%a in ('findstr "target_offset" "%temp_stats%"') do set "target_offset=%%a"

REM LKFS=-18
set "VOLUME_NORM=loudnorm=I=-18:LRA=7:TP=-2:measured_I=!input_i!:measured_LRA=!input_lra!:measured_TP=!input_tp!:measured_thresh=!input_thresh!:offset=!target_offset!:linear=true:print_format=summary"

echo Audio Analysis Results:
echo   -------------------------------------
echo   Input Loudness   : !input_i! LUFS
echo   Loudness Range   : !input_lra! LU
echo   True Peak Level  : !input_tp! dB
echo   -------------------------------------

exit /b 0

REM ===================================================================
REM Queue processing and encoding
REM ===================================================================
:process_queue
echo.

echo Available Encoding Presets:
set "preset_idx=1"
for %%p in (!presets!) do (
    echo [!preset_idx!] %%p
    set /a "preset_idx+=1"
)
echo.
echo Commands:
echo  * Enter numbers (1-%preset_count%) - Add presets to queue
echo  * Q - Finish selection and proceed
echo  * R - Reset queue and start over
echo.

set "selected_presets="
set "queue="

:queue_input
if "!queue!"=="" (
    echo [Empty] No presets selected
) else (
    echo Selected presets:
    for %%n in (!queue!) do (
        set /a "preset_idx=1"
        for %%p in (!presets!) do (
            if "%%n"=="!preset_idx!" echo   * %%p
            set /a "preset_idx+=1"
        )
    )
)
echo.

set /p "input=Select presets (1-%preset_count%, comma-separated, Q/R): "

if not defined input goto :queue_input

if /i "!input!"=="Q" (
    if "!queue!"=="" (
        echo Error: Queue is empty. Please select at least one preset.
        echo.
        goto :queue_input
    )
    goto :setup_output_name
)

if /i "!input!"=="R" (
    set "queue="
    set "selected_presets="
    echo Queue has been reset.
    echo.
    goto :queue_input
)

REM Process comma-separated input
set "input=!input!,"
set "current_number="
set "show_queue=0"

:process_next_number
for /f "delims=, tokens=1*" %%a in ("!input!") do (
    set "number=%%a"
    set "input=%%b"
)

REM Trim spaces
set "number=!number: =!"

if not defined number (
    if !show_queue! equ 1 (
        echo.
        echo Updated Queue:
        for %%n in (!queue!) do (
            set /a "preset_idx=1"
            for %%p in (!presets!) do (
                if "%%n"=="!preset_idx!" echo   * %%p
                set /a "preset_idx+=1"
            )
        )
        echo.
    )
    goto :queue_input
)

REM Validate number
set /a "valid_number=number" 2>nul || (
    echo Error: Invalid input "!number!" - Must be a number
    goto :process_remaining
)

if !valid_number! lss 1 (
    echo Error: Number must be at least 1
    goto :process_remaining
)

if !valid_number! gtr !preset_count! (
    echo Error: Number must not exceed !preset_count!
    goto :process_remaining
)

REM Check for duplicates
set "is_duplicate="
if defined queue (
    for %%n in (!queue!) do (
        if "%%n"=="!valid_number!" (
            set "is_duplicate=1"
            set "duplicate_preset="
            set /a "preset_idx=1"
            for %%p in (!presets!) do (
                if !preset_idx!==!valid_number! set "duplicate_preset=%%p"
                set /a "preset_idx+=1"
            )
            echo Notice: Skipping [!duplicate_preset!] - Already in queue
            set "show_queue=1"
        )
    )
)

if not defined is_duplicate (
    if "!queue!"=="" (
        set "queue=!valid_number!"
    ) else (
        set "queue=!queue! !valid_number!"
    )
    
    set /a "preset_idx=1"
    for %%p in (!presets!) do (
        if !preset_idx!==!valid_number! (
            if "!selected_presets!"=="" (
                set "selected_presets=%%p"
            ) else (
                set "selected_presets=!selected_presets! %%p"
            )
            echo Added: [%%p]
            set "show_queue=1"
        )
        set /a "preset_idx+=1"
    )
)

:process_remaining
if defined input goto :process_next_number
goto :queue_input

:setup_output_name
echo.

echo Current input filename: %~n1
:ask_use_original_filename
set /p "use_original=Use input filename as base? (Y/N): "

if /i "%use_original%"=="Y" (
    set "output_name=%~n1"
    goto :prepare_output_files
) else if /i "%use_original%"=="N" (
    goto :get_filename
) else (
    echo Error: Invalid input. Please enter Y or N.
    goto :ask_use_original_filename
)


:get_filename
echo.
set /p "output_name=Enter custom output filename (without extension): "
if not defined output_name (
    echo Error: Filename cannot be empty
    goto :get_filename
)
goto :prepare_output_files

:get_next_version
set "base=%~1"
set "ext=%~2"
set "version_num=01"

:version_loop
if exist "!base!_v!version_num!.!ext!" (
    set /a "current_ver=1!version_num! - 100"
    set /a "next_ver=!current_ver! + 1"
    if !next_ver! LSS 10 (
        set "version_num=0!next_ver!"
    ) else (
        set "version_num=!next_ver!"
    )
    goto :version_loop
)
exit /b 0

:prepare_output_files
echo.
echo Preview of Output Files:

set "preset_number=1"
for %%p in (!presets!) do (
    set "preset_to_number[%%p]=!preset_number!"
    set /a "preset_number+=1"
)

for %%p in (!selected_presets!) do (
    set "container=mp4"
    if defined preset[%%p].container set "container=!preset[%%p].container!"
    
    set "output_height=!height!"
    if defined preset[%%p].height set "output_height=!preset[%%p].height!"
    
    set "output_fps=!fps!"
    if defined preset[%%p].fps set "output_fps=!preset[%%p].fps!"
    
    set "current_preset_num=!preset_to_number[%%p]!"
    
    set "base_name=!output_name!_preset!current_preset_num!_!preset[%%p].encoder!_!output_height!p!output_fps!fps"
    
    call :get_next_version "!base_name!" "!container!"
    set "outputs[%%p]=!base_name!_v!version_num!.!container!"

    call :generate_encode_command "%%p" "%~1"
    
    echo.
    echo Preset: [%%p]
    echo ------------------------------------------------------------
    echo Output File : !base_name!_v!version_num!.!container!
    echo Resolution  : !output_height!p
    echo Frame Rate  : !output_fps! fps
    echo Encoder     : !preset[%%p].encoder!
    echo Pixel Format: !preset[%%p].pixfmt!
    echo.
    echo First Pass Command:
    echo ffmpeg !encode_cmd[%%p]! -pass 1 -an -f null NUL
    echo.
    echo Second Pass Command:
    echo ffmpeg !encode_cmd[%%p]! -pass 2 %AUDIO_OPTIONS% -af "%VOLUME_NORM%" "!outputs[%%p]!"
    echo ------------------------------------------------------------
)

set /p "confirm=Proceed with these output presets? (Y/N): "
if /i not "%confirm%"=="Y" goto :process_queue
exit /b 0

:generate_encode_command
set "preset=%~1"
set "input_path=%~2"

REM Setup video filters
set "video_filters=format=!preset[%preset%].pixfmt!"
if defined preset[%preset%].height (
    if !preset[%preset%].height! NEQ !height! (
        set "scale_flags=bicubic"
        if defined preset[%preset%].scale_flags set "scale_flags=!preset[%preset%].scale_flags!"
        set "video_filters=!video_filters!,scale=-1:!preset[%preset%].height!:flags=!scale_flags!"
    )
)
if defined preset[%preset%].fps (
    if !preset[%preset%].fps! NEQ !fps! (
        set "video_filters=!video_filters!,fps=!preset[%preset%].fps!"
    )
)

REM Add color filters if needed
if defined color_filters set "video_filters=!video_filters!,!color_filters!"

REM Store the base command for the preset
set "encode_cmd[%preset%]=%INPUT_OPTIONS% -i "%input_path%" -c:v !preset[%preset%].encoder! !preset[%preset%].options! %LOG_OPTIONS% -vf "!video_filters!""

exit /b 0

:encode_presets
echo.

for %%p in (!selected_presets!) do (
    echo Processing Preset: [%%p]
    echo ----------------------------------------
    
    set "current_output=!outputs[%%p]!"
    
    echo First Pass Encoding...
    set "ffmpeg_params=!encode_cmd[%%p]! -pass 1 -an -f null NUL"
    echo Command: ffmpeg !ffmpeg_params!
    echo.
    
    ffmpeg !ffmpeg_params! || (
        call :error_exit "First pass encoding failed for preset [%%p]"
        exit /b 1
    )
    
    echo.
    echo Second Pass Encoding...
    set "ffmpeg_params=!encode_cmd[%%p]! -pass 2 %AUDIO_OPTIONS% -af "%VOLUME_NORM%" "!current_output!""
    echo Command: ffmpeg !ffmpeg_params!
    echo.
    
    ffmpeg !ffmpeg_params! || (
        call :error_exit "Second pass encoding failed for preset [%%p]"
        exit /b 1
    )
    
    echo.
    echo Encoding completed successfully for preset [%%p]
    echo.
)

del /f /q ffmpeg2pass-*.log* 2>nul
exit /b 0

:show_results
echo.

for %%p in (!selected_presets!) do (
    echo Results for Preset: [%%p]
    echo ----------------------------------------
    
    set "current_output=!outputs[%%p]!"
    
    if exist "!current_output!" (
        for /f "tokens=1,2 delims==" %%a in ('ffprobe -v quiet -select_streams v:0 -print_format flat -show_entries stream^=width^,height^,r_frame_rate^,codec_name^,pix_fmt^,color_space^,color_range "!current_output!" 2^>^&1') do (
            set "line=%%a"
            set "value=%%~b"
            set "line=!line:streams.stream.0.=!"
            
            if "!line!"=="width" set "width=!value!"
            if "!line!"=="height" set "height=!value!"
            if "!line!"=="r_frame_rate" set "r_frame_rate=!value!"
            if "!line!"=="codec_name" set "codec=!value!"
            if "!line!"=="pix_fmt" set "pixfmt=!value!"
            if "!line!"=="color_space" set "colorspace=!value!"
            if "!line!"=="color_range" set "colorrange=!value!"
        )
        
        for /f "tokens=1,2 delims=/" %%a in ("!r_frame_rate!") do set /a "fps=%%a/%%b"
        
        for %%A in ("!current_output!") do set /a "size_mb=%%~zA / 1024 / 1024"
        
        echo Output File    : !current_output!
        echo Resolution     : !width! x !height!
        echo Frame Rate     : !fps! fps
        echo Codec          : !codec!
        echo File Size      : !size_mb! MB
        echo Pixel Format   : !pixfmt!
        echo Color Space    : !colorspace!
        echo Color Range    : !colorrange!
        
    ) else (
        echo Error: Output file was not created
    )
    echo.
)

exit /b 0