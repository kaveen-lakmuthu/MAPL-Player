# MAPL Player

**MAPL Player** is a modern, native desktop media player for Linux, built on **C++ and Qt6/QML**. It plays virtually every video and audio format, generates subtitles offline using a local AI model, and ships with a premium dark UI with hardware-accelerated timeline previews, a collapsible sidebar, and intelligent subtitle detection.

> **Alpha testing is underway.** Use `install.sh` to install system-wide on Fedora/Plasma 6.

---

## Repository Structure

| Directory | Description |
|---|---|
| `native/` | **Production** — native C++ & Qt6 application (recommended) |
| `electron/` | Legacy — original Electron/HTML5 prototype (unmaintained) |
| `public/` | App icon (`mapl-player-icon.png`) |
| `install.sh` | One-step install script for Fedora/KDE Plasma 6 |
| `mapl-player.desktop` | XDG desktop entry for system integration |

---

## Quick Start (Native Version)

### 1. Install dependencies (Fedora)

```bash
sudo dnf install cmake gcc-c++ \
    qt6-qtbase-devel qt6-qtdeclarative-devel qt6-qtmultimedia-devel \
    ffmpeg ffmpeg-devel libva-utils
```

### 2. Build

```bash
cd native
mkdir build && cd build
cmake .. -DCMAKE_BUILD_TYPE=Release
make -j$(nproc)
```

### 3. Run directly

```bash
./mapl-player
```

### 4. Install system-wide (KDE Plasma 6 / Fedora)

Run from the project root:

```bash
./install.sh
```

This installs the binary, icon, and `.desktop` entry to `~/.local/` — no `sudo` needed. Rebuilds the KDE service cache automatically. Then set MAPL as your default player in:

> **System Settings → Applications → Default Applications → Video Player / Music Player**

See [`native/README.md`](native/README.md) for the full build guide, hardware acceleration setup, and developer reference.

---

## Key Features

- **Broad format support** — MP4, MKV, AVI, MOV, WEBM, FLV, WMV, 3GP, MPEG + MP3, FLAC, WAV, OGG, M4A, AAC, OPUS, WMA, AIFF, and more
- **Smart subtitle detection** — auto-detects external `.srt`/`.vtt` files and embedded tracks with a language picker
- **Offline AI subtitle generation** — powered by `whisper.cpp` (OpenAI Whisper) running locally, no internet needed
- **Hardware-accelerated timeline previews** — VA-API/NVDEC-accelerated sprite sheet generation
- **Dynamic ambient UI** — extracts dominant color from the playing video and adapts the whole background
- **Interactive transcript panel** — click any subtitle line to seek to that moment
- **XSPF playlist support** — load and queue full playlists
- **Collapsible sidebar** — auto-hides during video playback for maximum screen real estate

---

## License

MIT — see [`LICENSE`](LICENSE).
