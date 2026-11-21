import QtQuick
import QtQuick.Window
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Dialogs
import QtMultimedia
import QtCore
import MAPLPlayerNative
import "components"
import "dialogs"
import "logic"
import "logic/MediaUtils.js" as MediaUtils
import "logic/SubtitleUtils.js" as SubtitleUtils

ApplicationWindow {
    id: window
    width: 1120
    height: 720
    minimumWidth: 640
    minimumHeight: 420
    visible: true
    title: currentTrackIndex >= 0 && playlist[currentTrackIndex] ? playlist[currentTrackIndex].title + " — MAPL" : "MAPL"
    font.family: "Inter, Noto Sans Sinhala, Noto Sans, sans-serif"

    palette.window: "#18222d"
    palette.base: "#121c26"
    palette.alternateBase: "#202d3a"
    palette.text: "#edf3fa"
    palette.windowText: "#edf3fa"
    palette.button: "#293947"
    palette.buttonText: "#edf3fa"
    palette.highlight: "#355c79"
    palette.highlightedText: "#ffffff"
    palette.mid: "#465b6e"
    palette.dark: "#101820"
    palette.light: "#52687c"
    font.pixelSize: 13

    property bool desktopControlsEnabled: true
    property bool layoutPersistenceEnabled: true
    property alias desktopLayout: layoutState
    property alias backgroundTasks: tasks
    readonly property bool backgroundTasksOpen: tasksPopup.visible
    readonly property bool textInputFocused: activeFocusItem instanceof TextInput || activeFocusItem instanceof TextEdit
    readonly property bool modalDialogOpen: playbackOptionsPopup.visible || resumeDialog.visible || modelManager.visible || recentFilesMenu.visible || aboutModal.visible || subtitlePickerPopup.visible || chaptersPopup.visible || fileDialogs.dialogOpen || subtitleSettings.visible || generatorDialog.visible || tasksPopup.visible || playerLayout.menuOpen
    onModalDialogOpenChanged: {
        if (modalDialogOpen) {
            controlsVisible = true;
            fullscreenCursorVisible = true;
        }
    }
    property alias playbackOptions: playbackOptionsBackend
    property alias desktopControls: mpris
    property bool loopPlaylist: controller.loadLoop()
    property alias playbackHistory: history
    property alias playbackMemory: memory
    readonly property bool hasLoadedTrack: playbackSession.hasLoadedTrack
    readonly property string playbackStateLabel: playbackSession.playbackStateLabel
    readonly property int nextTrackIndex: playbackSession.nextTrackIndex
    readonly property int previousTrackIndex: playbackSession.previousTrackIndex
    readonly property bool resumePending: memory.pendingResume !== null
    readonly property string resumeTitle: memory.pendingResume !== null ? memory.pendingResume.title : ""
    readonly property real resumePositionMs: memory.pendingResume !== null ? memory.pendingResume.position : 0
    property alias mediaPlayer: player
    property alias playerController: controller
    property alias subtitleGenerator: subGenerator
    property alias modelDownloader: modelDownloaderBackend
    property alias audioLevels: audioLevelBackend
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

    DesktopLayout { id: layoutState; app: window }
    BackgroundTasks { id: tasks; app: window }
    BackgroundTasksPopup { id: tasksPopup; app: window }
    function openBackgroundTasks() {
        generatorDialog.close();
        tasksPopup.open();
    }

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
    AudioLevelMeter {
        id: audioLevelBackend
        player: playbackOptionsBackend.audiblePlayer
        enabled: playerLayout.audioLevelIndicator.visible && !window.reduceMotion && window.visible
    }
    function openPlaybackOptions() {
        playbackOptionsPopup.open();
    }
    function resetAudioDelay() {
        playbackOptionsBackend.resetAudioDelay();
    }
    function seekTo(position) {
        audioLevelBackend.clear();
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
        // Alias changes are written on a delay. Save the final subtitle
        // appearance explicitly before syncing, even after a quick adjustment.
        desktopUiSettings.setValue("subtitleFontSize", subtitleFontSize);
        desktopUiSettings.setValue("subtitleTextColor", subtitleTextColor);
        desktopUiSettings.setValue("subtitleBgOpacity", subtitleBgOpacity);
        desktopUiSettings.setValue("subtitleBottomMarginPercent", subtitleBottomMarginPercent);
        desktopUiSettings.sync();
        layoutState.save();
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
        fullscreenCursorVisible = true;
        if (fullscreenVideo && fullscreenControlsCanHide) {
            controlsDismissTimer.stop();
            controlsHideTimer.restart();
            fullscreenCursorTimer.restart();
        }
    }
    function handleFullscreenPointer(nearBottom) {
        if (!fullscreenVideo) return;
        fullscreenCursorVisible = true;
        if (!fullscreenControlsCanHide) return;
        fullscreenCursorTimer.restart();
        if (nearBottom) {
            controlsVisible = true;
            restartControlsHideTimer();
        } else {
            hideFullscreenControlsSoon();
        }
    }
    function hideFullscreenControlsSoon() {
        if (fullscreenVideo && controlsVisible && fullscreenControlsCanHide && !controlsDismissTimer.running)
            controlsDismissTimer.start();
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
    onSubtitleChunksChanged: updateActiveSubtitles()
    property string activeSubtitleText: ""
    property int subtitleFontSize: 18
    onSubtitleFontSizeChanged: subtitleFontSize = Math.max(12, Math.min(36, subtitleFontSize))
    property string subtitleTextColor: "#ffffff"
    property real subtitleBgOpacity: 0.55
    property int subtitleBottomMarginPercent: 12
    onSubtitleBottomMarginPercentChanged: subtitleBottomMarginPercent = Math.max(5, Math.min(25, subtitleBottomMarginPercent))
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

    // currentView remains compatible with file-loading and full-view commands.
    // mediaView is independent, so opening a side panel never replaces the video.
    property string currentView: "audio"
    property string mediaView: "audio"
    property string panelView: ""
    property bool panelExpanded: false
    property bool sidebarOpen: false
    property bool sidebarExpanded: false
    onCurrentViewChanged: {
        if (currentView === "audio" || currentView === "video") {
            mediaView = currentView;
            panelExpanded = false;
        } else if (currentView === "lyrics" || currentView === "playlist") {
            panelView = currentView;
            panelExpanded = true;
        }
        controlsVisible = true;
    }
    function showMediaView(view) {
        currentView = view;
        mediaView = view;
        panelExpanded = false;
    }
    function togglePanel(view) {
        if (panelView === view) {
            closePanel();
        } else {
            currentView = mediaView;
            panelExpanded = false;
            panelView = view;
        }
    }
    function closePanel() {
        currentView = mediaView;
        panelExpanded = false;
        panelView = "";
    }
    function setPanelExpanded(expanded) {
        if (expanded && panelView !== "") currentView = panelView;
        else currentView = mediaView;
        panelExpanded = expanded && panelView !== "";
    }
    function openSubtitleSettings() { subtitleSettings.open(); }
    function openSubtitleGenerator() { generatorDialog.open(); }
    function captureCurrentThumbnail() {
        if (currentTrackIndex >= 0 && player.hasVideo && controller.hasVideoFrame)
            controller.captureThumbnail(playlist[currentTrackIndex].url);
    }

    property string currentThumbnailDataUrl: ""
    property string currentTimelinePreviewSheet: ""
    property bool controlsVisible: true
    property bool fullscreenCursorVisible: true
    property int fullscreenRestoreVisibility: Window.Windowed
    readonly property bool fullscreenVideo: visibility === Window.FullScreen && mediaView === "video" && !panelExpanded
    readonly property bool fullscreenControlsCanHide: !playerLayout.controlsHovered && !playerLayout.controlsInteracting && !modalDialogOpen
    onFullscreenControlsCanHideChanged: {
        if (fullscreenControlsCanHide) hideFullscreenControlsSoon();
        else controlsDismissTimer.stop();
    }
    onFullscreenVideoChanged: {
        controlsVisible = true;
        fullscreenCursorVisible = true;
    }

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
        layoutState.restore();
    }

    onVisibilityChanged: {
        // Track ordinary window states even when fullscreen is requested by
        // the window manager. Minimize/hide must not replace the restore state.
        if (window.visibility === Window.Windowed || window.visibility === Window.Maximized)
            fullscreenRestoreVisibility = window.visibility;
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
            leaveFullscreen();
        } else {
            window.visibility = Window.FullScreen;
        }
    }

    function leaveFullscreen() {
        if (window.visibility === Window.FullScreen)
            window.visibility = fullscreenRestoreVisibility;
    }

    Timer {
        id: controlsHideTimer
        interval: 1200
        running: window.fullscreenVideo && window.controlsVisible && window.fullscreenControlsCanHide
        repeat: false
        onTriggered: {
            if (window.fullscreenVideo && window.fullscreenControlsCanHide)
                window.controlsVisible = false;
        }
    }
    Timer {
        id: controlsDismissTimer
        interval: 180
        onTriggered: {
            if (window.fullscreenVideo && window.fullscreenControlsCanHide)
                window.controlsVisible = false;
        }
    }
    Timer {
        id: fullscreenCursorTimer
        interval: 1200
        running: window.fullscreenVideo && window.fullscreenCursorVisible && window.fullscreenControlsCanHide
        onTriggered: window.fullscreenCursorVisible = false
    }

    Shortcut {
        sequence: "Esc"
        enabled: window.visibility === Window.FullScreen && !window.modalDialogOpen
        onActivated: leaveFullscreen()
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
        // A held key must not immediately resume after pausing.
        autoRepeat: false
        enabled: !window.modalDialogOpen && !window.textInputFocused
        onActivated: togglePlayPause()
    }

    Shortcut {
        sequence: "f"
        enabled: !window.modalDialogOpen && !window.textInputFocused
        onActivated: toggleFullscreen()
    }

    Shortcut {
        sequence: "Right"
        enabled: !window.modalDialogOpen && !window.textInputFocused
        onActivated: seekRelative(5)
    }

    Shortcut {
        sequence: "Left"
        enabled: !window.modalDialogOpen && !window.textInputFocused
        onActivated: seekRelative(-5)
    }

    Shortcut {
        sequence: "Up"
        enabled: !window.modalDialogOpen && !window.textInputFocused
        onActivated: changeVolume(5)
    }

    Shortcut {
        sequence: "Down"
        enabled: !window.modalDialogOpen && !window.textInputFocused
        onActivated: changeVolume(-5)
    }

    Shortcut {
        sequence: "m"
        enabled: !window.modalDialogOpen && !window.textInputFocused
        onActivated: toggleMute()
    }

    Shortcut {
        sequence: "n"
        enabled: !window.modalDialogOpen && !window.textInputFocused
        onActivated: playNext()
    }

    Shortcut {
        sequence: "p"
        enabled: !window.modalDialogOpen && !window.textInputFocused
        onActivated: playPrev()
    }

    // Only existing chrome receives a small, smoothly changing ambient tint.
    property color bgBaseColor: "#151e28"
    property color containerColor: "#202c38"
    property color accentColor: "#86b7ec"
    property color ambientSourceColor: "#526a85"
    property bool ambientEnabled: true
    property real ambientStrength: 0.12
    property bool visualizerEnabled: true
    property bool reduceMotion: false
    onAmbientStrengthChanged: ambientStrength = Math.max(0, Math.min(0.25, ambientStrength))
    property color chromeColor: {
        var base = Qt.color("#1b2835");
        var amount = ambientEnabled && !reduceMotion ? Math.max(0, Math.min(0.25, ambientStrength)) : 0;
        return Qt.rgba(base.r * (1 - amount) + ambientSourceColor.r * amount,
                       base.g * (1 - amount) + ambientSourceColor.g * amount,
                       base.b * (1 - amount) + ambientSourceColor.b * amount, 1);
    }
    Behavior on chromeColor { ColorAnimation { duration: window.reduceMotion ? 0 : 700; easing.type: Easing.InOutQuad } }
    Settings {
        id: desktopUiSettings
        category: "DesktopUI"
        property alias ambientEnabled: window.ambientEnabled
        property alias ambientStrength: window.ambientStrength
        property alias visualizerEnabled: window.visualizerEnabled
        property alias reduceMotion: window.reduceMotion
        property alias subtitleFontSize: window.subtitleFontSize
        property alias subtitleTextColor: window.subtitleTextColor
        property alias subtitleBgOpacity: window.subtitleBgOpacity
        property alias subtitleBottomMarginPercent: window.subtitleBottomMarginPercent
    }

    // --- C++ Backend Elements ---
    PlayerController {
        id: controller
        videoSink: window.videoOutput.videoSink

        onBackgroundColorChanged: hexColor => ambientSourceColor = hexColor

        onThumbnailCaptured: (trackUrl, base64) => {
            currentThumbnailDataUrl = "data:image/png;base64," + base64;
        }
        onThumbnailSaveError: message => window.showMessage(message)

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

            updateActiveSubtitles();
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
                if (request.readyState === XMLHttpRequest.DONE) {
                    if (request.status === 200 || (request.status === 0 && request.responseText !== ""))
                        parseXspf(request.responseText, urlStr);
                    else
                        showMessage("Error: Could not read XSPF playlist.");
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
        color: Qt.rgba(0.06, 0.09, 0.13, 0.90) // Slate-900 with high opacity
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
                text: "MAPL"
                font.pixelSize: 22
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

    SubtitleSettingsPopup { id: subtitleSettings; app: window }
    SubtitleGenerationPopup { id: generatorDialog; app: window }

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

    function updateActiveSubtitles() {
        // The initial subtitle property can change before these objects exist.
        if (!player || !playerLayout)
            return;
        var posSec = player.position / 1000.0;
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
        // Keep long title/lyric cues above shorter dialogue cues.
        activeChunks.sort(function (a, b) {
            return (b.end - b.start) - (a.end - a.start);
        });
        var joinedText = "";
        for (var k = 0; k < activeChunks.length; k++) {
            if (k > 0)
                joinedText += "\n";
            joinedText += activeChunks[k].text;
        }
        var activeIdx = activeChunks.length > 0 ? activeChunks[activeChunks.length - 1].index : -1;
        activeSubtitleText = joinedText;
        currentActiveSubtitleIndex = activeIdx;
        // Keep highlights current when cues change, without interrupting search.
        var list = transcriptListView;
        if (list && list.visible && transcriptSearchQuery.trim() === "" && list.currentIndex !== activeIdx) {
            list.currentIndex = activeIdx;
            if (activeIdx >= 0)
                list.positionViewAtIndex(activeIdx, ListView.Center);
        }
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
        ambientSourceColor = "#526a85";
    }

    function parseXspf(xmlString, playlistUrl) {
        var parsed = controller.parseXspf(xmlString, playlistUrl === undefined ? "" : playlistUrl.toString());
        if (parsed.error !== "") {
            showMessage("Error: " + parsed.error);
            return;
        }
        var tracks = parsed.tracks;
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
