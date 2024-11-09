# o3Enc

o3Enc is a Python-based tool for video encoding using FFmpeg, with CUDA acceleration and customizable presets.

## Requirements

- Python 3.7+
- Windows 10 or later
- NVIDIA GPU For NVENC hardware acceleration (optional)

## Installation

1. Extract the downloaded archive to your desired location
2. Run `o3Enc.bat` - required components will be automatically installed on first run

## Usage

Either:
- Drag and drop a video file onto `o3Enc.bat`
- Run `o3Enc.bat <video file>`

## Included Presets

- H.264/HEVC presets for High-Quality Archiving
- Optimized presets for specific platforms (iwara.tv)

## License

This tool is open-source and available under the MIT License.

This software uses FFmpeg licensed under the LGPLv2.1. FFmpeg source code can be obtained from:
- FFmpeg official site: https://ffmpeg.org/
- gyan.dev (Windows builds): https://www.gyan.dev/ffmpeg/builds/

The FFmpeg binary is NOT included in this repository/release package and will be downloaded during the first run.