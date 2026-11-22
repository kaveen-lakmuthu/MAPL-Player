# Regression tests

The suite uses Qt Test for C++ and Qt Quick Test for QML. It tests the production controllers, logic components and subtitle helpers directly; it does not extract code from source text.

## Run

Install the project's Qt development dependencies, including Qt Test and Qt Quick Test, plus Qt DBus, `dbus-run-session`, CMake 3.21 or newer and Ninja for the presets. On Ubuntu/Debian, install the Qt QML runtime modules as well; the [README's installation instructions](../README.md#1-install-dependencies) list the package sets for each distribution. Tests run locally; there is no automatic GitHub Actions workflow. From the repository root:

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
- XSPF XML entity decoding, URI encoding, CDATA, namespaces, relative locations and `xml:base`, queue order and duplicate entries, malformed-file rejection, and real playback of escaped filenames through the File menu handler and drag-and-drop.
- Pending playlist reads cancelled by newer media, track or playlist selections and window closing, without stale queue changes or notifications.
- Model checksum verification, atomic publication, synchronous `abort()` callbacks, HTTP/network failures, short writes, commit failures, existing-file preservation, cancellation and shutdown cleanup.
- Model management controls, verification status, sizes and deletion guards for active models.
- Supported media extensions and filenames requiring URL encoding.
- Thumbnail migration into separate data files, preserved covers and preferences across reopening, compact preference writes, failed saves and migration retries without losing existing selections.
- SRT/WebVTT text, timestamps, metadata blocks and export/import round trips.
- Whitespace-only SRT separators across LF, CRLF and CR line endings, preserving cue timing and multiline text.
- Automatic subtitle filename matching across episode numbers, dotted titles, language/kind tags, case differences, literal wildcard characters and encoded Unicode names.
- Atomic UTF-8 exports through paths and file URLs, successful overwrites, rejected and partial writes, preservation of existing files, and temporary-file cleanup. Write failures use file-size limits in a separate Unix process.
- Subtitle generation completing after a track switch, same-file reload or model download.
- Asynchronous chapter scans and embedded-subtitle extraction, stale results, process failures, timeouts and shutdown.
- Whisper cancellation during extraction or inference, late completion races, temporary-file cleanup and retry after cancellation.
- Loading every extracted application view, transcript and popup without broken bindings.
- Popup centering and bounds across window sizes, keyboard focus, modal shortcut isolation, fullscreen Escape handling and file chooser ownership.
- Fullscreen restoration to windowed or maximized state through the toggle, Escape, F and double-click, including direct window-state changes, repeated cycles, normal-size preservation and saved layout restoration after reopening.
- Fullscreen bottom-edge control reveal, short idle and pointer-leave timeouts, independent cursor hiding, hover/slider/popup protection, and stable video/caption geometry.
- Separate timeline/transport hit areas and bottom padding in narrow, wide, Audio and fullscreen layouts, with independent speed-popup and fullscreen button activation.
- Adjustable subtitle reading position, saved bottom gap, and space for tall captions in small windows.
- Subtitle size changes through the settings slider, stable rendered font size across fullscreen transitions, and size/colour/background restoration after closing immediately after an adjustment.
- Immediate paused-caption and transcript-highlight updates after timing shifts, subtitle replacement, file loading and clearing, in windowed and fullscreen views, without seeking or resuming; overlapping cues keep their display order and duplicate suppression.
- Video single-click pause/resume and complete double-click sequences entering/leaving fullscreen without even a temporary playback-state change.
- Volume arrow keys immediately after startup and with timeline, volume or sidebar controls focused. The QML harness uses the same `QApplication` startup as the player, and dialog tests wait for closing animations before checking restored shortcuts.
- Final volume persistence after immediate exit in Video, Audio and fullscreen, including zero, maximum and fractional wheel values, while playback saves stay debounced.
- Wheel volume control on audio/video and volume controls, high-resolution deltas, bounds and unmuting, while transcripts, playlists and modal panels retain normal scrolling.
- Full application builds also copy the executable to an otherwise empty temporary directory and test application-menu startup and Open With (paths and file URLs), with isolated settings and a private D-Bus session.

Download tests simulate network replies, including the synchronous error/finished signals that caused the cancellation bug. They never contact external servers. Background-job tests launch a small child-process fixture in place of ffprobe/ffmpeg, checking that cancellation reaps it and removes partial files. When ffmpeg/ffprobe are installed, an integration check also creates a tiny real Matroska file and verifies chapter scanning and subtitle extraction. Transcription tests run the production worker and controller with a deterministic inference substitute; they do not validate Whisper recognition quality. The app smoke tests do not run Whisper inference. Use the `dev` preset above to build the full application with the pinned Whisper dependency and run the complete suite locally.
