@echo off
chcp 65001 > nul
setlocal

echo Creating default presets.ini...

(
echo ================================================================================================================================================
echo o3Enc Encoding Presets
echo Custom presets can be added to this file
echo [Preset-Name]
echo.
echo 2pass=^<bool^>           : Use two-pass encoding (true/false^)
echo.
echo hwaccel=^<accel^>        : Hardware acceleration (cuda, qsv, d3d11va, vaapi, none^)
echo.
echo encoder=^<encoder_name^> : Video encoder (Hardware GPU: h264_nvenc, hevc_nvenc, av1_nvenc, h264_qsv, hevc_qsv, av1_qsv, h264_vaapi, hevc_vaapi, av1_vaapi^)
echo                                        (Distribution: libx264, libx265, libvpx-vp9, libaom-av1, librav1e, libsvtav1^)
echo                                        (Professional: prores, prores_videotoolbox, dnxhd, cineform, ffv1, magicyuv^)
echo.
echo container=^<format^>     : Container format (mp4, mkv, mov, webm, mxf, gxf...^)
echo.
echo height=^<height^>        : Output height (empty for source^)
echo fps=^<fps^>              : Output fps (empty for source^)
echo.
echo pixfmt=^<format^>        : Pixel format (8-bit: yuv420p, yuv422p, yuv444p, rgb24^)
echo                                      (10-bit: yuv420p10le, yuv422p10le, yuv444p10le^)
echo                                      (12-bit: yuv420p12le, yuv422p12le, yuv444p12le^)
echo                                      (Professional: rgb48le, gbrp, gbrap^)
echo.
echo scale_flags=^<flags^>    : Scaling algorithm (neighbor, bilinear, bicubic, lanczos, spline, area^)
echo options=^<...^>          : FFmpeg options (For advanced users^)
echo                          Quality Control:
echo                            -preset p7          : NVENC quality preset (p1-p7, higher is better quality^)
echo                            -rc:v constqp       : Constant QP mode
echo                            -init_qpI/P/B       : Initial QP values for I/P/B frames (lower is higher quality^)
echo                          Frame Control:
echo                            -rc-lookahead       : Number of frames for lookahead (higher gives better quality^)
echo                            -bf                 : Maximum number of B frames
echo                            -refs               : Number of reference frames
echo                            -b_ref_mode each    : B frame referencing mode
echo                          Bitrate Control:
echo                            -b:v                : Target bitrate (e.g. 6000k^)
echo                            -maxrate:v          : Maximum bitrate
echo                            -bufsize:v          : Buffer size (typically 2x maxrate^)
echo.
echo target_lufs=^<LUFS^>     : Target loudness (-18 LUFS^)
echo target_lra=^<LU^>        : Loudness range (7 LU^)
echo target_tp=^<dB^>         : True peak (-2 dB^)
echo ================================================================================================================================================
echo.
echo preset_start:
echo.
echo [Basic-H264]
echo 2pass=true
echo hwaccel=cuda
echo encoder=h264_nvenc
echo container=mp4
echo height=
echo fps=
echo pixfmt=yuv420p
echo scale_flags=lanczos
echo options=-preset p6 -b:v 5000k -maxrate:v 10000k -bufsize:v 20000k -bf 2 -refs 16 -b_ref_mode each
echo target_lufs=-18
echo target_lra=7
echo target_tp=-2
echo.
echo [Basic-H264-1080p]
echo 2pass=true
echo hwaccel=cuda
echo encoder=h264_nvenc
echo container=mp4
echo height=1080
echo fps=
echo pixfmt=yuv420p
echo scale_flags=lanczos
echo options=-preset p6 -b:v 5000k -maxrate:v 10000k -bufsize:v 20000k -bf 2 -refs 16 -b_ref_mode each
echo target_lufs=-18
echo target_lra=7
echo target_tp=-2
echo [Basic-H264-1440p]
echo 2pass=true
echo hwaccel=cuda
echo encoder=h264_nvenc
echo container=mp4
echo height=1440
echo fps=
echo pixfmt=yuv420p
echo scale_flags=lanczos
echo options=-preset p6 -b:v 5000k -maxrate:v 10000k -bufsize:v 20000k -bf 2 -refs 16 -b_ref_mode each
echo target_lufs=-18
echo target_lra=7
echo target_tp=-2
echo.
echo [HQArchive-HEVC-yuv444]
echo 2pass=true
echo hwaccel=cuda
echo encoder=hevc_nvenc
echo container=mp4
echo height=
echo fps=
echo pixfmt=yuv444p
echo scale_flags=bilinear
echo options=-preset p7 -rc:v constqp -init_qpI 19 -init_qpP 21 -init_qpB 23 -rc-lookahead 53 -bf 2 -refs 16 -b_ref_mode each
echo target_lufs=-18
echo target_lra=7
echo target_tp=-2
echo.
echo [HQArchive-HEVC-yuv420]
echo 2pass=true
echo hwaccel=cuda
echo encoder=hevc_nvenc
echo container=mp4
echo height=
echo fps=
echo pixfmt=yuv420p
echo scale_flags=bilinear
echo options=-preset p7 -rc:v constqp -init_qpI 19 -init_qpP 21 -init_qpB 23 -rc-lookahead 53 -bf 2 -refs 16 -b_ref_mode each
echo target_lufs=-18
echo target_lra=7
echo target_tp=-2
echo.
echo [Archive-HEVC-1440p]
echo 2pass=true
echo hwaccel=cuda
echo encoder=hevc_nvenc
echo container=mp4
echo height=1440
echo fps=
echo pixfmt=yuv420p
echo scale_flags=bilinear
echo options=-preset p7 -b:v 10000k -maxrate:v 20000k -bufsize:v 40000k --rc-lookahead 53 -bf 2 -refs 16 -b_ref_mode each
echo target_lufs=-18
echo target_lra=7
echo target_tp=-2
echo.
echo [HQArchive-H264-yuv444]
echo 2pass=true
echo hwaccel=cuda
echo encoder=h264_nvenc
echo container=mp4
echo height=
echo fps=
echo pixfmt=yuv444p
echo scale_flags=bilinear
echo options=-preset p7 -rc:v constqp -init_qpI 19 -init_qpP 21 -init_qpB 23 -rc-lookahead 53 -bf 2 -refs 16 -b_ref_mode each
echo target_lufs=-18
echo target_lra=7
echo target_tp=-2
echo.
echo [HQArchive-H264-yuv420]
echo 2pass=true
echo hwaccel=cuda
echo encoder=h264_nvenc
echo container=mp4
echo height=
echo fps=
echo pixfmt=yuv420p
echo scale_flags=bilinear
echo options=-preset p7 -rc:v constqp -init_qpI 19 -init_qpP 21 -init_qpB 23 -rc-lookahead 53 -bf 2 -refs 16 -b_ref_mode each
echo target_lufs=-18
echo target_lra=7
echo target_tp=-2
echo.
echo [Archive-H264-1440p]
echo 2pass=true
echo hwaccel=cuda
echo encoder=h264_nvenc
echo container=mp4
echo height=1440
echo fps=
echo pixfmt=yuv420p
echo scale_flags=bilinear
echo options=-preset p7 -b:v 10000k -maxrate:v 20000k -bufsize:v 40000k -rc-lookahead 53 -bf 2 -refs 16 -b_ref_mode each
echo target_lufs=-18
echo target_lra=7
echo target_tp=-2
echo.
echo [Iwara-2160p60fps]
echo 2pass=true
echo hwaccel=cuda
echo encoder=h264_nvenc
echo container=mp4
echo height=2160
echo fps=60
echo pixfmt=yuv420p
echo scale_flags=bilinear
echo options=-preset p7 -b:v 23600k -maxrate:v 23800k -bufsize:v 47600k -rc-lookahead 32 -bf 2 -refs 16 -b_ref_mode each
echo target_lufs=-18
echo target_lra=7
echo target_tp=-2
echo.
echo [Iwara-2160p30fps]
echo 2pass=true
echo hwaccel=cuda
echo encoder=h264_nvenc
echo container=mp4
echo height=2160
echo fps=30
echo pixfmt=yuv420p
echo scale_flags=bilinear
echo options=-preset p7 -b:v 16800k -maxrate:v 17000k -bufsize:v 34000k -rc-lookahead 32 -bf 2 -refs 16 -b_ref_mode each
echo target_lufs=-18
echo target_lra=7
echo target_tp=-2
echo.
echo [Iwara-1440p60fps]
echo 2pass=true
echo hwaccel=cuda
echo encoder=h264_nvenc
echo container=mp4
echo height=1440
echo fps=60
echo pixfmt=yuv420p
echo scale_flags=bilinear
echo options=-preset p7 -b:v 15900k -maxrate:v 16100k -bufsize:v 32200k -rc-lookahead 32 -bf 2 -refs 16 -b_ref_mode each
echo target_lufs=-18
echo target_lra=7
echo target_tp=-2
echo.
echo [Iwara-1440p30fps]
echo 2pass=true
echo hwaccel=cuda
echo encoder=h264_nvenc
echo container=mp4
echo height=1440
echo fps=30
echo pixfmt=yuv420p
echo scale_flags=bilinear
echo options=-preset p7 -b:v 11300k -maxrate:v 11500k -bufsize:v 23000k -rc-lookahead 32 -bf 2 -refs 16 -b_ref_mode each
echo target_lufs=-18
echo target_lra=7
echo target_tp=-2
echo.
echo [Iwara-1080p60fps]
echo 2pass=true
echo hwaccel=cuda
echo encoder=h264_nvenc
echo container=mp4
echo height=1080
echo fps=60
echo pixfmt=yuv420p
echo scale_flags=bilinear
echo options=-preset p7 -b:v 10300k -maxrate:v 10500k -bufsize:v 21000k -rc-lookahead 32 -bf 2 -refs 16 -b_ref_mode each
echo target_lufs=-18
echo target_lra=7
echo target_tp=-2
echo.
echo [Iwara-1080p30fps]
echo 2pass=true
echo hwaccel=cuda
echo encoder=h264_nvenc
echo container=mp4
echo height=1080
echo fps=30
echo pixfmt=yuv420p
echo scale_flags=bilinear
echo options=-preset p7 -b:v 7300k -maxrate:v 7500k -bufsize:v 15000k -rc-lookahead 32 -bf 2 -refs 16 -b_ref_mode each
echo target_lufs=-18
echo target_lra=7
echo target_tp=-2
echo.
echo [Iwara-720p60fps]
echo 2pass=true
echo hwaccel=cuda
echo encoder=h264_nvenc
echo container=mp4
echo height=720
echo fps=60
echo pixfmt=yuv420p
echo scale_flags=bilinear
echo options=-preset p7 -b:v 6100k -maxrate:v 6300k -bufsize:v 12600k -rc-lookahead 32 -bf 2 -refs 16 -b_ref_mode each
echo target_lufs=-18
echo target_lra=7
echo target_tp=-2
echo.
echo [Iwara-720p30fps]
echo 2pass=true
echo hwaccel=cuda
echo encoder=h264_nvenc
echo container=mp4
echo height=720
echo fps=30
echo pixfmt=yuv420p
echo scale_flags=bilinear
echo options=-preset p7 -b:v 4300k -maxrate:v 4500k -bufsize:v 9000k -rc-lookahead 32 -bf 2 -refs 16 -b_ref_mode each
echo target_lufs=-18
echo target_lra=7
echo target_tp=-2

echo [for-X]
echo 2pass=true
echo hwaccel=cuda
echo encoder=h264_nvenc
echo container=mp4
echo height=1080
echo fps=30
echo pixfmt=yuv420p
echo scale_flags=bilinear
echo options=-preset p7 -b:v 8000k -maxrate:v 8000k -bufsize:v 16000k -rc-lookahead 32 -bf 2 -refs 16 -b_ref_mode each
echo target_lufs=-23
echo target_lra=7
echo target_tp=-2

echo [vp9]
echo 2pass=false
echo hwaccel=
echo encoder=libvpx-vp9
echo container=mp4
echo height=
echo fps=
echo pixfmt=yuv420p
echo scale_flags=bilinear
echo options=-cpu-used 3 -b:v 10000k -maxrate:v 20000k -bufsize:v 20000k -row-mt 1 -tile-columns 2 -tile-rows 1 -frame-parallel 0 -auto-alt-ref 4 -lag-in-frames 0 -aq-mode 2 -deadline good -passlogfile vpx_stats 
echo target_lufs=-18
echo target_lra=7
echo target_tp=-2




) > "%~dp0..\presets.ini"

echo Presets file created successfully.