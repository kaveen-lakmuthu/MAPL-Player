# MAPL Player

**MAPL Player** is a native desktop media player for Linux, built with **C++ and Qt6/QML**. It plays audio and video, generates subtitles offline using a local AI model, and provides compact video controls, a dedicated ambient Audio view, expandable lyrics and playlist panels, and timeline previews. Format support depends on the installed Qt Multimedia backend and codecs.

> **Version 2.3.15-alpha. Alpha testing is underway.** Use `scripts/install.sh` to install for your user on Linux.

The desktop UI redesign starts the **2.x** release series. Fixes use patch releases such as `2.0.1-alpha`; feature updates use minor releases such as `2.1.0-alpha`. Releases retain the `-alpha` suffix while alpha testing continues. The build derives the application version from `CMakeLists.txt` and exposes it in About and through `mapl-player --version`.

MAPL remembers the normal window size, maximized state, Audio/Video presentation, and the open or expanded Lyrics/Playlist panel between sessions. Opening a media file still selects its appropriate presentation. Leaving fullscreen through Escape, F, double-click or the fullscreen button restores the previous windowed or maximized state and preserves the normal window size; window placement stays with the window manager.

Menus and dropdowns use inset rows with room around text, checkmarks and submenu arrows. Buttons, panel headers and settings dialogs share more generous padding and group spacing while keeping the video area compact; the Thumbnail toolbar action uses its icon at narrow window widths.

The timeline and transport rows have an 8-pixel gap so speed, volume and fullscreen buttons stay visually separate. The playback bar follows its contents' height, including desktop theme sizing.

In fullscreen Video, move the pointer to the bottom edge to reveal a compact, translucent playback strip. It hides after 1.2 seconds of inactivity, or promptly when you move back into the picture. Hovering the strip, dragging its sliders or using a popup keeps it available. Moving elsewhere over the video only wakes the cursor; external captions stay above the strip without shifting when it appears.

Click the video once to pause or resume; double-click to enter or leave fullscreen without changing playback. The video-surface single click waits for your system's double-click interval so the gestures stay separate. The play button and Space shortcut respond immediately. Space toggles playback once per press, ignoring keyboard auto-repeat, and preserves the current position when pausing or resuming. Shortcuts stay inactive while typing or using a menu or dialog.

Brief notifications such as seeking, volume and track changes appear in the top-right of the playback area, clear of bottom subtitles. Longer messages wrap in a compact overlay; an open side panel keeps its header buttons unobstructed.

Selected thumbnails are stored as separate PNG files under `$XDG_DATA_HOME/mapl-player/thumbnails` (normally `~/.local/share/mapl-player/thumbnails`). Existing embedded thumbnails migrate at startup; originals stay in settings if saving fails. Volume and other preference changes no longer rewrite thumbnail image data during playback.

Subtitles sit higher by default, with a bottom gap of 12% of the playback area's height that scales with window/fullscreen size. Adjust **Bottom gap** (5–25%) under **Options → Subtitles → Appearance, timing and export…**; higher values raise the text, and MAPL remembers your choice. Captions stay above the fullscreen strip without moving when it hides, and long captions leave room at the top when possible.

Subtitle font size, text colour and background opacity are remembered too. Entering or leaving fullscreen keeps the chosen font size, and reopening MAPL restores the same appearance settings.

Changing subtitle timing or loading, replacing or clearing subtitles refreshes captions and transcript highlights immediately, including while paused, without seeking or resuming playback.

Subtitle exports use UTF-8 and replace the destination only after the complete file is saved successfully. Failed writes report an export error and preserve any existing destination file.

Automatic subtitle detection requires the same base filename, optionally followed by dot-separated tags: `Episode1.srt`, `Episode1.en.vtt` and `Episode1.en.forced.srt` match `Episode1.mp4`; `Episode10.srt` does not. Matching ignores case and treats brackets and other filename characters literally.

Click any Playlist row to select and play that item, including in folder-loaded queues and filtered results. Filtering preserves queue positions, and selecting an item keeps the queue for automatic advancement. Entries remain individually selectable when the same file appears more than once. Files with a saved position can still offer Resume or Start over.

XSPF imports decode XML escapes in paths and titles, including filenames containing `&`, and support CDATA and namespace-prefixed elements. Relative media locations resolve against the playlist file, including `xml:base` overrides. Malformed playlists report an error and keep the current queue.

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

This repository contains the native player; the earlier Electron project is separate.

## Requirements

- Linux with a Wayland or X11 session. A standalone window manager is sufficient; KDE Plasma is optional.
- A C++20 compiler, Git, CMake and Ninja. **CMake 3.21+** is required for the supplied presets.
- **Qt 6.5+** with Core, Gui, Qml, Quick, Multimedia, Network, Widgets and DBus. The UI uses [`QtCore.Settings`, introduced in Qt 6.5](https://doc.qt.io/qt-6/qml-qtcore-settings.html).
- **Qt 6.8+ with the FFmpeg backend** for the live visualizer. Other configurations use a steady playback indicator, following the availability of [Qt's decoded-audio buffer API](https://doc.qt.io/qt-6/qaudiobufferoutput.html).
- `ffmpeg` and `ffprobe` on `PATH` for previews, chapter scans, subtitle extraction and transcription audio preparation.
- A session D-Bus for MPRIS desktop controls. The regression tests also use `dbus-run-session`.

The first application configuration needs an internet connection to fetch the pinned `whisper.cpp` **v1.8.6** source. Model weights are downloaded separately when requested; transcription runs offline once a model is available. MAPL invokes the FFmpeg command-line tools, so FFmpeg development headers are not required by MAPL itself.

## Quick Start

### 1. Install dependencies

The commands below include build dependencies, QML runtime modules and desktop integration tools. Fedora is the development environment; the other commands use distribution package names and have not all been tested in fresh installations.

#### Fedora

```bash
sudo dnf install git cmake ninja-build gcc-c++ \
    qt6-qtbase-devel qt6-qtdeclarative-devel qt6-qtmultimedia-devel \
    qt6-qtwayland dbus-daemon desktop-file-utils xdg-utils
sudo dnf install ffmpeg-free
```

Use [`ffmpeg-free`](https://packages.fedoraproject.org/pkgs/ffmpeg/ffmpeg-free/) on stock Fedora. If you already use the full `ffmpeg` package from RPM Fusion, keep it instead of installing `ffmpeg-free`. For additional codecs, see the [RPM Fusion multimedia guide](https://rpmfusion.org/Howto/Multimedia).

#### openSUSE Tumbleweed

```bash
sudo zypper refresh
sudo zypper install git cmake ninja gcc-c++ \
    qt6-base-devel qt6-declarative-devel qt6-multimedia-devel \
    qt6-quickcontrols2-devel qt6-declarative-imports qt6-multimedia-imports \
    qt6-network-tls qt6-wayland qt6-wayland-integration \
    ffmpeg dbus-1 desktop-file-utils xdg-utils
```

The QML `-imports` packages are needed at runtime alongside the development packages. See the openSUSE Factory package information for [Qt Declarative](https://build.opensuse.org/package/show/openSUSE:Factory/qt6-declarative) and [Qt Multimedia](https://build.opensuse.org/package/show/openSUSE:Factory/qt6-multimedia). For additional codecs, follow the [openSUSE Packman codec guide](https://en.opensuse.org/SDB:Installing_codecs_from_Packman_repositories).

#### Arch Linux

```bash
sudo pacman -Syu --needed base-devel git cmake ninja \
    qt6-base qt6-declarative qt6-multimedia qt6-multimedia-ffmpeg \
    qt6-wayland ffmpeg dbus desktop-file-utils xdg-utils
```

Install the [Qt Multimedia FFmpeg backend](https://archlinux.org/packages/extra/x86_64/qt6-multimedia-ffmpeg/) for the live visualizer. Arch packages include development files, so separate `-dev` packages are not needed.

#### Ubuntu 26.04 LTS and Debian 13 (Trixie)

On Ubuntu, enable **Universe** if it is not already enabled; the Qt packages below are distributed there:

```bash
sudo apt update
sudo apt install software-properties-common
sudo add-apt-repository universe
```

Then, on Ubuntu or Debian:

```bash
sudo apt update
sudo apt install build-essential git cmake ninja-build ffmpeg \
    dbus-daemon desktop-file-utils xdg-utils \
    qt6-base-dev qt6-declarative-dev qt6-multimedia-dev qt6-wayland \
    qml6-module-qtcore qml6-module-qtqml qml6-module-qtqml-models \
    qml6-module-qtqml-workerscript qml6-module-qtquick \
    qml6-module-qtquick-window qml6-module-qtquick-controls \
    qml6-module-qtquick-templates qml6-module-qtquick-layouts \
    qml6-module-qtquick-dialogs qml6-module-qtquick-shapes \
    qml6-module-qtmultimedia qml6-module-qttest
```

Both releases provide a suitable Qt version: see [Ubuntu's Qt Declarative packages](https://packages.ubuntu.com/resolute/qt6-declarative-dev) and [Debian's Qt Multimedia packages](https://packages.debian.org/trixie/qt6-multimedia-dev). The explicit QML packages prevent an otherwise successful build from failing at startup with missing modules.

**Older releases:** the standard repositories for [Ubuntu 24.04](https://packages.ubuntu.com/noble/qt6-base-dev) and [Debian 12](https://packages.debian.org/bookworm/qt6-base-dev) provide Qt 6.4, which is too old for the current UI. Use a newer distribution release or a newer Qt SDK that includes Qt Declarative/Quick and Qt Multimedia. When you reach the build step, add the SDK's installation prefix to the configure command:

```bash
cmake -S . -B build -G Ninja -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_PREFIX_PATH="/path/to/Qt/<version>/gcc_64"
```

Replace the example path with your SDK directory. Keep its libraries and plugins available after installation; the installer does not bundle Qt. Qt 6.8+ is recommended for the full visualizer.

### 2. Build

Get the source if you do not already have a checkout:

```bash
git clone https://github.com/kaveen-lakmuthu/MAPL-Player.git
cd MAPL-Player
```

Run from the project root:

```bash
cmake -S . -B build -G Ninja -DCMAKE_BUILD_TYPE=Release
cmake --build build --parallel 4
```

Adjust the parallel build count to suit your machine. If an existing `build` directory uses a different generator, reuse that generator or choose a new build directory rather than mixing generators. The installation script expects `build/mapl-player`.

### 3. Run directly

```bash
./build/mapl-player
```

To open a file or check the version:

```bash
./build/mapl-player "/path/to/movie.mkv"
./build/mapl-player --version
```

### 4. Install for your user

Run from the project root:

```bash
./scripts/install.sh
```

This installs the executable to `~/.local/bin/mapl-player`, the launcher to `~/.local/share/applications/mapl-player.desktop`, and the icon under `~/.local/share/icons/`, without `sudo`.

The script also registers MAPL as the default handler for several common audio/video MIME types and refreshes desktop caches when the corresponding tools are available. On Plasma it refreshes the KDE service cache too; KDE is not required. Change file associations through your file manager's **Open With** settings if desired.

Launch from your application menu or run `~/.local/bin/mapl-player`. Ensure `~/.local/bin` is on your `PATH` to use the shorter `mapl-player` command.

After source updates, close MAPL, rebuild with `cmake --build build --parallel 4`, and run `./scripts/install.sh` again. Restart the player to use the updated executable. The installed executable bundles the application QML and statically linked Whisper/ggml, so it does not need the build folder at runtime. Qt libraries, QML plugins, media codecs, `ffmpeg` and `ffprobe` are still required. Settings, saved layout, playback history, thumbnails and downloaded models are preserved when reinstalling.

Use the instructions above for the current installation workflow. See [the native guide](docs/native-guide.md) for architecture, hardware acceleration notes and developer reference, [desktop media controls](docs/desktop-media.md) for MPRIS and audio delay, and [the model catalogue](docs/model-catalog.md) for Whisper models.

## Regression tests

Tests run locally through the commands below; this repository does not configure automatic GitHub Actions runs.

```bash
cmake --preset tests
cmake --build --preset tests --parallel 4
ctest --preset tests
```

This preset runs the regression suite without downloading Whisper models or building Whisper. See [tests/README.md](tests/README.md) for dependencies and coverage.

To build the application and its complete test suite together:

```bash
cmake --preset dev
cmake --build --preset dev --parallel 4
ctest --preset dev
```

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
- **Layout memory** — restores window size, maximized state, Audio/Video presentation and open/expanded panels between sessions
- **Frequency visualizer** — real audio analysis drives 24 vertical bass-to-treble bars, with silence/mute handling and a steady Reduce motion fallback
- **Direct playlist selection** — jump to any folder-queue entry, including filtered results and duplicate files, while retaining automatic advancement
- **Unified task controls** — download, verification and transcription progress with individual cancellation beside the timeline

---

## Getting started

- **Video / Audio** changes the presentation while keeping the same player alive.
- **Playlist** opens the queue from the top toolbar. Click a row to select it; enable **Auto-load folder files** to queue the current file's folder, or filter the list to find a title.
- **Lyrics & Subs** opens the transcript panel. Load a lyrics/subtitle file, search and select timed lines, adjust timing/appearance, or export the text. Expand the panel for a full view.
- **Options → Subtitles → Whisper models** manages Tiny/Base models. The generation tools select the model, language and transcription/translation task. Downloads require internet access; inference runs locally.
- **The task button beside the timeline** opens background progress and cancellation. Closing the popup leaves jobs running, and fullscreen playback controls provide the same access.
- **Options → Appearance** controls ambient colour/strength, the Audio visualizer and Reduce motion. The visualizer shows bass on the left, midrange in the middle and treble on the right.

## Troubleshooting

- **CMake cannot find Qt6Multimedia:** install the multimedia development package listed for your distribution and configure again.
- **A QML module is missing:** install the runtime modules/imports above. For `QtCore.Settings`, also check that Qt is at least version 6.5.
- **The visualizer shows a steady indicator:** check Qt 6.8+, that the Audio visualizer option is enabled, and that Reduce motion is off. Live bars need the FFmpeg backend; select it explicitly with `QT_MEDIA_BACKEND=ffmpeg ./build/mapl-player` when it is installed.
- **Previews or transcription extraction fail:** check `ffmpeg -version` and `ffprobe -version`, and confirm the tools can decode the file. Codec availability depends on your distribution's multimedia packages.
- **Desktop media controls are unavailable in a standalone window manager:** ensure the window-manager session has a session D-Bus. Local playback continues without MPRIS.

---

## License

MIT — see [`LICENSE`](LICENSE).
