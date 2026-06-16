# MAPL Player (Native C++ & Qt6 Version)

MAPL Player is a high-performance, native C++ desktop media player built for **Fedora Linux (KDE)** using **Qt6 (Qt Quick / QML)**. It features dynamic color extraction, cover-art snapshots, and a built-in local speech-to-text subtitle generator powered by **OpenAI Whisper** via `whisper.cpp`.

---

## Key Features

*   **Native Qt6 Performance:** Built directly on Qt6 Quick (QML) for fluid animations, native window integration, and a very low RAM footprint (~15MB - 30MB).
*   **Offline Whisper Subtitles:** Automatically transcribes or translates audio/video files locally. 
*   **Offline-First Security:** Downloads the required model file once on the first run; all network code is deactivated afterwards to guarantee 100% data privacy.
*   **Dynamic Backgrounds:** Intercepts active video frames via `QVideoSink` to sample pixel averages on the fly and transition the background colors.
*   **Custom Cover Art Capture:** Grab any paused video frame to save it persistently as PNG cover art.
*   **Interactive Transcript Panel:** Click on transcribed speech segments in the transcript sidebar to instantly seek the video playback.
*   **XSPF Playlist Parsing:** Read and filter XML-based XSPF playlists locally.

---

## System Prerequisites

To build and compile the application on Fedora Linux, you must install the GCC compiler, CMake, and the development headers for Qt6 and FFmpeg:

```bash
sudo dnf install cmake gcc-c++ qt6-qtbase-devel qt6-qtdeclarative-devel qt6-qtmultimedia-devel ffmpeg
```

---

## How to Build the Application

Configure and build the native C++ executable in the build directory:

1.  Navigate to the `native` directory:
    ```bash
    cd native
    ```
2.  Create and enter the build directory:
    ```bash
    mkdir -p build && cd build
    ```
3.  Configure with CMake (which automatically downloads and prepares `whisper.cpp` v1.8.6):
    ```bash
    cmake ..
    ```
4.  Compile using all available CPU threads:
    ```bash
    make -j$(nproc)
    ```

---

## Running the Application

After compilation, launch the executable directly:
```bash
./mapl-player
```

### Initial Model Download
The very first time you generate subtitles, the app will request to download the Whisper `.bin` model file from Hugging Face:
*   **Tiny Model (~77 MB):** Fast, low CPU/RAM usage.
*   **Base Model (~140 MB):** Higher transcription accuracy, handles heavy noise and accents.

The model is saved locally to `~/.cache/mapl-player/`. Once downloaded, you can disable internet access entirely, and transcription will operate completely offline.
