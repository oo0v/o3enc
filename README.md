# o3Enc

o3Enc is a Python based tool for video encoding using FFmpeg, with CUDA acceleration and customizable presets.

## Requirements

- Windows 11 (PowerShell)
- NVIDIA GPU (for default presets)

## Installation

1. Extract the downloaded archive to your desired location
2. Run `o3Enc.exe` - required components will be automatically installed on first run

## Usage

Drag and drop a video file onto `o3Enc.exe`

## Presets Usage

Presets are defined in `presets.ini` with the following format:

```
[example_preset_name]
2pass=false                # Use two-pass encoding (true/false)
hwaccel=                   # Hardware acceleration (cuda, none, etc.)
encoder=libaom-av1         # Encoder
container=webm             # Container format
height=1080                # Output height (width is automatically calculated)
fps=30                     # Frame rate (space = same as input)
pixfmt=yuv420p             # Pixel format (space = auto)
scale_flags=lanczos        # Scaling algorithm (If you use scaling in option)
options=                   # FFmpeg encoding options (For advanced users)
audio_codec=libopus        # Audio codec
audio_bitrate=128k         # Audio bitrate
target_lufs=-18            # Audio normalization target (Integrated Loudness)
target_lra=7               # Target Loudness Range (LU, lower = more consistent volume)
target_tp=-2               # True Peak target (dB, prevents clipping)
```

## Flow

```mermaid
graph TD
    Start([Start]) --> ComponentCheck{Components?}
    ComponentCheck -->|Missing| Install[Install Components]
    Install --> Analysis
    ComponentCheck -->|Present| Analysis[Video Analysis]
    
    Analysis --> MetadataCheck{Color Info in Metadata?}
    MetadataCheck -->|Yes| PresetSelect[Preset Selection]
    
    MetadataCheck -->|No| ColorSpace["Color Space Selection"]
    ColorSpace --> ColorRange["Color Range Selection"]
    ColorRange --> PresetSelect
    
    PresetSelect --> OutputName[Output Name Selection]
    OutputName --> AudioCheck{Audio Track?}
    
    AudioCheck -->|Yes| AudioAnalysis[Audio Analysis]
    AudioAnalysis --> Encode
    AudioCheck -->|No| Encode
    
    Encode[Encoding] --> Complete([Complete])
```

## Included Presets

- H.264 presets for basic use
- H.264/HEVC presets for High-Quality Archiving
- VP9 and AV1
- Optimized presets for specific platforms (X, iwara.tv)

## License

Unlicense

- FFmpeg official site: https://ffmpeg.org/
- gyan.dev (Windows builds): https://www.gyan.dev/ffmpeg/builds/

The FFmpeg binary is NOT included in this repository/release package and will be downloaded during the first run.