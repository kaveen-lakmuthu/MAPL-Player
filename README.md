# MAPL Player

**MAPL Player** is a modern, native desktop media player for Linux, built on **C++ and Qt6/QML**. It plays virtually every video and audio format, generates subtitles offline using a local AI model, and ships with a dark desktop UI with compact video controls, a dedicated ambient Audio view, expandable lyrics and playlist panels, and hardware-accelerated timeline previews.

> **Version 2.3.1-alpha. Alpha testing is underway.** Use `scripts/install.sh` to install for your user on Linux.

The desktop UI redesign starts the **2.x** release series. Fixes use patch releases such as `2.0.1-alpha`; feature updates use minor releases such as `2.1.0-alpha`. Releases retain the `-alpha` suffix while alpha testing continues. The build derives the application version from `CMakeLists.txt` and exposes it in About and through `mapl-player --version`.

MAPL remembers the normal window size, maximized state, Audio/Video presentation, and the open or expanded Lyrics/Playlist panel between sessions. Opening a media file still selects its appropriate presentation. Fullscreen is temporary; window placement stays with the window manager.

Click any Playlist row to play that item immediately, including in folder-loaded queues and filtered results. Filtering preserves queue positions, and selecting an item keeps the queue for automatic advancement. Entries remain individually selectable when the same file appears more than once.

During model downloads, verification, or transcription, a compact task button beside the timeline opens progress and individual cancellation controls. It is available in every view, including the fullscreen playback strip. Dismissing the task panel leaves jobs running; detailed model management remains in Options → Subtitles → Whisper models.

Audio view has a compact cava-style visualizer: 24 vertical bars respond to actual frequency content, with bass on the left and treble on the right. It analyzes decoded audio with a Hann-windowed FFT and logarithmic frequency bands, combines channel powers without cancelling opposite-phase stereo, and follows MAPL volume, mute and audio delay. Silence flattens the bars; pause/stop clears them and hidden views stop collecting samples. Qt 6.8+ with the FFmpeg backend provides audio samples; other backends, older Qt versions, and Reduce motion use a steady playback indicator. Toggle it through Options → Appearance → Audio visualizer.

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
- **Recent files** — reopen the latest 20 files from the File menu, with full paths and a clear-list action
- **Broad format support** — MP4, MKV, AVI, MOV, WEBM, FLV, WMV, 3GP, MPEG + MP3, FLAC, WAV, OGG, M4A, AAC, OPUS, WMA, AIFF, and more
- **Smart subtitle detection** — auto-detects external `.srt`/`.vtt` files and embedded tracks with a language picker
- **Whisper model manager** — installed sizes, progress, cancellation and deletion, with SHA-256 checks and atomic downloads
- **Offline AI subtitle generation** — powered by `whisper.cpp` (OpenAI Whisper) running locally, with cancellation and cleanup
- **Responsive background jobs** — asynchronous chapter scanning and embedded subtitle extraction
- **Hardware-accelerated timeline previews** — VA-API/NVDEC-accelerated sprite sheet generation
- **Dedicated Audio view** — prominent artwork, ambient lighting, live lyrics, an Up next summary and larger playback controls
- **Dynamic ambient UI** — broad lighting in Audio and restrained toolbar/control tinting in Video, with strength and reduced-motion options
- **Interactive transcript panel** — click any subtitle line to seek to that moment
- **XSPF playlist support** — load and queue full playlists
- **Expandable panels** — lyrics and playlists can sit beside the media or expand into full views

---

## License

MIT — see [`LICENSE`](LICENSE).
