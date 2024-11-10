import json
import os
import subprocess
import colorama
import sys
from dataclasses import dataclass
from pathlib import Path
from typing import Dict, List, Optional, Tuple, Union
import configparser
import time
import shutil
import logging
from contextlib import contextmanager
import tempfile

# Config logging
log_file_path = Path(__file__).parent / '..' / 'o3enc.log'
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s',
    datefmt='%Y-%m-%d %H:%M:%S',
    handlers=[
        logging.StreamHandler(),
        logging.FileHandler(log_file_path, mode='w', encoding='utf-8')
    ]
)
logger = logging.getLogger(__name__)

class O3EncoderError(Exception):
    pass

class InitializationError(O3EncoderError):
    pass

class VideoAnalysisError(O3EncoderError):
    pass

class AudioAnalysisError(O3EncoderError):
    pass

class EncodingError(O3EncoderError):
    pass

class PresetError(O3EncoderError):
    pass

@contextmanager
def error_context(error_msg: str, error_class=O3EncoderError):
    try:
        yield
    except Exception as e:
        logger.error(f"{error_msg}: {str(e)}")
        raise error_class(f"{error_msg}: {str(e)}") from e

class O3Encoder:
    def __init__(self, input_file: str):
        if not input_file or not isinstance(input_file, str):
            raise InitializationError("Invalid input file specified")
            
        self.input_file = input_file
        self.root_dir = Path(__file__).parent.parent
        self.src_dir = Path(__file__).parent
        self.bin_dir = self.root_dir / "bin"
        self.ffmpeg = str(self.bin_dir / "ffmpeg.exe")
        self.ffprobe = str(self.bin_dir / "ffprobe.exe")
        
        try:
            self.temp_dir = Path(tempfile.gettempdir()) / f"o3enc_{os.getpid()}"
            self.temp_dir.mkdir(exist_ok=True, parents=True)
            logger.info(f"Created temporary directory: {self.temp_dir}")
        except Exception as e:
            raise InitializationError(f"Failed to create temporary directory: {str(e)}")

    def initialize_environment(self):
        logger.info("Initializing system environment...")
        
        with error_context("Failed to check required components", InitializationError):
            logger.info("Checking required components in bin directory...")
            self._check_required_components()

        with error_context("CUDA functionality test failed", InitializationError):
            logger.info("Testing CUDA functionality...")
            self._test_cuda_functionality()

        with error_context("Failed to load encoding presets", PresetError):
            logger.info("Loading encoding presets...")
            self._initialize_presets()
            
        logger.info("Initialization completed successfully")

    def _check_required_components(self):
        missing_tools = []
        for tool in ["ffmpeg", "ffprobe"]:
            exe_path = self.bin_dir / f"{tool}.exe"
            if not exe_path.exists():
                missing_tools.append(tool)
                logger.warning(f"{tool}.exe not found in bin directory")

        if missing_tools:
            print(f"\nRequired tools are missing: {', '.join(missing_tools)}")
            print("These tools need to be installed to continue.")
            
            init_script = self.src_dir / "initialize.bat"
            if not init_script.exists():
                raise InitializationError("initialize.bat not found in src directory")
                
            try:
                self.bin_dir.mkdir(exist_ok=True, parents=True)
                
                process = subprocess.run(
                    [str(init_script)],
                    check=True
                )
                
                missing_after_init = []
                for tool in missing_tools:
                    exe_path = self.bin_dir / f"{tool}.exe"
                    if not exe_path.exists():
                        missing_after_init.append(tool)

                if missing_after_init:
                    raise InitializationError(
                        f"Failed to install required tools: {', '.join(missing_after_init)}"
                    )
                    
                logger.info("Required tools installation completed successfully")
                
            except subprocess.CalledProcessError as e:
                raise InitializationError(
                    f"Initialization script failed with return code: {e.returncode}"
                )
            except OSError as e:
                raise InitializationError(
                    f"Failed to execute initialization script: {str(e)}"
                )

    def _test_cuda_functionality(self):
        result = subprocess.run([
            self.ffmpeg,
            "-hwaccel", "cuda",
            "-f", "lavfi",
            "-i", "color=black:s=1280x720",
            "-frames:v", "1",
            "-an",
            "-f", "null",
            "-"
        ], capture_output=True, text=True)
        
        if result.returncode != 0:
            raise InitializationError(
                "NVIDIA CUDA acceleration not available\n"
                f"Error: {result.stderr}"
            )
        logger.info("CUDA functionality test passed")

    def _initialize_presets(self):
        self.preset_manager = PresetManager()
        self.preset_manager.load_presets()
        preset_count = len(self.preset_manager.presets)
        logger.info(f"Loaded {preset_count} presets")

    def analyze_video(self) -> dict:
        logger.info("Starting video analysis...")
        print("Analyzing input video file...\n")
        
        with error_context("Failed to analyze video file", VideoAnalysisError):
            if not Path(self.input_file).exists():
                raise VideoAnalysisError("Input file does not exist")
                
            cmd = [
                self.ffprobe,
                "-v", "quiet",
                "-select_streams", "v:0",
                "-print_format", "json",
                "-show_entries", "stream=width,height,r_frame_rate,codec_name,duration,pix_fmt,"
                "color_space,color_transfer,color_primaries,color_range,field_order,bit_rate",
                self.input_file
            ]
            
            try:
                result = subprocess.run(cmd, capture_output=True, text=True, check=True)
            except subprocess.CalledProcessError as e:
                logger.error(f"FFprobe failed: {e.stderr}")
                raise VideoAnalysisError(f"FFprobe failed: {e.stderr}")
            
            try:
                data = json.loads(result.stdout)
                if not data.get("streams"):
                    raise VideoAnalysisError("No video stream found in input file")
                stream_data = data["streams"][0]
                
                # Validate required fields
                required_fields = ["width", "height", "r_frame_rate", "codec_name"]
                missing_fields = [field for field in required_fields if field not in stream_data]
                if missing_fields:
                    raise VideoAnalysisError(f"Missing required video information: {', '.join(missing_fields)}")
                
                # Calculate FPS
                try:
                    num, den = map(int, stream_data["r_frame_rate"].split("/"))
                    if den == 0:
                        raise ValueError("Invalid frame rate denominator (zero)")
                    fps = num / den
                    if fps <= 0:
                        raise ValueError(f"Invalid frame rate: {fps} FPS")
                except (ValueError, ZeroDivisionError) as e:
                    raise VideoAnalysisError(f"Invalid frame rate format: {str(e)}")
                
                # Calculate file size
                try:
                    size_mb = Path(self.input_file).stat().st_size / (1024 * 1024)
                except OSError as e:
                    raise VideoAnalysisError(f"Failed to get file size: {e}")
                
                # Get duration
                try:
                    duration = float(stream_data.get("duration", 0))
                    if duration <= 0:
                        logger.warning("Invalid or missing duration in video stream")
                        duration = 0
                except (ValueError, TypeError):
                    logger.warning("Could not parse duration value")
                    duration = 0
                
                info = {
                    "width": stream_data["width"],
                    "height": stream_data["height"],
                    "fps": fps,
                    "duration": duration,
                    "codec": stream_data["codec_name"],
                    "pixfmt": stream_data.get("pix_fmt", "unknown"),
                    "colorspace": stream_data.get("color_space", "unknown"),
                    "colortrc": stream_data.get("color_transfer", "unknown"),
                    "colorprim": stream_data.get("color_primaries", "unknown"),
                    "colorrange": stream_data.get("color_range", "unknown"),
                    "field_order": stream_data.get("field_order", "unknown"),
                    "size_mb": size_mb
                }
                
                if info["width"] <= 0 or info["height"] <= 0:
                    raise VideoAnalysisError(f"Invalid video dimensions: {info['width']}x{info['height']}")
                
                self._print_video_info(info)
                logger.info("Video analysis completed successfully")
                return info
                
            except json.JSONDecodeError as e:
                raise VideoAnalysisError(f"Failed to parse FFprobe output: {str(e)}")
            except KeyError as e:
                raise VideoAnalysisError(f"Missing required field in video data: {str(e)}")

    def get_color_settings(self, video_info: dict) -> tuple:
        logger.info("Getting color settings...")
        try:
            if not isinstance(video_info, dict):
                raise EncodingError("Invalid video_info format")
                
            if video_info.get("colorspace") != "unknown":
                colorspace = video_info["colorspace"]
                colorrange = video_info["colorrange"]
                print(f"Detected input color space: {colorspace}")
                print(f"Detected input color range: {colorrange}")
                print("Using detected settings (no conversion needed)")
                print()
                logger.info(f"Using detected color settings: space={colorspace}, range={colorrange}")
                return colorspace, colorrange

            logger.info(f"No input color information detected.")
            print("\nSelect input color space interpretation:")
            print("  -----------------------------------------------")
            print("  [0] Auto (No color space conversion)")
            print("      - Let FFmpeg automatically detect the colorspace")
            print("      - Not recommended as detection may be unreliable")
            print()
            print("  [1] Standard Definition (BT.601-6-625)")
            print("      - For SD content")
            print("      - For raw video output from MMD, select this option")
            print()
            print("  [2] High Definition (BT.709)")
            print("      - For HD content")
            print("      - Recommended for most modern HD/4K")
            print("  -----------------------------------------------")
            print()

            colorspace = self._get_user_color_space()
            colorrange = self._get_user_color_range(video_info, colorspace)

            self._print_color_settings(video_info, colorspace, colorrange)
            logger.info(f"User selected color settings: space={colorspace}, range={colorrange}")
            return colorspace, colorrange
                
        except Exception as e:
            raise EncodingError(f"Failed to get color settings: {str(e)}")

    def _get_user_color_space(self) -> str:
        while True:
            try:
                choice = input("Enter your selection (0-2): ").strip()
                if choice == "0":
                    return "auto"
                elif choice == "1":
                    return "bt601-6-625"
                elif choice == "2":
                    return "bt709"
                else:
                    logger.warning(f"Invalid selection. Please enter 0, 1 or 2.")
            except EOFError:
                raise EncodingError("Unexpected end of input")
            except KeyboardInterrupt:
                logger.info(f"Operation cancelled by user")
                raise

    def _get_user_color_range(self, video_info: dict, colorspace: str) -> str:
        if colorspace == "auto" or video_info.get("colorrange") != "unknown":
            return "auto"

        print("\nSelect input color range interpretation:")
        print("  -----------------------------------------------")
        print("  [0] Auto (No range conversion)")
        print("      - Let FFmpeg automatically detect the range")
        print("      - Not recommended as detection may be unreliable")
        print()
        print("  [1] TV/Limited Range (16-235)")
        print("      - For broadcast content")
        print("      - For raw video output from MMD, select this option")
        print()
        print("  [2] PC/Full Range (0-255)")
        print("      - For full dynamic range")
        print("      - Recommended for most modern HD/4K")
        print("  -----------------------------------------------")
        print()

        while True:
            try:
                choice = input("Enter your selection (0-2): ").strip()
                if choice == "0":
                    return "auto"
                elif choice == "1":
                    return "tv"
                elif choice == "2":
                    return "pc"
                else:
                    logger.warning(f"Invalid selection. Please enter 0, 1 or 2.")
            except EOFError:
                raise EncodingError("Unexpected end of input")
            except KeyboardInterrupt:
                logger.info(f"Operation cancelled by user")
                raise

    def _print_video_info(self, info: dict):
        print("Video Properties:")
        print(" ---------------------------------------")
        print(f"  Resolution     : {info['width']} x {info['height']}")
        print(f"  Frame Rate     : {info['fps']:.2f} fps")
        print(f"  Duration       : {info['duration']:.2f} seconds")
        print(f"  Codec          : {info['codec']}")
        print(f"  Pixel Format   : {info['pixfmt']}")
        print(f"  Color Range    : {info['colorrange']}")
        print(f"  Color Space    : {info['colorspace']}")
        print(f"  Color Transfer : {info['colortrc']}")
        print(f"  Color Primaries: {info['colorprim']}")
        print(f"  Field Order    : {info['field_order']}")
        print(f"  File Size      : {info['size_mb']:.1f} MB")
        print(" ---------------------------------------")
        print()

    def _print_color_settings(self, video_info: dict, colorspace: str, colorrange: str):
        print("\nInput Color Settings:")
        print("----------------------------------------")
        if video_info["colorspace"] != "unknown":
            print("Using source file color settings (no conversion needed)")
        elif colorspace == "auto":
            print("Input Color Space: Auto detection")
            print("Input Color Range: Auto detection")
            print("Note: This may lead to incorrect color reproduction")
        else:
            filter_str = f"colorspace=all=bt709:iall={colorspace}"
            if colorrange != "auto":
                filter_str += f":range={colorrange}:irange={colorrange}"
            print(f"Input Color Space: {colorspace}")
            print(f"Input Color Range: {colorrange}")
            print(f"Applied Filter: {filter_str}")
        print("----------------------------------------")
        print()

    def analyze_audio(self, preset: dict) -> Optional[dict]:
        logger.info("Starting audio analysis...")
        print("\nAnalyzing audio levels...")
        
        with error_context("Failed to analyze audio", AudioAnalysisError):
            if not isinstance(preset, dict):
                raise AudioAnalysisError("Invalid preset format")
                
            # Check if file has audio
            cmd = [
                self.ffprobe,
                "-v", "error",
                "-select_streams", "a",
                "-show_entries", "stream=codec_name",
                "-of", "csv=p=0",
                self.input_file
            ]
            
            try:
                result = subprocess.run(cmd, capture_output=True, text=True, encoding='utf-8', check=True)
            except subprocess.CalledProcessError as e:
                raise AudioAnalysisError(f"Failed to probe audio stream: {e.stderr}")
                
            if not result.stdout.strip():
                logger.info("No audio track detected")
                print("No audio track detected in the input file.")
                print("Skipping audio normalization process.")
                return None
                
            # Get target values from preset
            try:
                target_lufs = float(preset.get("target_lufs", -18))
                target_lra = float(preset.get("target_lra", 7))
                target_tp = float(preset.get("target_tp", -2))
            except (ValueError, TypeError) as e:
                raise AudioAnalysisError(f"Invalid audio target values in preset: {str(e)}")
                
            # Analyze audio levels
            cmd = [
                self.ffmpeg,
                "-v", "info",
                "-stats",
                "-i", self.input_file,
                "-af", f"loudnorm=I={target_lufs}:LRA={target_lra}:print_format=json",
                "-f", "null", "-"
            ]
            
            try:
                process = subprocess.Popen(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE, universal_newlines=True, encoding='utf-8')
                
                stderr_lines = []
                while True:
                    line = process.stderr.readline()
                    if not line and process.poll() is not None:
                        break
                    if line.startswith("frame="):
                        print(f"\r{line.strip()}", end='', flush=True)
                    else:
                        stderr_lines.append(line)
                
                print()
                process.wait()
                if process.returncode != 0:
                    raise AudioAnalysisError(f"Audio analysis failed")
                
                stderr = ''.join(stderr_lines)
                json_start = stderr.find("{")
                json_end = stderr.rfind("}") + 1
                if json_start == -1 or json_end == 0:
                    raise AudioAnalysisError("Audio analysis data not found in output")
                
                json_str = stderr[json_start:json_end]
                data = json.loads(json_str)
                
                required_fields = ["input_i", "input_lra", "input_tp", "input_thresh", "target_offset"]
                missing_fields = [field for field in required_fields if field not in data]
                if missing_fields:
                    raise AudioAnalysisError(f"Missing audio analysis data: {', '.join(missing_fields)}")
                
                try:
                    audio_info = {
                        "input_i": float(data["input_i"]),
                        "input_lra": float(data["input_lra"]),
                        "input_tp": float(data["input_tp"]),
                        "input_thresh": float(data["input_thresh"]),
                        "target_offset": float(data["target_offset"])
                    }
                except (ValueError, TypeError) as e:
                    raise AudioAnalysisError(f"Invalid audio measurement values: {str(e)}")
                
                self._print_audio_info(audio_info, target_lufs, target_lra, target_tp)
                logger.info("Audio analysis completed successfully")
                return audio_info
                
            except json.JSONDecodeError as e:
                raise AudioAnalysisError(f"Failed to parse audio analysis data: {str(e)}")
            except subprocess.CalledProcessError as e:
                raise AudioAnalysisError(f"Audio analysis process failed: {e.stderr}")

    def _print_audio_info(self, audio_info: dict, target_lufs: float, target_lra: float, target_tp: float):
        print("\nAudio Analysis Results:")
        print("  -------------------------------------")
        print(f"  Target LUFS     : {target_lufs} LUFS")
        print(f"  Target LRA      : {target_lra} LU")
        print(f"  Target TP       : {target_tp} dB")
        print("  -------------------------------------")
        print(f"  Input Loudness  : {audio_info['input_i']:.1f} LUFS")
        print(f"  Loudness Range  : {audio_info['input_lra']:.1f} LU")
        print(f"  True Peak Level : {audio_info['input_tp']:.1f} dB")
        print("  -------------------------------------")

    def encode(self, preset: dict, output_file: Path, color_filters: str, 
               audio_info: Optional[dict], video_info: dict) -> bool:
        logger.info(f"Starting encoding process for preset: {preset.get('name', 'unknown')}")
        with error_context("Encoding failed", EncodingError):
            self._validate_encoding_inputs(preset, output_file, video_info)
            
            try:
                # Build filter chain safely
                filters = self._build_filter_chain(preset, video_info, color_filters)
                filter_chain = ",".join(filters)
                
                # Build audio filter if needed
                audio_filter = self._build_audio_filter(preset, audio_info) if audio_info else None
                
                # Get hardware acceleration options
                hwaccel_opts = self._get_hwaccel_options(preset)
                
                print(f"\nProcessing Preset: [{preset['name']}]")
                print("----------------------------------------")
                
                # Run encoding passes
                success = self._run_first_pass(preset, hwaccel_opts, filter_chain)
                if not success:
                    raise EncodingError("First pass encoding failed")
                
                success = self._run_second_pass(preset, hwaccel_opts, filter_chain, 
                                              audio_filter, output_file)
                if not success:
                    raise EncodingError("Second pass encoding failed")
                
                # Verify output file
                if not output_file.exists():
                    raise EncodingError("Output file was not created")
                    
                output_size = output_file.stat().st_size
                if output_size == 0:
                    raise EncodingError("Output file is empty")
                
                # Force cleanup of FFmpeg logs after encoding
                self.cleanup()
                
                logger.info(f"Encoding completed successfully: {output_file}")
                return True
                
            except Exception as e:
                if output_file.exists():
                    try:
                        output_file.unlink()
                        logger.info(f"Removed failed output file: {output_file}")
                    except OSError as del_err:
                        logger.error(f"Failed to remove failed output file: {del_err}")
                        
                # Try to clean up logs even if encoding failed
                try:
                    self.cleanup()
                except Exception as cleanup_err:
                    logger.error(f"Failed to clean up FFmpeg logs after error: {cleanup_err}")
                raise

    def _validate_encoding_inputs(self, preset: dict, output_file: Path, video_info: dict):
        if not isinstance(preset, dict):
            raise EncodingError("Invalid preset format")
        if not isinstance(output_file, Path):
            raise EncodingError("Invalid output file path")
        if not isinstance(video_info, dict):
            raise EncodingError("Invalid video info format")
        
        required_preset_fields = ['name', 'encoder', 'pixfmt', 'options']
        missing_fields = [field for field in required_preset_fields if field not in preset]
        if missing_fields:
            raise EncodingError(f"Missing required preset fields: {', '.join(missing_fields)}")
            
        output_dir = output_file.parent
        if not output_dir.exists():
            try:
                output_dir.mkdir(parents=True)
            except OSError as e:
                raise EncodingError(f"Failed to create output directory: {str(e)}")
        if not os.access(output_dir, os.W_OK):
            raise EncodingError(f"Output directory is not writable: {output_dir}")

    def _build_filter_chain(self, preset: dict, video_info: dict, color_filters: str) -> List[str]:
        try:
            filters = [f"format={preset['pixfmt']}"]
            
            # Add scaling if needed
            if preset.get('height'):
                try:
                    target_height = int(preset['height'])
                    if target_height != video_info['height']:
                        scale_flags = preset.get('scale_flags', 'lanczos')
                        filters.append(f"scale=-1:{target_height}:flags={scale_flags}")
                except ValueError as e:
                    raise EncodingError(f"Invalid height value in preset: {str(e)}")
            
            # Add fps filter if needed
            if preset.get('fps'):
                try:
                    target_fps = float(preset['fps'])
                    current_fps = float(video_info['fps'])
                    if abs(target_fps - current_fps) > 0.01:
                        filters.append(f"fps={preset['fps']}")
                except (ValueError, TypeError) as e:
                    raise EncodingError(f"Invalid FPS value in preset: {str(e)}")
                
            # Add color filters if specified
            if color_filters:
                filters.append(color_filters)
                
            return filters
            
        except KeyError as e:
            raise EncodingError(f"Missing required field in preset: {str(e)}")
        except Exception as e:
            raise EncodingError(f"Failed to build filter chain: {str(e)}")

    def _build_audio_filter(self, preset: dict, audio_info: dict) -> str:
        try:
            required_fields = ['target_lufs', 'target_lra', 'target_tp']
            missing_fields = [f for f in required_fields if f not in preset]
            if missing_fields:
                raise EncodingError(f"Missing audio preset fields: {', '.join(missing_fields)}")
                
            required_audio_fields = ['input_i', 'input_lra', 'input_tp', 
                                   'input_thresh', 'target_offset']
            missing_audio = [f for f in required_audio_fields if f not in audio_info]
            if missing_audio:
                raise EncodingError(f"Missing audio analysis fields: {', '.join(missing_audio)}")
            
            return (
                f"loudnorm=I={preset['target_lufs']}:LRA={preset['target_lra']}"
                f":TP={preset['target_tp']}"
                f":measured_I={audio_info['input_i']}"
                f":measured_LRA={audio_info['input_lra']}"
                f":measured_TP={audio_info['input_tp']}"
                f":measured_thresh={audio_info['input_thresh']}"
                f":offset={audio_info['target_offset']}"
                f":linear=true:print_format=summary"
            )
        except (KeyError, ValueError) as e:
            raise EncodingError(f"Failed to build audio filter: {str(e)}")

    def _get_hwaccel_options(self, preset: dict) -> List[str]:
        try:
            hwaccel = preset.get('hwaccel', 'none')
            if hwaccel == "none":
                return []
                
            hwaccel_opts = ["-hwaccel", hwaccel]
            if hwaccel in ["cuda", "d3d11va", "qsv", "vaapi"]:
                hwaccel_opts.extend(["-hwaccel_output_format", hwaccel])
            return hwaccel_opts
            
        except KeyError:
            raise EncodingError("Invalid hardware acceleration settings in preset")

    def _run_first_pass(self, preset: dict, hwaccel_opts: List[str], filter_chain: str) -> bool:
        try:
            print("\nFirst Pass Encoding...")
            
            first_pass = [
                self.ffmpeg,
                "-y",
                "-loglevel", "warning",
                "-stats",
                *hwaccel_opts,
                "-i", self.input_file,
                "-c:v", preset['encoder'],
                *preset['options'].split(),
                "-vf", filter_chain,
                "-pass", "1",
                "-an",
                "-f", "null",
                "NUL"
            ]
            
            print(f"ffmpeg {' '.join(first_pass[1:])}\n")
            result = subprocess.run(first_pass)
            if result.returncode != 0:
                raise EncodingError("First pass encoding failed")
                
            return True
            
        except subprocess.SubprocessError as e:
            raise EncodingError("First pass process error")

    def _run_second_pass(self, preset: dict, hwaccel_opts: List[str], filter_chain: str, 
                        audio_filter: Optional[str], output_file: Path) -> bool:
        try:
            print("\nSecond Pass Encoding...")
            
            second_pass = [
                self.ffmpeg,
                "-y",
                "-loglevel", "warning",
                "-stats",
                *hwaccel_opts,
                "-i", self.input_file,
                "-c:v", preset['encoder'],
                *preset['options'].split(),
                "-vf", filter_chain,
                "-pass", "2"
            ]
            
            if audio_filter:
                second_pass.extend([
                    "-c:a", "aac",
                    "-b:a", "128k",
                    "-ac", "2",
                    "-af", audio_filter
                ])
            
            second_pass.append(str(output_file))
            print(f"ffmpeg {' '.join(second_pass[1:])}\n")
            result = subprocess.run(second_pass)
            if result.returncode != 0:
                raise EncodingError("Second pass encoding failed")
                
            if not output_file.exists():
                raise EncodingError("Output file was not created")
                
            return True
            
        except subprocess.SubprocessError as e:
            raise EncodingError("Second pass process error")
        except OSError as e:
            raise EncodingError("Output file system error")

    def cleanup(self):
        logger.info("Starting cleanup process")
        cleanup_errors = []
        
        if hasattr(self, 'temp_dir') and self.temp_dir.exists():
            try:
                shutil.rmtree(self.temp_dir, ignore_errors=False)
                logger.info(f"Removed temporary directory: {self.temp_dir}")
            except Exception as e:
                error_msg = f"Failed to remove temp directory: {str(e)}"
                cleanup_errors.append(error_msg)
                logger.error(error_msg)
        
        max_retries = 3
        retry_delay = 1
        
        ffmpeg_patterns = [
            "ffmpeg2pass-*.log",
            "ffmpeg2pass-*.log.*",
            "*.mbtree",
            "*.temp",
            "*.stats"
        ]
        
        for retry in range(max_retries):
            remaining_files = []
            
            for pattern in ffmpeg_patterns:
                try:
                    for log_file in Path().glob(pattern):
                        try:
                            # Try to open the file to check if it's still in use
                            with open(log_file, 'a') as f:
                                f.close()
                            log_file.unlink()
                            logger.debug(f"Removed FFmpeg temporary file: {log_file}")
                        except (PermissionError, OSError):
                            remaining_files.append(log_file)
                            continue
                except Exception as e:
                    error_msg = f"Error processing pattern {pattern}: {str(e)}"
                    cleanup_errors.append(error_msg)
                    logger.error(error_msg)
            
            if not remaining_files:
                break
                
            if retry < max_retries - 1:
                logger.debug(f"Some files still in use, retrying in {retry_delay} seconds...")
                time.sleep(retry_delay)
        
        if remaining_files:
            file_list = ', '.join(str(f) for f in remaining_files)
            error_msg = f"Could not remove some FFmpeg temporary files: {file_list}"
            cleanup_errors.append(error_msg)
            logger.warning(error_msg)
                
        if cleanup_errors:
            print("\nWarning: Some cleanup operations failed:")
            for error in cleanup_errors:
                print(f"- {error}")

class PresetManager:
    def __init__(self):
        self.root_dir = Path(__file__).parent.parent
        self.preset_file = self.root_dir / "presets.ini"
        self.presets: Dict[str, dict] = {}

    def _parse_preset_section(self, config: configparser.ConfigParser, section: str) -> dict:
        try:
            preset = {
                'name': section,
                'hwaccel': config.get(section, 'hwaccel', fallback='none'),
                'encoder': config.get(section, 'encoder'),
                'container': config.get(section, 'container', fallback='mp4'),
                'height': config.get(section, 'height', fallback=''),
                'fps': config.get(section, 'fps', fallback=''),
                'pixfmt': config.get(section, 'pixfmt'),
                'scale_flags': config.get(section, 'scale_flags', fallback='lanczos'),
                'options': config.get(section, 'options'),
                'target_lufs': config.getfloat(section, 'target_lufs', fallback=-18),
                'target_lra': config.getfloat(section, 'target_lra', fallback=7),
                'target_tp': config.getfloat(section, 'target_tp', fallback=-2)
            }
            
            required_fields = ['encoder', 'pixfmt', 'options']
            missing = [f for f in required_fields if not preset.get(f)]
            if missing:
                raise PresetError(
                    f"Missing required fields in preset {section}: {', '.join(missing)}"
                )
            
            return preset
            
        except configparser.Error as e:
            raise PresetError(f"Error parsing preset {section}: {str(e)}")

    def create_presets(self):
        with error_context("Failed to create presets", PresetError):
            create_presets_bat = self.root_dir / "src" / "create_presets.bat"
            if not create_presets_bat.exists():
                raise PresetError("create_presets.bat not found")
                
            try:
                result = subprocess.run(
                    [str(create_presets_bat)], 
                    capture_output=True, 
                    text=True, 
                    check=True
                )
                if not self.preset_file.exists():
                    raise PresetError(
                        f"Failed to create presets.ini:\n{result.stderr}"
                    )
                logger.info("Created default presets")
            except subprocess.CalledProcessError as e:
                raise PresetError(f"create_presets.bat failed:\n{e.stderr}")

    def load_presets(self) -> None:
        with error_context("Failed to load presets", PresetError):
            if not self.preset_file.exists():
                logger.warning("Presets file not found")
                logger.info("Creating default presets...")
                self.create_presets()
                
            try:
                # Read the entire file
                with open(self.preset_file, 'r', encoding='utf-8') as f:
                    lines = f.readlines()
            except (OSError, UnicodeDecodeError) as e:
                raise PresetError(f"Failed to read presets file: {str(e)}")

            # Find preset sections
            try:
                preset_start = -1
                for i, line in enumerate(lines):
                    if line.strip() == 'preset_start:':
                        preset_start = i
                        break
                        
                if preset_start == -1:
                    raise PresetError("No preset_start: marker found in presets.ini")

                # Create temporary ini file
                temp_ini = self.preset_file.with_suffix('.temp.ini')
                try:
                    with open(temp_ini, 'w', encoding='utf-8') as f:
                        f.writelines(lines[preset_start+1:])
                    
                    # Load presets
                    config = configparser.ConfigParser()
                    config.read(temp_ini, encoding='utf-8')
                    
                    for section in config.sections():
                        self.presets[section] = self._parse_preset_section(config, section)
                        
                    if not self.presets:
                        raise PresetError("No valid presets found")
                        
                finally:
                    # Cleanup temporary file
                    if temp_ini.exists():
                        try:
                            temp_ini.unlink()
                        except OSError as e:
                            logger.warning(f"Failed to remove temporary preset file: {str(e)}")
                            
            except Exception as e:
                raise PresetError(f"Failed to process presets: {str(e)}")

    def show_preset_menu(self) -> List[dict]:
        logger.info("Showing preset selection menu")
        print()
        if not self.presets:
            raise PresetError("No presets available")
            
        print("Available Encoding Presets:")
        preset_list = list(self.presets.keys())
        for i, preset in enumerate(preset_list, 1):
            print(f"[{i}] {preset}")
        print()
        print("Commands:")
        print(f" * Enter numbers (1-{len(preset_list)}) - Add presets to queue")
        print(" * Q - Finish selection and proceed")
        print(" * R - Reset queue and start over")
        print()
        
        selected_presets = []
        while True:
            try:
                # Show current selection status
                if not selected_presets:
                    print("[Empty] No presets selected")
                else:
                    print("Selected presets:")
                    for preset in selected_presets:
                        print(f"  * {preset['name']}")
                print()
                
                choice = input(f"Select presets (1-{len(preset_list)}, "
                             "comma-separated, Q/R): ").strip().upper()
                
                if choice == 'Q':
                    if not selected_presets:
                        print("Error: Queue is empty. Please select at least one preset.")
                        print()
                        continue
                    print("\nSelected presets for encoding:")
                    for i, preset in enumerate(selected_presets, 1):
                        print(f"  {i}. [{preset['name']}]")
                    break
                
                if choice == 'R':
                    selected_presets = []
                    print("Queue has been reset.")
                    print()
                    continue
                
                # Process number selections
                try:
                    for num in choice.split(','):
                        num = int(num.strip())
                        if 1 <= num <= len(preset_list):
                            preset_name = preset_list[num-1]
                            preset = self.presets[preset_name]
                            if preset not in selected_presets:
                                selected_presets.append(preset)
                                print(f"Added preset to queue: {preset_name}")
                            else:
                                logger.warning(f"Skipping [{preset_name}] - Already in queue")
                        else:
                            logger.warning(f"Invalid preset number selected: {num}")
                except ValueError:
                    logger.warning(f"Invalid preset selection input: {choice}")
                    
            except EOFError:
                raise PresetError("Unexpected end of input")
            except KeyboardInterrupt:
                logger.info(f"Operation cancelled by user")
                raise
            except Exception as e:
                logger.error(f"Error during preset selection: {str(e)}")
                raise PresetError(f"Failed to process preset selection: {str(e)}")
                
            print()
        
        return selected_presets

    def get_base_filename(self, input_file: str) -> str:
        try:
            if not input_file or not isinstance(input_file, str):
                raise PresetError("Invalid input file")
                
            input_name = Path(input_file).stem
            
            while True:
                try:
                    answer = input(f"\nCurrent input filename: {input_name}\n"
                                 "Use input filename as base? (Y/N): ").strip().upper()
                    
                    if answer == 'Y':
                        return input_name
                    elif answer == 'N':
                        while True:
                            base_name = input("\nEnter custom output filename "
                                            "(without extension): ").strip()
                            if not base_name:
                                logger.warning(f"Filename cannot be empty")
                                continue
                                
                            # Check for invalid characters in filename
                            invalid_chars = '<>:"/\\|?*'
                            if any(char in base_name for char in invalid_chars):
                                logger.warning(f"Filename contains invalid characters")
                                logger.warning(f"({invalid_chars})")
                                continue
                                
                            return base_name
                    else:
                        logger.warning(f"Invalid input '{answer}'. Please enter Y or N.")
                except EOFError:
                    raise PresetError("Unexpected end of input")
                except KeyboardInterrupt:
                    logger.info(f"Operation cancelled by user")
                    raise
                    
        except Exception as e:
            raise PresetError(f"Failed to get base filename: {str(e)}")

    def get_output_filename(self, base_name: str, preset: dict) -> Path:
        try:
            if not base_name or not isinstance(base_name, str):
                raise PresetError("Invalid base filename")
            if not isinstance(preset, dict):
                raise PresetError("Invalid preset format")
            if 'name' not in preset:
                raise PresetError("Preset missing required 'name' field")
            if 'container' not in preset:
                raise PresetError("Preset missing required 'container' field")
                
            output_name = f"{base_name}_{preset['name']}"
            
            # Validate output name length
            if len(output_name) > 200:  # Leave room for version and extension
                raise PresetError("Output filename too long")
            
            version = 0
            while True:
                version_str = f"_v{version:02d}"
                output_path = Path(f"{output_name}{version_str}.{preset['container']}")
                
                try:
                    # Check if path is too long for the system
                    output_path.resolve()
                except (OSError, RuntimeError) as e:
                    raise PresetError(f"Invalid output path: {str(e)}")
                    
                if not output_path.exists():
                    # Verify the parent directory exists and is writable
                    parent_dir = output_path.parent
                    if not parent_dir.exists():
                        try:
                            parent_dir.mkdir(parents=True)
                        except OSError as e:
                            raise PresetError(f"Failed to create output directory: {str(e)}")
                            
                    if not os.access(parent_dir, os.W_OK):
                        raise PresetError(f"Output directory is not writable: {parent_dir}")
                        
                    break
                    
                version += 1
                if version > 99:
                    raise PresetError("Too many versions of this output file exist")
                
            return output_path
            
        except Exception as e:
            raise PresetError(f"Failed to generate output filename: {str(e)}")

def show_encoding_preview(selected_presets: List[dict], output_files: Dict[str, Path], video_info: dict):
    try:
        logger.info("Generating encoding preview")
        print("\nEncoding Preview:")
        print("----------------------------------------")
        
        for preset in selected_presets:
            try:
                output_file = output_files[preset['name']]
                
                target_height = video_info['height']
                target_width = video_info['width']

                if preset.get('height'):
                    try:
                        target_height = int(preset['height'])
                        scale_factor = target_height / video_info['height']
                        target_width = int(video_info['width'] * scale_factor)
                        if target_width <= 0 or target_height <= 0:
                            raise ValueError("Invalid scaled dimensions")
                    except (ValueError, TypeError, ZeroDivisionError) as e:
                        logger.warning(f"Could not calculate scaled dimensions for preset {preset['name']}: {e}")
                        target_height = video_info['height']
                        target_width = video_info['width']
                
                try:
                    preset_fps = preset.get('fps')
                    fps = int(float(preset_fps)) if preset_fps else int(video_info['fps'])
                except (ValueError, TypeError) as e:
                    logger.warning(f"Could not parse FPS value for preset {preset['name']}: {e}")
                    fps = int(video_info['fps'])
                
                preview_info = [
                    f"\nPreset: [{preset['name']}]",
                    "----------------------------------------",
                    f"Output Path : {output_file.absolute()}",
                    f"Resolution  : {target_width} x {target_height}",
                    f"Frame Rate  : {fps} fps",
                    f"Encoder     : {preset['encoder']}",
                    f"Pixel Format: {preset['pixfmt']}"
                ]
                
                for line in preview_info:
                    print(line)
                
            except KeyError as e:
                error_msg = f"Missing field in preset {preset['name']}: {e}"
                logger.error(error_msg)
                
            except Exception as e:
                error_msg = f"Error showing preview for preset {preset['name']}: {e}"
                logger.error(error_msg)
        
        print("----------------------------------------")
        
    except Exception as e:
        error_msg = f"Failed to generate encoding preview: {e}"
        logger.error(error_msg)
        raise EncodingError(error_msg)

def show_encoding_results(results: Dict[str, dict], ffprobe_path: str):
   print("\nEncoding Results:")
   print("----------------------------------------")
   
   for preset_name, result in results.items():
       status = "Success" if result['success'] else "Failed"
       print(f"[{preset_name}] : {status}")

   print("\nDetailed Information:")
   print("----------------------------------------")
   
   for preset_name, result in results.items():
       if result['success'] and result['output_file'].exists():
           try:
               cmd = [
                   ffprobe_path,
                   "-v", "quiet",
                   "-select_streams", "v:0",
                   "-print_format", "json",
                   "-show_entries", "stream=width,height,r_frame_rate,codec_name,"
                   "pix_fmt,color_space,color_range,color_transfer,color_primaries",
                   str(result['output_file'])
               ]
               
               probe_result = subprocess.run(cmd, capture_output=True, text=True)
               if probe_result.returncode != 0:
                   print(f"Warning: Could not analyze file for [{preset_name}]")
                   continue
                   
               data = json.loads(probe_result.stdout)["streams"][0]
               file_size = result['output_file'].stat().st_size / (1024*1024)
               
               print(f"\nDetails for [{preset_name}]:")
               print(f"  Output Path    : {result['output_file'].absolute()}")
               print(f"  Resolution     : {data['width']} x {data['height']}")
               print(f"  Frame Rate     : {int(eval(data['r_frame_rate']))} fps")
               print(f"  Codec          : {data['codec_name']}")
               print(f"  Pixel Format   : {data['pix_fmt']}")
               print(f"  Color Space    : {data.get('color_space', 'unknown')}")
               print(f"  Color Transfer : {data.get('color_transfer', 'unknown')}")
               print(f"  Color Primaries: {data.get('color_primaries', 'unknown')}")
               print(f"  Color Range    : {data.get('color_range', 'unknown')}")
               print(f"  File Size      : {file_size:.1f} MB")
               
           except Exception as e:
               print(f"Warning: Could not analyze file for [{preset_name}]")

   print("----------------------------------------")

def main():
    try:
        if len(sys.argv) == 2 and sys.argv[1] == "--init":
            try:
                encoder = O3Encoder("dummy")
                encoder.initialize_environment()
                print("\nPress Enter to exit...")
                input()
                return 0
            except Exception as e:
                logger.error(f"Initialization Error: {str(e)}")
                print("\nPress Enter to exit...")
                input()
                return 1

        if len(sys.argv) != 2:
            print("Usage: python o3enc.py <input_file>")
            print("\nPress Enter to exit...")
            input()
            return 1

        input_file = sys.argv[1]
        if not os.path.exists(input_file):
            print(f"Error: Input file not found: {input_file}")
            print("\nPress Enter to exit...")
            input()
            return 1

        encoder = None
        try:
            # Initialize and analyze video
            encoder = O3Encoder(input_file)
            encoder.initialize_environment()
            video_info = encoder.analyze_video()
            colorspace, colorrange = encoder.get_color_settings(video_info)
            
            # Set up color filters
            color_filters = ""
            if colorspace != "auto":
                if colorspace == "bt601-6-625":
                    color_filters = "colorspace=all=bt709:iall=bt601-6-625"
                elif colorspace == "bt709":
                    color_filters = "colorspace=all=bt709:iall=bt709"
                if colorrange != "auto":
                    color_filters += f":range={colorrange}:irange={colorrange}"

            while True:  # Main selection loop
                try:
                    selected_presets = encoder.preset_manager.show_preset_menu()
                    base_name = encoder.preset_manager.get_base_filename(input_file)

                    # Generate output filenames
                    output_files = {}
                    try:
                        for preset in selected_presets:
                            output_file = encoder.preset_manager.get_output_filename(base_name, preset)
                            output_files[preset['name']] = output_file
                    except OSError as e:
                        raise EncodingError(f"Failed to generate output filenames: {str(e)}")

                    # Show encoding preview
                    print("\nEncoding Preview:")
                    print("----------------------------------------")
                    show_encoding_preview(selected_presets, output_files, video_info)

                    while True:
                        try:
                            answer = input("\nProceed with encoding? (Y/N): ").strip().upper()
                            if answer == 'Y':
                                # Start encoding process
                                audio_info = None
                                try:
                                    audio_info = encoder.analyze_audio(selected_presets[0])
                                except Exception as e:
                                    logger.warning(f"Audio analysis failed: {str(e)}")
                                    logger.info(f"Continuing without audio normalization...")
                                
                                # Process each preset
                                results = {}
                                for preset in selected_presets:
                                    try:
                                        output_file = output_files[preset['name']]
                                        success = encoder.encode(preset, output_file, 
                                                              color_filters, audio_info, 
                                                              video_info)
                                        results[preset['name']] = {
                                            'success': success,
                                            'output_file': output_file
                                        }
                                    except Exception as e:
                                        logger.error(f"Encoding failed for preset "
                                                   f"{preset['name']}: {str(e)}")
                                        results[preset['name']] = {
                                            'success': False,
                                            'error': str(e),
                                            'output_file': output_file
                                        }

                                # Show results
                                show_encoding_results(results, encoder.ffprobe)
                                print("\nPress Enter to exit...")
                                input()
                                return 0
                                
                            elif answer == 'N':
                                print("Returning to queue selection...")
                                print()
                                break
                            else:
                                print("Error: Invalid input. Please enter Y or N.")
                        except EOFError:
                            raise EncodingError("Unexpected end of input")
                        except KeyboardInterrupt:
                            logger.info("Operation cancelled by user")
                            raise

                except PresetError as e:
                    logger.error(f"Preset error: {str(e)}")
                    response = input("Would you like to try again? (Y/N): ").strip().upper()
                    if response != 'Y':
                        raise
                    print()
                    continue

        finally:
            # Ensure cleanup happens even if an error occurred
            if encoder:
                try:
                    encoder.cleanup()
                except Exception as e:
                    logger.error(f"Cleanup failed: {str(e)}")
                    print(f"\nWarning: Cleanup failed: {str(e)}")

    except KeyboardInterrupt:
        logger.info("Operation cancelled by user")
        print("\nPress Enter to exit...")
        input()
        return 130
    except O3EncoderError as e:
        logger.error(f"Encoding error: {str(e)}")
        print("\nPress Enter to exit...")
        input()
        return 1
    except Exception as e:
        logger.error(f"Unexpected error: {str(e)}")
        print("\nPress Enter to exit...")
        input()
        return 1

if __name__ == "__main__":
    sys.exit(main())