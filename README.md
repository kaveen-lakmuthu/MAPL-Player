# MAPL Player (Mp4 Audio PLayback)

MAPL Player is a clean, feature-rich desktop media player designed for playing MP4/WebM videos as audio-focused media tracks or native videos. It includes dynamic background color matching, custom cover-art capture, XSPF playlist parsing, and integrated subtitles.

This repository hosts two distinct implementations:
1.  **[Native C++ & Qt6 Version (Current Production)](file:///home/kaveen/projects/MAPL-Player/native/README.md):** A high-performance version built directly on the C++ Qt Quick/QML framework, utilizing a local OpenAI Whisper model for offline speech-to-text subtitle generation and direct GPU decoding.
2.  **[Electron Version (Legacy Web Prototype)](file:///home/kaveen/projects/MAPL-Player/README.md):** An Electron-based desktop prototype written in HTML5, Vanilla JavaScript, and Tailwind CSS.

---

## 🚀 Native C++ & Qt6 Version (Recommended)

The native desktop implementation is designed for lightweight footprint (~20MB RAM) and hardware-accelerated playback.

### Key Features
*   **Offline speech-to-text transcription**: Generates subtitles locally in seconds using a bundled C++ implementation of OpenAI Whisper (`whisper.cpp`).
*   **Low memory footprint**: Written in native C++ using Qt Quick (QML) scene graphs.
*   **Hardware Acceleration (VA-API)**: Compiles with default support for GPU decoding on Linux.
*   **Interactive transcript syncing**: Click any transcribed segment to instantly seek playback to that word.

To build and run the native version, see the **[Native C++ Documentation](file:///home/kaveen/projects/MAPL-Player/native/README.md)**.

---

## 🌐 Electron & Web Version (Legacy Prototype)

The original HTML5-based Electron version runs a web-tech-based renderer.

### Key Features
*   **Dynamic Ambient Color Matching**: Draws active video frames to an offscreen canvas to extract pixel averages on the fly.
*   **Custom Cover Art Capture**: Freeze a frame in video mode and capture it to serve as the track's album cover art in audio mode.
*   **Drag-and-Drop Loader**: Load single media tracks, XSPF playlists, or subtitle files by dropping them onto the window.

### Setup and Launch
Make sure you have Node.js and npm installed.

1.  Install dependencies:
    ```bash
    npm install
    ```
2.  Launch the application:
    ```bash
    npm start
    ```

For detailed configurations, see the code in the root directory.

---

## 📜 License
This project is licensed under the MIT License. See the `LICENSE` file for details.
