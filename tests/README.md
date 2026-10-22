# Regression tests

The suite uses Qt Test for C++ and Qt Quick Test for QML. It tests the production controllers, logic components and subtitle helpers directly; it does not extract code from source text.

## Run

Install the project's Qt development dependencies, including Qt Test and Qt Quick Test, plus Qt DBus, `dbus-run-session`, CMake 3.21 or newer and Ninja for the presets. On Ubuntu/Debian, install the Qt QML runtime modules as well; the [CI workflow](../.github/workflows/tests.yml) lists the complete package set. From the repository root:

```bash
cmake --preset tests
cmake --build --preset tests
ctest --preset tests
```

The `tests` preset sets `MAPL_BUILD_APP=OFF`, so these checks do not fetch or compile Whisper, download model weights, or require a GPU. The UI integration checks generate a temporary silent WAV file to exercise real Qt Multimedia loading and resume seeks, with isolated settings. The QML tests run with the offscreen platform and software rendering. Application smoke tests use a stub for Whisper inference and isolate settings in a temporary directory.

To build both the application and tests:

```bash
cmake --preset dev
cmake --build --preset dev
ctest --preset dev
```

The executable is then `build/mapl-player`, ready for `./scripts/install.sh`. The standalone test preset uses `build/test-only` and keeps its build files separate.

## Coverage

- Saved playback positions, resume/start-over choices, periodic and shutdown checkpoints, and recent-file persistence, ordering, URL encoding and missing files.
- Multilingual audio selection, persisted playback rate, signed audio delay, real shifted playback and decoder cleanup.
- MPRIS registration, typed metadata, remote controls, microsecond seeks, stale track IDs, property notifications and isolated multi-instance D-Bus behavior.
- Previous/Next, explicit Stop, end-of-media advancement, playlist looping and folder selection.
- Model checksum verification, atomic publication, synchronous `abort()` callbacks, HTTP/network failures, short writes, commit failures, existing-file preservation, cancellation and shutdown cleanup.
- Model management controls, verification status, sizes and deletion guards for active models.
- Supported media extensions and filenames requiring URL encoding.
- SRT/WebVTT text, timestamps, metadata blocks and export/import round trips.
- Subtitle generation completing after a track switch, same-file reload or model download.
- Asynchronous chapter scans and embedded-subtitle extraction, stale results, process failures, timeouts and shutdown.
- Whisper cancellation during extraction or inference, late completion races, temporary-file cleanup and retry after cancellation.
- Loading every extracted application view, transcript and popup without broken bindings.
- Popup centering and bounds across window sizes, keyboard focus, modal shortcut isolation, fullscreen Escape handling and file chooser ownership.
- Volume arrow keys immediately after startup and with timeline, volume or sidebar controls focused. The QML harness uses the same `QApplication` startup as the player, and dialog tests wait for closing animations before checking restored shortcuts.
- Wheel volume control on audio/video and volume controls, high-resolution deltas, bounds and unmuting, while transcripts, playlists and modal panels retain normal scrolling.
- Full application builds also copy the executable to an otherwise empty temporary directory and test application-menu startup and Open With (paths and file URLs), with isolated settings and a private D-Bus session.

Download tests simulate network replies, including the synchronous error/finished signals that caused the cancellation bug. They never contact external servers. Background-job tests launch a small child-process fixture in place of ffprobe/ffmpeg, checking that cancellation reaps it and removes partial files. When ffmpeg/ffprobe are installed, an integration check also creates a tiny real Matroska file and verifies chapter scanning and subtitle extraction. Transcription tests run the production worker and controller with a deterministic inference substitute; they do not validate Whisper recognition quality. The app smoke tests do not run Whisper inference. The GitHub Actions workflow also builds the full application with the pinned Whisper dependency.
