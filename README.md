# o3Enc

o3Enc is a Windows batch script utility that simplifies video encoding using NVIDIA NVENC hardware acceleration. It allows users to create multiple versions of videos optimized for different platforms through customizable encoding queues.

## Features

- NVIDIA NVENC hardware acceleration support
- Multiple encoding presets for different use cases
- Automatic color management and audio level optimization

## Requirements

- Windows 10 later
- NVIDIA GPU with NVENC support

## Installation

1. Extract the downloaded archive to your desired location
2. Run `o3Enc.bat` - required components will be automatically installed on first run

## Usage

Either:
- Drag and drop a video file onto `o3Enc.bat`
- Run `o3Enc.bat <video file>`

## Included Presets

- High quality presets for H.264/HEVC encoding
- Optimized presets for specific platforms

## License

This tool is open-source and available under the MIT License.

This software uses FFmpeg licensed under the LGPLv2.1. FFmpeg source code can be obtained from:
- FFmpeg official site: https://ffmpeg.org/
- gyan.dev (Windows builds): https://www.gyan.dev/ffmpeg/builds/

The FFmpeg binary is NOT included in this repository/release package and will be downloaded during the first run.