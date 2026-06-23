# MAPL Player — Native C++ & Qt6

A high-performance, native desktop media player for **Fedora Linux / KDE Plasma 6**, built on **C++ and Qt6 (Qt Quick / QML)**. Plays virtually every major video and audio format with hardware acceleration, detects subtitles automatically, and generates them offline using a local AI model.

---

## Table of Contents

1. [Features](#features)
2. [System Architecture](#system-architecture)
3. [Build & Installation](#build--installation)
4. [System-Wide Installation (Plasma 6)](#system-wide-installation-plasma-6)
5. [Supported Formats](#supported-formats)
6. [Subtitle Support](#subtitle-support)
7. [Hardware Acceleration](#hardware-acceleration)
8. [AI Subtitle Generation (Whisper)](#ai-subtitle-generation-whisper)
9. [Keyboard Shortcuts](#keyboard-shortcuts)
10. [Configuration & Persistence](#configuration--persistence)
11. [File Formats Reference](#file-formats-reference)
12. [Developer Guide](#developer-guide)
13. [Media Codecs Setup](#media-codecs-setup)

---

## Features

| Feature | Details |
|---|---|
| **Format support** | MP4, MKV, AVI, MOV, WEBM, FLV, WMV, 3GP, MPEG, MPG + MP3, FLAC, WAV, OGG, M4A, AAC, OPUS, WMA, AIFF, WV, APE |
| **Subtitle detection** | Auto-detects external `.srt`/`.vtt` files and embedded tracks; shows a picker when multiple are found |
| **Offline AI subtitles** | Generates subtitles locally with `whisper.cpp` — no internet required after model download |
| **Timeline previews** | Hardware-accelerated (VA-API/NVDEC) sprite-sheet previews with ~8s generation for a 2.5h film |
| **Dynamic ambient UI** | Extracts dominant color from playing video and smoothly adapts the entire background |
| **Collapsible sidebar** | Auto-hides when a video starts playing; toggle with `☰` or expand from inside the panel |
| **Interactive transcript** | Click any subtitle line in the transcript panel to seek playback to that moment |
| **Cover art capture** | Snapshot any video frame as the track's album art |
| **XSPF playlists** | Load and queue full playlists via XSPF |
| **Folder play mode** | Optionally auto-load all media files in a video/audio file's folder |
| **VA-API hardware decoding** | Enabled by default for Intel/AMD GPU video decoding |

---

## System Architecture

```
main.cpp
  └── QQmlApplicationEngine
        └── main.qml  (UI)
              ├── PlayerController (C++)  — settings, file ops, frame color extraction,
              │                             timeline preview generation (ffmpeg), subtitle file scan
              ├── SubtitleGenerator (C++) — whisper.cpp offline transcription
              │     └── TranscriptionWorker (QThread)
              ├── ModelDownloader (C++)   — Whisper model download via QNetworkAccessManager
              └── Qt MediaPlayer          — playback, embedded track detection
```

### Component Responsibilities

#### `main.cpp`
- Sets `QT_FFMPEG_DECODING_HW_DEVICE_TYPES=vaapi` and `QT_FFMPEG_HW_ALLOW_PROFILE_MISMATCH=1` for automatic hardware decoding
- Enables `QML_XHR_ALLOW_FILE_READ` for local XSPF/subtitle file reading
- Initializes and loads the QML engine

#### `PlayerController`
- **`videoSink`** — hooks into `VideoOutput` to receive frames for color extraction
- **`handleVideoFrame()`** — samples pixel colors at 4fps to emit `backgroundColorChanged(hexColor)`
- **`generateTimelinePreviews(url, durationSec)`** — spawns a background `ffmpeg` process with `-hwaccel auto -discard nokey -skip_frame nokey` to generate a 10×10 sprite sheet at `~/.cache/mapl-player/previews/`
- **`findSubtitleFiles(mediaUrl)`** — scans the media file's directory for all `<basename>*.srt` and `<basename>*.vtt` files, returning `{ label, url }` maps
- **`getFilesInFolder(fileUrl)`** — enumerates all media files in a folder for folder-play mode
- **`captureThumbnail()`** / **`getThumbnail()`** — frame-snapshot cover art via `QSettings`
- **`saveVolume()`** / **`loadVolume()`** / **`saveLoop()`** / **`loadLoop()`** — persistent settings

#### `SubtitleGenerator` & `TranscriptionWorker`
- Extracts audio to a 16kHz mono PCM WAV via `ffmpeg`
- Runs `whisper.cpp` inference on a background `QThread`
- Reports progress via signal; returns `subtitlesReady(chunks)` on completion

#### `ModelDownloader`
- Downloads Whisper `.bin` model weights from Hugging Face
- Streams download with progress reporting; saves to `~/.cache/mapl-player/`

---

## Build & Installation

### Dependencies (Fedora Linux)

```bash
sudo dnf install cmake gcc-c++ \
    qt6-qtbase-devel qt6-qtdeclarative-devel qt6-qtmultimedia-devel \
    ffmpeg ffmpeg-devel libva-utils
```

### Dependencies (Ubuntu / Debian)

```bash
sudo apt install cmake g++ \
    qt6-base-dev qt6-declarative-dev qt6-multimedia-dev \
    libqt6multimedia6 ffmpeg libva-dev vainfo
```

### Compile

CMake automatically fetches `whisper.cpp` v1.8.6 as a dependency at configure time.

```bash
cd native
mkdir build && cd build
cmake .. -DCMAKE_BUILD_TYPE=Release
make -j$(nproc)
```

The executable is created at `native/build/mapl-player`.

### Run directly

```bash
./mapl-player
```

---

## System-Wide Installation (Plasma 6)

Run the install script from the **project root**:

```bash
./install.sh
```

This will:
1. Copy `native/build/mapl-player` → `~/.local/bin/mapl-player`
2. Copy `public/mapl-player-icon.png` → `~/.local/share/icons/hicolor/256x256/apps/`
3. Install `mapl-player.desktop` → `~/.local/share/applications/`
4. Rebuild the XDG desktop database (`update-desktop-database`)
5. Rebuild the KDE service cache (`kbuildsycoca6`)
6. Register MAPL as the default handler for common video/audio MIME types

**No `sudo` required.** Everything installs to your user's home directory.

After installing, set MAPL as your default media player:
> **System Settings → Applications → Default Applications → Video Player / Music Player**

Or right-click any video/audio file in Dolphin → **Open With → Other Application** → select MAPL Player → tick **Remember application association**.

---

## Supported Formats

The Qt6 Multimedia FFmpeg backend decodes all formats that system FFmpeg supports. The file picker exposes three filter groups:

| Group | Formats |
|---|---|
| **Video** | `.mp4` `.mkv` `.avi` `.mov` `.webm` `.flv` `.m4v` `.ts` `.ogv` `.wmv` `.3gp` `.mpg` `.mpeg` |
| **Audio** | `.mp3` `.flac` `.wav` `.ogg` `.m4a` `.aac` `.opus` `.wma` `.aiff` `.wv` `.ape` |
| **All Media** | All of the above combined |

> **Note:** Playback of H.264/H.265/AAC inside MKV or MP4 containers may require RPM Fusion `mesa-va-drivers-freeworld` on Fedora. See [Media Codecs Setup](#media-codecs-setup).

---

## Subtitle Support

### Automatic Detection

When a media file is loaded, MAPL automatically:
1. Scans the media file's directory for external subtitle files matching `<filename>*.srt` and `<filename>*.vtt`
2. Queries Qt MediaPlayer for any embedded subtitle tracks inside the container (MKV, MP4, etc.)

**If exactly one external file is found** and no embedded tracks exist, it is loaded silently.

**If multiple subtitle options are found** (e.g. `movie.en.srt` + `movie.fr.srt`, or embedded tracks), a **subtitle picker popup** appears automatically.

### Subtitle Picker

The picker lists:
- **External files** (loaded into MAPL's custom overlay — supports transcript panel, search, timing shift)
- **Embedded tracks** (activated via Qt's native track API — rendered directly onto the video output)

You can reopen the picker at any time via the subtitle controls.

### Supported Subtitle Formats

| Format | Auto-detect | Manual load | Notes |
|---|---|---|---|
| `.srt` (SubRip) | Yes | Yes | Full support including HTML tag stripping |
| `.vtt` (WebVTT) | Yes | Yes | WEBVTT/NOTE/STYLE headers stripped automatically |
| Embedded MKV/MP4 tracks | Yes | — | Native Qt rendering |

### Subtitle Naming Convention for Auto-Detection

Place subtitle files in the same folder as the video, using the same base filename:

```
/Videos/
  movie.mp4
  movie.srt          → label: "Default"
  movie.en.srt       → label: "en"
  movie.fr.srt       → label: "fr"
  movie.Japanese.vtt → label: "Japanese"
```

### Manual Subtitle Load

Use the subtitle button in the controls panel, or the file picker (`Subtitles & Lyrics` filter accepts `.srt`, `.vtt`, `.txt`).

### Subtitle Shift

If subtitle timing is off, use the shift controls in the Lyrics & Subtitles view (±0.5s / ±1s / custom). Export the corrected file as `.srt`, `.vtt`, or `.txt`.

---

## Hardware Acceleration

MAPL enables VA-API hardware video decoding by default via environment variables set in `main.cpp`:

```cpp
qputenv("QT_FFMPEG_DECODING_HW_DEVICE_TYPES", "vaapi");
qputenv("QT_FFMPEG_HW_ALLOW_PROFILE_MISMATCH", "1");
```

### Verify VA-API

```bash
vainfo
```

You should see `va_openDriver() returns 0` and a list of supported profiles (e.g. `VAProfileH264High : VAEntrypointVLD`).

On Fedora, H.264/H.265 GPU decoding requires RPM Fusion:

```bash
sudo dnf swap mesa-va-drivers mesa-va-drivers-freeworld
```

### Wayland / XWayland

MAPL runs natively on Wayland. If VA-API fails to initialize (common with some NVIDIA setups), force XWayland:

```bash
QT_QPA_PLATFORM=xcb ./mapl-player
```

---

## AI Subtitle Generation (Whisper)

MAPL can generate subtitles for any video or audio file entirely offline using a bundled [whisper.cpp](https://github.com/ggerganov/whisper.cpp) (OpenAI Whisper) implementation.

### Pipeline

```
Input file
  → ffmpeg: extract audio → 16kHz mono 16-bit PCM WAV
  → TranscriptionWorker (QThread): whisper_full() inference
  → subtitlesReady signal → QML subtitle chunks
```

### First-Time Model Setup

On first use, MAPL downloads a Whisper model:

| Model | Size | Speed | Accuracy |
|---|---|---|---|
| **Tiny** | ~77 MB | Fastest | Good for clean speech |
| **Base** | ~140 MB | Moderate | Better with noise/accents |

Models are saved to `~/.cache/mapl-player/` and reused on subsequent runs. No internet needed after download.

### Translation

Enable **Translate to English** in the subtitle generator panel to transcribe any foreign-language audio directly into English text.

---

## Keyboard Shortcuts

| Key | Action |
|---|---|
| `Space` | Play / Pause |
| `←` / `→` | Seek −5s / +5s |
| `F` or `Double-click` (video) | Toggle fullscreen |
| `M` | Toggle mute |
| `N` | Next track |
| `P` | Previous track |
| `Escape` | Exit fullscreen |

---

## Configuration & Persistence

All settings are stored via `QSettings` at:

```
~/.config/MAPL/MAPLPlayerNative.conf
```

Stored values include: volume, loop toggle, play-folder toggle, thumbnails (base64 PNG), and per-track settings.

Timeline preview sprite sheets are cached at:

```
~/.cache/mapl-player/previews/<md5-hash>.jpg
```

Whisper model files are cached at:

```
~/.cache/mapl-player/<model-name>.bin
```

---

## File Formats Reference

### XSPF Playlist (`.xspf`)

```xml
<?xml version="1.0" encoding="UTF-8"?>
<playlist version="1" xmlns="http://xspf.org/ns/0/">
  <trackList>
    <track>
      <title>Example Video</title>
      <location>file:///home/user/Videos/movie.mkv</location>
    </track>
    <track>
      <title>Example Song</title>
      <location>file:///home/user/Music/song.flac</location>
    </track>
  </trackList>
</playlist>
```

### SubRip Subtitles (`.srt`)

```
1
00:00:10,200 --> 00:00:13,500
Welcome to MAPL Player!

2
00:00:14,000 --> 00:00:18,200
This is a synced subtitle line.
```

### WebVTT Subtitles (`.vtt`)

```
WEBVTT

00:00:10.200 --> 00:00:13.500
Welcome to MAPL Player!

00:00:14.000 --> 00:00:18.200
This is a synced subtitle line.
```

---

## Developer Guide

### Registering a New C++ Class with QML

1. Add `QML_ELEMENT` to your class inside the `MAPLPlayerNative` CMake module:
    ```cpp
    #include <QtQml/QQmlEngine>
    class MyClass : public QObject {
        Q_OBJECT
        QML_ELEMENT
    public:
        Q_INVOKABLE void doSomething(const QString &param);
    signals:
        void somethingDone(const QString &result);
    };
    ```
2. Rebuild. In `main.qml`:
    ```qml
    import MAPLPlayerNative

    MyClass {
        id: myClass
        onSomethingDone: (result) => console.log(result)
    }
    ```

### QML ↔ C++ Communication Patterns

| Pattern | How |
|---|---|
| C++ → QML (push) | `emit mySignal(value)` in C++; `onMySignal: ...` in QML |
| QML → C++ (call) | `Q_INVOKABLE` method; called as `myObject.method(args)` from QML JS |
| Bidirectional binding | `Q_PROPERTY(T name READ get WRITE set NOTIFY changed)` |

---

## Media Codecs Setup

### Fedora (RPM Fusion)

Enable RPM Fusion first ([instructions](https://rpmfusion.org/Configuration)), then:

```bash
# H.264/H.265 GPU decoding support
sudo dnf swap mesa-va-drivers mesa-va-drivers-freeworld

# Full codec pack
sudo dnf groupupdate multimedia \
    --setop="install_weak_deps=False" \
    --exclude=PackageKit-gstreamer-plugin
sudo dnf install gstreamer1-plugins-ugly gstreamer1-libav
```

### Ubuntu / Debian

```bash
sudo apt install ubuntu-restricted-extras \
    gstreamer1.0-plugins-bad \
    gstreamer1.0-plugins-ugly \
    gstreamer1.0-libav
```
