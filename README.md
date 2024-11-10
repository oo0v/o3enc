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

## Flow

```mermaid
graph TD
    Start([Start]) --> ComponentCheck{Components?}
    ComponentCheck -->|Missing| Install[Install Components]
    Install --> Analysis
    ComponentCheck -->|Present| Analysis[Video Analysis]
    
    Analysis --> MetadataCheck{Color Info<br/>in Metadata?}
    MetadataCheck -->|Yes| PresetSelect[Preset Selection]
    
    MetadataCheck -->|No| ColorSpace[Input Color Space<br/>[0] Auto<br/>[1] SD BT.601<br/>[2] HD BT.709]
    ColorSpace --> ColorRange[Input Color Range<br/>[0] Auto<br/>[1] TV 16-235<br/>[2] PC 0-255]
    ColorRange --> PresetSelect
    
    PresetSelect --> OutputName[Output Name<br/>[Y/N] Use input name]
    OutputName --> AudioCheck{Audio Track?}
    
    AudioCheck -->|Yes| AudioAnalysis[Audio Analysis]
    AudioAnalysis --> Encode
    AudioCheck -->|No| Encode
    
    Encode[2-Pass Encoding] --> Complete([Complete])
```

## Included Presets

- H.264 presets for basic use
- H.264/HEVC presets for High-Quality Archiving
- Optimized presets for specific platforms (iwara.tv)

## License

This tool is open-source and available under the MIT License.

This software uses FFmpeg licensed under the LGPLv2.1. FFmpeg source code can be obtained from:
- FFmpeg official site: https://ffmpeg.org/
- gyan.dev (Windows builds): https://www.gyan.dev/ffmpeg/builds/

The FFmpeg binary is NOT included in this repository/release package and will be downloaded during the first run.