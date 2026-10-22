import QtQuick
import QtQuick.Window
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Dialogs
import QtMultimedia
import MAPLPlayerNative
import "components"
import "dialogs"
import "logic"
import "logic/MediaUtils.js" as MediaUtils
import "logic/SubtitleUtils.js" as SubtitleUtils

ApplicationWindow {
    id: window
    width: 850
    height: 700
    minimumWidth: 600
    minimumHeight: 600
    visible: true
    title: "MAPL Player - Native C++"
    font.family: "Inter, Noto Sans Sinhala, Noto Sans, sans-serif"

    property bool desktopControlsEnabled: true
    readonly property bool modalDialogOpen: playbackOptionsPopup.visible || resumeDialog.visible || modelManager.visible || recentFilesMenu.visible || aboutModal.visible || subtitlePickerPopup.visible || chaptersPopup.visible || fileDialogs.dialogOpen
    onModalDialogOpenChanged: {
        if (modalDialogOpen)
            controlsVisible = true;
    }
    property alias playbackOptions: playbackOptionsBackend
    property alias desktopControls: mpris
    property bool loopPlaylist: controller.loadLoop()
    property alias playbackHistory: history
    property alias playbackMemory: memory
    readonly property bool resumePending: memory.pendingResume !== null
    readonly property string resumeTitle: memory.pendingResume !== null ? memory.pendingResume.title : ""
    readonly property real resumePositionMs: memory.pendingResume !== null ? memory.pendingResume.position : 0
    property alias mediaPlayer: player
    property alias playerController: controller
    property alias subtitleGenerator: subGenerator
    property alias modelDownloader: modelDownloaderBackend
    property alias videoOutput: playerLayout.videoOutput
    property alias seekSlider: playerLayout.seekSlider
    property alias volumeSlider: playerLayout.volumeSlider
    property alias transcriptListView: playerLayout.transcriptListView
    property string messageText: ""
    property real transcriptionProgressValue: 0
    property real downloadProgressValue: 0
    property string subtitleModel: "tiny"
    property string subtitleLanguage: "Auto-Detect"
    property bool translateSubtitles: false

    PlaybackOptions {
        id: playbackOptionsBackend
        player: window.mediaPlayer
        audioOutput: mainAudioOutput
        onAdjustmentError: message => window.showMessage(message)
    }
    PlaybackOptionsPopup {
        id: playbackOptionsPopup
        app: window
    }
    function openPlaybackOptions() {
        playbackOptionsPopup.open();
    }
    function resetAudioDelay() {
        playbackOptionsBackend.resetAudioDelay();
    }
    function seekTo(position) {
        mpris.seekToMs(Math.round(position));
        playbackOptionsBackend.synchronize();
    }
    MprisService {
        id: mpris
        player: window.mediaPlayer
        audioOutput: mainAudioOutput
        applicationWindow: window
        playlistCount: window.playlist.length
        trackIndex: window.currentTrackIndex
        trackRevision: window.mediaRevision
        trackUrl: window.currentTrackIndex >= 0 && window.currentTrackIndex < window.playlist.length ? window.playlist[window.currentTrackIndex].url : ""
        trackTitle: window.currentTrackIndex >= 0 && window.currentTrackIndex < window.playlist.length ? window.playlist[window.currentTrackIndex].title : ""
        artUrl: window.currentThumbnailDataUrl
        looping: window.loopPlaylist
        onPlayRequested: {
            if (window.currentTrackIndex < 0 && window.playlist.length > 0)
                window.loadTrack(0);
            window.playCurrentTrack();
        }
        onPauseRequested: player.pause()
        onToggleRequested: window.togglePlayPause()
        onStopRequested: playbackSession.stopPlayback()
        onNextRequested: playbackSession.navigateFromDesktop(1)
        onPreviousRequested: playbackSession.navigateFromDesktop(-1)
        onOpenUriRequested: uri => window.loadMediaFile(uri)
        onRateRequested: rate => playbackOptionsBackend.rate = rate
        onVolumeRequested: volume => {
            window.isMuted = false;
            window.volumeSlider.value = volume * 100;
        }
        onQuitRequested: window.close()
    }

    PlaybackMemory {
        id: memory
        app: window
    }
    PlaybackHistory {
        id: history
    }
    ResumeDialog {
        id: resumeDialog
        app: window
    }
    ModelManager {
        id: modelManager
        app: window
    }
    function openModelManager() {
        modelDownloaderBackend.refreshModels();
        modelManager.open();
    }

    RecentFilesMenu {
        id: recentFilesMenu
        app: window
    }

    function openRecentFiles() {
        history.refreshRecentFiles();
        recentFilesMenu.open();
    }
    function openRecentFile(url) {
        memory.openRecent(url);
    }
    function resumePlayback() {
        memory.resume();
    }
    function startPlaybackOver() {
        memory.startOver();
    }
    function playCurrentTrack() {
        playbackSession.playCurrentTrack();
    }

    onClosing: {
        memory.checkpoint();
        history.sync();
        // Shutdown's position reset must not replace the checkpoint just saved.
        memory.transitioning = true;
        player.stop();
        playbackOptionsBackend.resetAudioDelay();
        mpris.stop();
    }

    PlaybackSession {
        id: playbackSession
        app: window
    }
    SubtitleFiles {
        id: subtitleFiles
        app: window
    }
    SubtitleJobs {
        id: subtitleJobs
        app: window
    }
    MediaDialogs {
        id: fileDialogs
        app: window
    }

    function restartControlsHideTimer() {
        controlsHideTimer.restart();
    }
    function openAboutDialog() {
        aboutModal.open();
    }
    function openMediaDialog() {
        fileDialogs.openMediaDialog();
    }
    function openPlaylistDialog() {
        fileDialogs.openPlaylistDialog();
    }
    function openLyricsDialog() {
        fileDialogs.openLyricsDialog();
    }
    function openExportDialog() {
        fileDialogs.openExportDialog();
    }

    // --- State Properties ---
    property var playlist: []
    property int currentTrackIndex: -1
    property bool playFolderToggle: controller.loadPlayFolderToggle()
    property string currentLyrics: ""
    property var subtitleChunks: []
    property string activeSubtitleText: ""
    property int subtitleFontSize: 18
    property string subtitleTextColor: "#ffffff"
    property real subtitleBgOpacity: 0.55
    property string transcriptSearchQuery: ""
    property int currentActiveSubtitleIndex: -1
    property int mediaRevision: 0
    property var subtitleGenerationRequest: null

    property var filteredSubtitleChunks: {
        if (!subtitleChunks)
            return [];
        if (transcriptSearchQuery.trim() === "") {
            return subtitleChunks;
        }
        var query = transcriptSearchQuery.toLowerCase();
        var result = [];
        for (var i = 0; i < subtitleChunks.length; i++) {
            var chunk = subtitleChunks[i];
            if (chunk.text && chunk.text.toLowerCase().indexOf(query) !== -1) {
                result.push({
                    originalIndex: i,
                    start: chunk.start,
                    end: chunk.end,
                    text: chunk.text
                });
            }
        }
        return result;
    }

    // View state: 'audio' | 'video' | 'lyrics' | 'playlist'
    property string currentView: "audio"
    property bool sidebarOpen: false
    property bool sidebarExpanded: true

    onCurrentViewChanged: {
        if (currentView !== "video") {
            sidebarExpanded = true;
        } else if (player.playbackState === MediaPlayer.PlayingState) {
            sidebarExpanded = false;
        }
    }
    property string currentThumbnailDataUrl: ""
    property string currentTimelinePreviewSheet: ""
    property bool controlsVisible: true

    // Subtitle track selection state
    property var availableSubtitles: []      // [{label, url, isEmbedded, embeddedIndex}]
    property bool subtitlePickerVisible: false
    property bool subtitleDetectionDone: false  // guard against duplicate detection per file
    property string activeSubtitleUrl: ""
    property int activeEmbeddedTrackIndex: -1
    property var mediaChapters: []
    property bool chaptersPopupVisible: false

    // Set by main.cpp via engine.setInitialProperties() when MAPL is launched
    // by double-clicking a file in Dolphin or via xdg-open / command line.
    property string initialFileUrl: ""

    Component.onCompleted: {
        if (desktopControlsEnabled)
            mpris.start();
        if (initialFileUrl !== "") {
            loadMediaFile(initialFileUrl);
        }
    }

    onVisibilityChanged: {
        if (window.visibility !== Window.FullScreen) {
            controlsVisible = true;
        } else {
            sidebarOpen = false;
        }
    }

    onPlayFolderToggleChanged: {
        syncPlaylistForFolderToggle();
    }

    function toggleFullscreen() {
        if (window.visibility === Window.FullScreen) {
            window.visibility = Window.Windowed;
        } else {
            window.visibility = Window.FullScreen;
        }
    }

    Timer {
        id: controlsHideTimer
        interval: 3000
        running: window.visibility === Window.FullScreen && !playerLayout.controlsHovered && !window.modalDialogOpen
        repeat: false
        onTriggered: {
            controlsVisible = false;
        }
    }

    Shortcut {
        sequence: "Esc"
        enabled: window.visibility === Window.FullScreen && !window.modalDialogOpen
        onActivated: {
            window.visibility = Window.Windowed;
        }
    }

    // --- Mute & Notification Properties & Helpers ---
    property bool isMuted: false

    Timer {
        id: messageTimer
        interval: 3000
        repeat: false
        onTriggered: messageText = ""
    }

    function showMessage(msg) {
        messageText = msg;
        messageTimer.restart();
    }

    function togglePlayPause() {
        playbackSession.togglePlayPause();
    }

    function seekRelative(offsetSeconds) {
        playbackSession.seekRelative(offsetSeconds);
    }

    function changeVolume(delta) {
        var newVol = Math.max(0, Math.min(100, volumeSlider.value + delta));
        volumeSlider.value = newVol;
        if (newVol > 0)
            isMuted = false;
        showMessage("Volume: " + Math.round(newVol) + "%");
    }

    function toggleMute() {
        isMuted = !isMuted;
        showMessage(isMuted ? "Muted" : "Unmuted");
    }

    function playNext() {
        playbackSession.playNext();
    }

    function playPrev() {
        playbackSession.playPrev();
    }

    // --- Keyboard Shortcuts ---
    Shortcut {
        sequence: "Space"
        enabled: !window.modalDialogOpen
        onActivated: togglePlayPause()
    }

    Shortcut {
        sequence: "f"
        enabled: !window.modalDialogOpen
        onActivated: toggleFullscreen()
    }

    Shortcut {
        sequence: "Right"
        enabled: !window.modalDialogOpen
        onActivated: seekRelative(5)
    }

    Shortcut {
        sequence: "Left"
        enabled: !window.modalDialogOpen
        onActivated: seekRelative(-5)
    }

    Shortcut {
        sequence: "Up"
        enabled: !window.modalDialogOpen
        onActivated: changeVolume(5)
    }

    Shortcut {
        sequence: "Down"
        enabled: !window.modalDialogOpen
        onActivated: changeVolume(-5)
    }

    Shortcut {
        sequence: "m"
        enabled: !window.modalDialogOpen
        onActivated: toggleMute()
    }

    Shortcut {
        sequence: "n"
        enabled: !window.modalDialogOpen
        onActivated: playNext()
    }

    Shortcut {
        sequence: "p"
        enabled: !window.modalDialogOpen
        onActivated: playPrev()
    }

    // Dynamic background colors updated from C++ PlayerController
    property color bgBaseColor: "#0f172a"      // Slate-900 (Default)
    property color containerColor: "#1e293b"   // Slate-800 (Default)
    property color accentColor: "#3b82f6"      // Blue-500 (Default)

    // Custom background transitions
    Behavior on bgBaseColor {
        ColorAnimation {
            duration: 600
            easing.type: Easing.InOutQuad
        }
    }
    Behavior on containerColor {
        ColorAnimation {
            duration: 600
            easing.type: Easing.InOutQuad
        }
    }

    // --- C++ Backend Elements ---
    PlayerController {
        id: controller
        videoSink: window.videoOutput.videoSink

        onBackgroundColorChanged: hexColor => {
            var c = Qt.color(hexColor);
            // Calculate perceived luminance (0.0 to 1.0)
            var luminance = 0.299 * c.r + 0.587 * c.g + 0.114 * c.b;

            // Tint and heavily darken the background base color based on luminance
            // If the source color is extremely light, we darken it much more aggressively
            var bgDarken = luminance > 0.7 ? 5.5 : (luminance > 0.5 ? 4.5 : 3.0);
            bgBaseColor = Qt.darker(hexColor, bgDarken);

            // Styled panel background: semi-transparent, very dark tint of the color
            // This guarantees high contrast for white text/labels under any dynamic video/album art
            var panelDarken = luminance > 0.7 ? 4.5 : (luminance > 0.5 ? 3.5 : 2.2);
            var darkTint = Qt.darker(hexColor, panelDarken);
            containerColor = Qt.rgba(darkTint.r, darkTint.g, darkTint.b, 0.75);

            accentColor = hexColor;
        }

        onThumbnailCaptured: (trackUrl, base64) => {
            currentThumbnailDataUrl = "data:image/png;base64," + base64;
        }

        onTimelinePreviewsReady: (trackUrl, spriteSheetPath) => {
            console.log("[DEBUG] timelinePreviewsReady signal received. trackUrl:", trackUrl, "spriteSheetPath:", spriteSheetPath);
            var currentSource = decodeURIComponent(player.source.toString());
            var decodedTrack = decodeURIComponent(trackUrl);
            console.log("[DEBUG] Current player source (decoded):", currentSource);
            if (currentSource === decodedTrack || currentSource.indexOf(decodedTrack) !== -1 || decodedTrack.indexOf(currentSource) !== -1) {
                currentTimelinePreviewSheet = "file://" + spriteSheetPath;
                console.log("[DEBUG] Loaded timeline preview sheet:", currentTimelinePreviewSheet);
            } else {
                console.log("[DEBUG] Warning: Track URL mismatch!");
            }
        }
    }

    SubtitleGenerator {
        id: subGenerator
    }

    ModelDownloader {
        id: modelDownloaderBackend
        inUsePath: subGenerator.activeModelPath
    }

    // --- Native Media Player ---
    MediaPlayer {
        id: player
        audioOutput: AudioOutput {
            id: mainAudioOutput
            volume: volumeSlider.value / 100.0
            muted: isMuted
        }
        videoOutput: window.videoOutput

        onErrorOccurred: (error, errorString) => {
            showMessage("Media Error: " + errorString);
        }

        onDurationChanged: {
            console.log("[DEBUG] MediaPlayer duration changed to:", player.duration, "source:", player.source.toString());
            if (player.duration > 0 && player.source.toString() !== "") {
                if (MediaUtils.isVideo(player.source)) {
                    console.log("[DEBUG] Generating timeline previews for:", player.source.toString());
                    controller.generateTimelinePreviews(player.source.toString(), player.duration / 1000.0);
                } else {
                    console.log("[DEBUG] Track is not a video file.");
                }
            }
        }

        onTracksChanged: {
            // Fires once when Qt has finished scanning embedded audio/subtitle tracks.
            // We use subtitleDetectionDone to ensure we only run once per media file.
            if (!subtitleDetectionDone) {
                subtitleDetectionDone = true;
                detectSubtitles();
            }
        }

        onPositionChanged: {
            if (!seekSlider.pressed && player.duration > 0) {
                seekSlider.value = (player.position / player.duration) * 100;
            }

            // Sync subtitles overlay & list view highlight
            if (subtitleChunks.length > 0) {
                var posSec = player.position / 1000.0;
                var activeIdx = -1;
                var activeChunks = [];
                for (var i = 0; i < subtitleChunks.length; i++) {
                    var chunk = subtitleChunks[i];
                    if (posSec >= chunk.start && posSec <= chunk.end) {
                        var duplicate = false;
                        for (var c = 0; c < activeChunks.length; c++) {
                            if (activeChunks[c].text === chunk.text) {
                                duplicate = true;
                                break;
                            }
                        }
                        if (!duplicate) {
                            activeChunks.push({
                                index: i,
                                start: chunk.start,
                                end: chunk.end,
                                text: chunk.text
                            });
                        }
                    }
                }

                if (activeChunks.length > 0) {
                    // Sort by duration descending (longest duration first, i.e., title cards/lyrics on top, dialogue on bottom)
                    activeChunks.sort(function (a, b) {
                        var durA = a.end - a.start;
                        var durB = b.end - b.start;
                        return durB - durA;
                    });

                    var joinedText = "";
                    for (var k = 0; k < activeChunks.length; k++) {
                        if (k > 0)
                            joinedText += "\n";
                        joinedText += activeChunks[k].text;
                    }

                    activeSubtitleText = joinedText;
                    activeIdx = activeChunks[activeChunks.length - 1].index;
                } else {
                    activeSubtitleText = "";
                }

                if (activeIdx !== -1) {
                    currentActiveSubtitleIndex = activeIdx;
                    // Only auto-scroll the list when not searching, so the user can browse freely
                    if (transcriptListView.visible && transcriptSearchQuery.trim() === "") {
                        if (transcriptListView.currentIndex !== activeIdx) {
                            transcriptListView.currentIndex = activeIdx;
                            transcriptListView.positionViewAtIndex(activeIdx, ListView.Center);
                        }
                    }
                } else {
                    currentActiveSubtitleIndex = -1;
                }
            }
        }

        onPlaybackStateChanged: {
            if (player.playbackState === MediaPlayer.PlayingState && currentView === "video") {
                sidebarExpanded = false;
            }
        }

        onMediaStatusChanged: playbackSession.handleMediaStatusChanged(player.mediaStatus)
    }

    // --- File Dialogs ---

    // Tracks the pending export format ("srt" | "vtt" | "txt")
    property string pendingExportFormat: "srt"

    // --- Drag and Drop File Support Helper ---
    function handleDroppedFile(fileUrl) {
        var urlStr = fileUrl.toString();
        var lower = urlStr.toLowerCase();

        if (lower.endsWith(".xspf")) {
            var request = new XMLHttpRequest();
            request.open("GET", urlStr, true);
            request.onreadystatechange = function () {
                if (request.readyState === XMLHttpRequest.DONE && (request.status === 200 || request.status === 0)) {
                    parseXspf(request.responseText);
                    showMessage("Playlist loaded.");
                }
            };
            request.send();
            sidebarOpen = false;
        } else if (lower.endsWith(".txt") || lower.endsWith(".srt") || lower.endsWith(".vtt")) {
            loadSubtitleFile(urlStr, true);
            sidebarOpen = false;
        } else {
            loadMediaFile(urlStr);
        }
    }

    // --- Background Rect ---
    Rectangle {
        anchors.fill: parent
        color: bgBaseColor
    }

    // --- Drag and Drop Area ---
    DropArea {
        id: globalDropArea
        anchors.fill: parent

        onDropped: drag => {
            if (drag.hasUrls) {
                for (var i = 0; i < drag.urls.length; ++i) {
                    handleDroppedFile(drag.urls[i]);
                }
            }
        }
    }

    // --- Drag and Drop Visual Overlay ---
    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(15, 23, 42, 0.85) // Slate-900 with high opacity
        z: 9999
        visible: globalDropArea.containsDrag

        Rectangle {
            anchors.fill: parent
            anchors.margins: 24
            color: "transparent"
            border.color: "#3b82f6"
            border.width: 2
            radius: 12
        }

        ColumnLayout {
            anchors.centerIn: parent
            spacing: 16

            Text {
                text: "📂"
                font.pixelSize: 48
                Layout.alignment: Qt.AlignHCenter
            }
            Text {
                text: "Drop files here to load"
                color: "white"
                font.pixelSize: 20
                font.bold: true
                Layout.alignment: Qt.AlignHCenter
            }
            Text {
                text: "Supports Media (.mp4, .webm, .mp3, .wav), Playlists (.xspf), and Lyrics (.txt)"
                color: "#94a3b8"
                font.pixelSize: 13
                Layout.alignment: Qt.AlignHCenter
            }
        }
    }

    // --- Main Layout ---
    PlayerLayout {
        id: playerLayout
        app: window
    }

    // 3. Sliding Menu Drawer (For Loaders)
    FileDrawer {
        id: sidebarDrawer
        app: window
    }

    // Overlay (anchored next to the leftPanel so the vertical sidebar stays bright and matches the drawer)
    Rectangle {
        anchors.left: parent.left
        anchors.leftMargin: playerLayout.sidebarWidth
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        color: "#90000000"
        z: 999
        visible: sidebarOpen

        MouseArea {
            anchors.fill: parent
            onClicked: sidebarOpen = false
        }
    }

    // About Modal
    AboutDialog {
        id: aboutModal
        app: window
    }

    // --- Helper Functions ---
    function formatTime(seconds) {
        return MediaUtils.formatTime(seconds);
    }

    function parseSRT(text) {
        return SubtitleUtils.parseSRT(text);
    }

    function getChapterAtTime(seconds) {
        if (!mediaChapters || mediaChapters.length === 0)
            return "";
        var activeTitle = "";
        for (var i = 0; i < mediaChapters.length; i++) {
            if (seconds >= mediaChapters[i].time) {
                activeTitle = mediaChapters[i].title;
            }
        }
        return activeTitle;
    }

    function isSubtitleGenerationRequestCurrent(request) {
        return subtitleJobs.isSubtitleGenerationRequestCurrent(request);
    }

    function generateSubtitlesForCurrentTrack() {
        subtitleJobs.generateSubtitlesForCurrentTrack();
    }

    // Detects all subtitle options for the current track:
    // - External .srt / .vtt files beside the media (via C++ directory scan)
    // - Embedded subtitle tracks reported by Qt MediaPlayer
    // Called from player.onTracksChanged (once per file, guarded by subtitleDetectionDone).
    function detectSubtitles() {
        if (currentTrackIndex < 0 || playlist.length === 0)
            return;
        var mediaUrl = playlist[currentTrackIndex].url.toString();

        var allOptions = [];

        // 1. External subtitle files in the same directory
        var externalSubs = controller.findSubtitleFiles(mediaUrl);
        for (var i = 0; i < externalSubs.length; i++) {
            allOptions.push({
                label: externalSubs[i].label,
                url: externalSubs[i].url,
                isEmbedded: false,
                embeddedIndex: -1
            });
        }

        // 2. Embedded subtitle tracks from Qt MediaPlayer
        for (var j = 0; j < player.subtitleTracks.length; j++) {
            var track = player.subtitleTracks[j];
            var lang = track.value(MediaMetaData.Language) || "";
            var title = track.value(MediaMetaData.Title) || "";
            var lbl = lang !== "" ? lang : (title !== "" ? title : ("Track " + (j + 1)));
            allOptions.push({
                label: "\uD83C\uDF9E\uFE0F " + lbl // Prefix marks embedded tracks
                ,
                url: "",
                isEmbedded: true,
                embeddedIndex: j
            });
        }

        availableSubtitles = allOptions;

        if (allOptions.length === 0) {
            // Nothing found — leave subtitles off
        } else if (allOptions.length === 1 && !allOptions[0].isEmbedded) {
            // Single external file: auto-load silently (preserves existing behaviour)
            loadSubtitleFile(allOptions[0].url);
        } else if (allOptions.length >= 1) {
            // Multiple options or any embedded track: show the picker
            subtitlePickerVisible = true;
        }
    }

    function invalidateSubtitleFiles() {
        subtitleFiles.invalidate();
    }
    function clearSubtitles() {
        subtitleFiles.clear();
    }
    function selectEmbeddedSubtitle(trackIndex) {
        subtitleFiles.selectEmbedded(trackIndex);
    }
    function loadSubtitleFile(fileUrl, showTranscript) {
        subtitleFiles.load(fileUrl, undefined, showTranscript);
    }
    function cancelSubtitleGeneration() {
        subtitleJobs.cancelGeneration();
    }

    // Parses WebVTT into the same [{start, end, text}] format as parseSRT.
    function parseVTT(text) {
        return SubtitleUtils.parseVTT(text);
    }

    function loadTrack(index) {
        playbackSession.loadTrack(index);
    }

    function loadMediaFile(fileUrl) {
        playbackSession.loadMediaFile(fileUrl);
    }

    function syncPlaylistForFolderToggle() {
        playbackSession.syncPlaylistForFolderToggle();
    }

    function resetTheme() {
        bgBaseColor = "#0f172a";
        containerColor = "#1e293b";
        accentColor = "#3b82f6";
    }

    function parseXspf(xmlString) {
        var tracks = [];
        var trackRegex = /<track>([\s\S]*?)<\/track>/g;
        var locationRegex = /<location>([\s\S]*?)<\/location>/;
        var titleRegex = /<title>([\s\S]*?)<\/title>/;
        var match;
        while ((match = trackRegex.exec(xmlString)) !== null) {
            var trackXml = match[1];
            var locMatch = locationRegex.exec(trackXml);
            var titleMatch = titleRegex.exec(trackXml);
            if (locMatch) {
                var location = locMatch[1].trim();
                var title = titleMatch ? titleMatch[1].trim() : location.substring(location.lastIndexOf('/') + 1);
                tracks.push({
                    url: location,
                    title: title
                });
            }
        }

        if (tracks.length > 0) {
            playlist = tracks;
            currentTrackIndex = 0;
            loadTrack(0);
            showMessage("Playlist loaded with " + tracks.length + " tracks.");
            currentView = "playlist";
        } else {
            showMessage("Error: No valid tracks found in XSPF.");
        }
    }

    function shiftSubtitles(seconds) {
        var newChunks = [];
        for (var i = 0; i < subtitleChunks.length; i++) {
            var chunk = subtitleChunks[i];
            newChunks.push({
                start: Math.max(0, chunk.start + seconds),
                end: Math.max(0, chunk.end + seconds),
                text: chunk.text
            });
        }
        subtitleChunks = newChunks;
        showMessage("Subtitles shifted by " + (seconds > 0 ? "+" : "") + seconds + "s");
    }

    function formatSRTContent() {
        return SubtitleUtils.formatSRT(subtitleChunks);
    }

    function formatVTTContent() {
        return SubtitleUtils.formatVTT(subtitleChunks);
    }

    function formatTXTContent() {
        return SubtitleUtils.formatTXT(subtitleChunks, currentLyrics);
    }

    // ─── Subtitle Track Picker ──────────────────────────────────────────────────
    SubtitlePicker {
        id: subtitlePickerPopup
        app: window
    }

    // ─── Chapters List Popup ──────────────────────────────────────────────────
    ChaptersPopup {
        id: chaptersPopup
        app: window
    }
}
