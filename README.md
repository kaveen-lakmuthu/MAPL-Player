# MAPL Player

**MAPL Player** is a modern, native desktop media player for Linux, built on **C++ and Qt6/QML**. It plays virtually every video and audio format, generates subtitles offline using a local AI model, and ships with a premium dark UI with hardware-accelerated timeline previews, a collapsible sidebar, and intelligent subtitle detection.

> **Alpha testing is underway.** Use `scripts/install.sh` to install for your user on Linux.

---

## Repository Structure

| Path | Description |
|---|---|
| `src/` | C++ application entry point and controllers |
| `qml/` | Window shell, views, controls, dialogs and shared logic |
| `assets/icons/` | Application icon |
| `packaging/` | Desktop launcher template |
| `scripts/` | User-local installation script |
| `docs/` | Full build guide and developer reference |
| `tests/` | Qt Test and Qt Quick Test regression suite |
| `CMakeLists.txt` | Build configuration |

---

The legacy Electron project lives separately at `~/Projects/MAPL-Player-Electron`.

## Quick Start

### 1. Install dependencies (Fedora)

```bash
sudo dnf install cmake ninja-build gcc-c++ \
    qt6-qtbase-devel qt6-qtdeclarative-devel qt6-qtmultimedia-devel \
    ffmpeg ffmpeg-devel libva-utils
```

### 2. Build

```bash
cmake -S . -B build -DCMAKE_BUILD_TYPE=Release
cmake --build build -j$(nproc)
```

### 3. Run directly

```bash
./build/mapl-player
```

### Run regression tests

```bash
cmake --preset tests
cmake --build --preset tests
ctest --preset tests
```

This preset runs the regression suite without downloading Whisper models or building Whisper. See [tests/README.md](tests/README.md) for dependencies and coverage.

### 4. Install for your user

Run from the project root:

```bash
./scripts/install.sh
```

This installs the binary, icon, and `.desktop` entry to `~/.local/` — no `sudo` needed. Rebuilds the KDE service cache automatically. Then set MAPL as your default player in:

> **System Settings → Applications → Default Applications → Video Player / Music Player**

After source updates, close MAPL, rebuild with `cmake --build build -j$(nproc)`, and run `./scripts/install.sh` again. The installed executable bundles the application QML and statically linked Whisper/ggml, so it does not need the build folder at runtime. System Qt and media dependencies are still required. Settings, playback history and downloaded models are preserved when reinstalling.

See [`docs/native-guide.md`](docs/native-guide.md) for the full build guide, hardware acceleration setup, and developer reference.

---

## Key Features

- **Audio & playback controls** — multilingual audio tracks, 0.25×–3× speed and signed audio delay
- **Linux desktop media controls** — MPRIS playback, seeking, volume and track metadata
- **Resume playback** — remembers unfinished files and offers Resume or Start from beginning when reopened
- **Recent files** — reopen the latest 20 files from the sidebar, with full paths and a clear-list action
- **Broad format support** — MP4, MKV, AVI, MOV, WEBM, FLV, WMV, 3GP, MPEG + MP3, FLAC, WAV, OGG, M4A, AAC, OPUS, WMA, AIFF, and more
- **Smart subtitle detection** — auto-detects external `.srt`/`.vtt` files and embedded tracks with a language picker
- **Whisper model manager** — installed sizes, progress, cancellation and deletion, with SHA-256 checks and atomic downloads
- **Offline AI subtitle generation** — powered by `whisper.cpp` (OpenAI Whisper) running locally, with cancellation and cleanup
- **Responsive background jobs** — asynchronous chapter scanning and embedded subtitle extraction
- **Hardware-accelerated timeline previews** — VA-API/NVDEC-accelerated sprite sheet generation
- **Dynamic ambient UI** — extracts dominant color from the playing video and adapts the whole background
- **Interactive transcript panel** — click any subtitle line to seek to that moment
- **XSPF playlist support** — load and queue full playlists
- **Collapsible sidebar** — auto-hides during video playback for maximum screen real estate

---

## License

MIT — see [`LICENSE`](LICENSE).
