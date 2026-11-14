# MAPL desktop UI requirements

The redesign keeps the existing player’s commands, options and media workflows. The goal is to give video more room through compact controls and a quieter appearance. An option being absent from an illustrative preview is not authorization to remove it from the application.

## Layout

- Start the application content with its compact command bar: File for Open media / Load playlist / Load lyrics & subtitles / Recent files, Video / Audio / Lyrics & Subs / Playlist navigation, a labelled Thumbnail action, and Options. Keep the file name in the compact playback metadata and Audio view.
- Do not draw a custom title bar or duplicate minimize, maximize or close buttons. Let the window manager/compositor choose and manage window decorations, movement, resizing and closing. Preserve normal managed-window behaviour and window-title metadata for platform integration; do not force a frameless mode just to match the preview. The HTML depicts application content only.
- Give video the remaining content area, with its original aspect ratio. Remove the decorative outer card, redundant view heading and large surrounding padding.
- Keep Video and Audio directly accessible. Changing presentation preserves the file, playback state, position, queue, selected tracks, subtitle data and playback adjustments.
- Keep dedicated Lyrics & Subs and Playlist views through expandable panels. Panels may also sit beside the current media presentation.
- Keep thumbnails, timestamp, chapter name and subtitle text on timeline hover or scrubbing. Reuse the existing preview generation and sprite sheets.
- Keep Video controls compact. Give Audio its own artwork-led listening layout with room for ambient lighting and larger playback controls; the full playlist belongs in its panel. Use contrasting foregrounds and softly separated button surfaces, keyboard focus and desktop DPI scaling. Remove permanent button outlines, coloured edge strokes and inset bevel/highlight shadows. Use surface fill for hover, press and toggle feedback, keeping the keyboard focus indicator. Keep normal control labels at a minimum 4.5:1 contrast against their actual fill across light/dark themes and ambient colours. Distinguish Play/Pause from the secondary controls. Avoid hover enlargement.
- In the native player, use consistent monochrome icons for transport, seeking, loop, mute/volume, chapters and fullscreen, with tooltips, accessible names, keyboard shortcuts and visible active states. Use bundled/native icon assets so controls remain visible without the HTML viewer's icon runtime. Keep conventional labels such as speed and CC where useful. Text-labelled transport buttons may remain in the HTML preview for reliable inspection.
- In Video, keep ambient colour as a restrained tint on the existing toolbar and playback strip, with no extra surrounding space and black letterboxing. Audio may use broader, soft ambient lighting behind its artwork and metadata. Preserve stable high-contrast button/text colours, smooth tint updates and reduced-motion behaviour in both modes. Provide an on/off option and a capped tint-strength control.
- Keep familiar desktop playback interactions. Express MAPL’s identity through its integrated audio/video/lyrics workflow, thumbnail selection and offline subtitle tools, supported by restrained typography, colour and icon styling.

## Feature inventory and placement

| Existing feature | Desktop placement and behaviour | Existing implementation |
|---|---|---|
| Capture/select a video frame as the file’s cover thumbnail | Labelled Thumbnail action in Video and Audio layouts. Select a moment in Video view, then capture it. Keep each file’s saved cover and use it in Audio view and desktop metadata. | `NavigationSidebar.qml`, `PlayerController::captureThumbnail`, `PlayerController::getThumbnail`, `main.qml` |
| Open media | File → Open media. Preserve native chooser behaviour and command-line/Open With startup. | `FileDrawer.qml`, `MediaDialogs.qml`, `main.cpp` |
| Load XSPF playlists | Files menu. Preserve queue contents, ordering and loading. | `MediaDialogs.qml`, `MediaUtils.js`, `PlaybackSession.qml` |
| Load lyrics/subtitle files | Files menu and Lyrics & Subs tools. Preserve TXT, SRT and VTT support. | `MediaDialogs.qml`, `SubtitleFiles.qml`, `main.qml` |
| Drag and drop | Media surface. Preserve media, playlist, lyrics and subtitle drop handling. | `main.qml` |
| Recent files | File → Recent files. Preserve full paths, opening an entry and clearing the list. | `RecentFilesMenu.qml`, `PlaybackHistory` |
| Resume playback / start over | Resume prompt. Preserve checkpoints and per-file position memory. | `ResumeDialog.qml`, `PlaybackMemory.qml`, `PlaybackHistory` |
| Video / Audio presentation | Direct navigation controls. Retain automatic initial view selection when opening media and manual view switching. | `NavigationSidebar.qml`, `PlaybackSession.qml`, `VideoView.qml`, `AudioView.qml` |
| Audio artwork and metadata | Prominent artwork, title, artist, format, duration and track number in a dedicated Audio presentation. Preserve the live subtitle entry and next-track access. | `AudioView.qml` |
| Audio visualizer and ambient colours | Keep the visualizer available in Audio view. Keep broad ambient lighting in Audio and a compact chrome tint in Video, with on/off and strength in Options → Appearance. | `AudioView.qml`, `main.qml` |
| Playlist selection | Playlist panel/full view; Up next summary and a Playlist action in Audio. Keep current-track indication and selecting an entry. | `PlaylistView.qml`, `PlaybackSession.qml` |
| Automatically load folder files | Visible option in Playlist, also accessible through Options → Playback. Preserve persistence and queue updates. | `PlaylistView.qml`, `PlaybackSession.qml`, `PlayerController` |
| Previous / next file | Bottom transport strip and existing keyboard/desktop commands. | `TransportButtons.qml`, `PlaybackSession.qml`, `MprisService` |
| Play/pause and stop | Transport and playback commands. Preserve video click playback and desktop stop handling. | `TransportButtons.qml`, `VideoView.qml`, `PlaybackSession.qml`, `MprisService` |
| Seek ±5 seconds and arbitrary positions | Transport buttons, keyboard and timeline. Preserve chapter and transcript seeking. | `TransportButtons.qml`, `Timeline.qml`, `PlaybackSession.qml` |
| Loop playlist | Bottom strip and Playlist tools. Preserve the saved preference. | `TransportControls.qml`, `PlayerController` |
| Timeline previews | Popup above the timeline on deliberate hover/scrubbing, with frame, time, chapter and subtitle snippet. Preserve subtitle-density ticks and chapter markers. | `Timeline.qml`, `PlayerController::generateTimelinePreviews` |
| Volume and mute | Bottom strip. Preserve saved volume, wheel adjustment, arrow keys, bounds and unmuting behaviour. | `VolumeControl.qml`, `VolumeWheelHandler.qml`, `main.qml` |
| Fullscreen | Bottom control, double-click video, F and Escape. Preserve cursor/control hiding and protection while dialogs or controls are in use. | `VideoView.qml`, `main.qml`, `PlaybackControls.qml` |
| Audio track selection | Audio & Playback popup through Options → Audio and the compact playback-options control. Preserve all available tracks. | `PlaybackOptionsPopup.qml`, `PlaybackOptions` |
| Playback speed | Compact playback-options control. Preserve the complete existing 0.25×–3× selection, not just the preview’s illustrative subset. | `PlaybackOptionsPopup.qml`, `PlaybackOptions` |
| Signed audio delay and reset | Audio & Playback popup. Preserve −2000 to +2000 ms, 50 ms steps, reset and per-file reset behaviour. | `PlaybackOptionsPopup.qml`, `PlaybackOptions` |
| Subtitle auto-detection and track selection | CC access and Subtitles tools. Preserve embedded/external sources, language labels, disabled subtitles and extraction handling. | `SubtitlePicker.qml`, `SubtitleFiles.qml`, `SubtitleJobs.qml` |
| Lyrics / transcript | Side panel or expanded view. Preserve plain lyrics, search, active-line indication and click-to-seek. | `TranscriptView.qml` |
| Clear lyrics/subtitles | Lyrics & Subs tools and Subtitles menu. Preserve clearing the current subtitle/lyrics state. | `TranscriptView.qml`, `SubtitleFiles.qml` |
| Subtitle appearance | Lyrics & Subs settings. Keep font size, text colour and background opacity. | `TranscriptView.qml` |
| Subtitle timing adjustments | Lyrics & Subs settings. Keep −2, −0.5, +0.5 and +2 second adjustments. | `TranscriptView.qml`, `main.qml` |
| SRT / VTT / TXT export | Explicit export actions in Lyrics & Subs tools, with existing format availability and save chooser. | `TranscriptView.qml`, `MediaDialogs.qml`, `SubtitleUtils.js` |
| Offline generation | Lyrics & Subs generation tools. Keep model selection, task/translation mode, language, progress, errors and cancellation. | `SubtitleGeneratorPanel.qml`, `SubtitleJobs.qml`, `SubtitleGenerator` |
| Whisper model management | Options → Subtitles and generation tools. Keep installed/expected size, status, verification, download/retry, cancellation, deletion and in-use restrictions. Closing the manager must not cancel a download. | `ModelManager.qml`, `ModelDownloader` |
| Background job status and cancellation | Compact task/status controls accessible across views. Keep chapter scans, extraction and transcription responsive. | `PlayerContent.qml`, `SubtitleJobs.qml`, `BackgroundProcess` |
| Desktop media controls | Preserve playback, seeking, volume, rate, track title/artwork, navigation and Open URI integration. | `MprisService`, `MprisAdaptors` |
| About | Options → About MAPL Player. | `AboutDialog.qml` |

## Thumbnail scope

The native checkout’s existing thumbnail command captures the current decoded video frame and saves it under that media URL in settings. This behaviour must be retained. Enable frame capture only when the current file has an available video frame, including when that video file is presented in Audio view. An external-image thumbnail chooser was not found in this checkout; the design must not describe one as already implemented. The HTML preview demonstrates frame selection and per-file cover state using illustrative frames.

## Implementation boundary

The HTML is a design preview, not a replacement media player. Keep the native playback, preview, history and subtitle systems while reorganizing QML. Preserve the full existing option ranges and background-job behaviour even where the preview uses abbreviated sample content. Validate existing playback, focus, shortcuts, subtitle, model and desktop-integration regression coverage when implementing the QML changes.

The preview’s File and Options menus must open and remain usable through submenu clicks. Option commands open inspectable dialogs instead of placeholder menu text. Keep visible text transport labels when the HTML is opened without the chat viewer’s icon runtime; the native transport uses icons with tooltips and accessible names. Verify real browser clicks, light/dark control contrast, reduced motion, narrow windows, thumbnail state and view switching. File inputs select local files for inspection; Whisper inference and model operations continue to belong to the native player.

## Native implementation

The native layout uses a 40 px command bar, a 72 px playback strip in Video, and a roomier 116 px strip with a centered 60 px Play/Pause button in Audio. Expanded lyrics/playlist views use compact controls. The default window is 1120 × 720, with a minimum of 640 × 420. Video occupies the remaining area without an outer card or padding; aspect-ratio letterboxing stays black. Window decorations remain under the window manager’s control.

Video and Audio select the media presentation. Lyrics & Subs and Playlist toggle a side panel; the panel’s expand control opens its full view, and its close control restores the media area. These operations keep the same player and video output alive. Audio has its own ambient listening background, larger saved artwork, metadata, live lyrics/subtitle access and an Up next summary. Its Playlist action opens the full queue beside the audio presentation. It adapts to small windows and side panels without changing playback.

- File contains media, XSPF, lyrics/subtitle loading and recent files.
- Options → Playback and audio contains tracks/speed/delay, looping and folder loading. The playback strip’s rate button also opens tracks/speed/delay.
- Options → Subtitles contains appearance/timing/export, track selection, generation, model management and clearing. Generation remains available when subtitles are already loaded.
- Options → Appearance contains ambient color, strength (5–25%), the audio visualizer and Reduce motion. These preferences persist. Reduce motion is an application preference in this pass; it suppresses ambient animation, visualizer animation and fullscreen control fades.
- Thumbnail captures the displayed video frame in either media presentation. It stays disabled until a frame is available; loading another file clears frame availability so the previous file’s frame cannot become the new file’s cover.

Build with `cmake --preset dev` and `cmake --build --preset dev`; run `./build/mapl-player`. Validation uses `ctest --preset dev --output-on-failure`, including UI interaction, playback, subtitles, model management, desktop controls and standalone application startup. The native layout has also been rendered with a generated video through the window manager, including the minimum window size.
