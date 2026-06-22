import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Dialogs
import QtMultimedia
import MAPLPlayerNative

ApplicationWindow {
    id: window
    width: 850
    height: 700
    minimumWidth: 600
    minimumHeight: 600
    visible: true
    title: "MAPL Player - Native C++"
    font.family: "Inter"

    // --- State Properties ---
    property var playlist: []
    property int currentTrackIndex: -1
    property string currentLyrics: ""
    property var subtitleChunks: []
    property string activeSubtitleText: ""
    property int subtitleFontSize: 18
    property string subtitleTextColor: "#ffffff"
    property real subtitleBgOpacity: 0.55
    property string transcriptSearchQuery: ""
    property int currentActiveSubtitleIndex: -1

    property var filteredSubtitleChunks: {
        if (!subtitleChunks) return [];
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
    property string currentThumbnailDataUrl: ""
    property string currentTimelinePreviewSheet: ""
    property bool controlsVisible: true

    onVisibilityChanged: {
        if (window.visibility !== Window.FullScreen) {
            controlsVisible = true
        } else {
            sidebarOpen = false
        }
    }

    function toggleFullscreen() {
        if (window.visibility === Window.FullScreen) {
            window.visibility = Window.Windowed
        } else {
            window.visibility = Window.FullScreen
        }
    }

    Timer {
        id: controlsHideTimer
        interval: 3000
        running: window.visibility === Window.FullScreen && !controlsHoverHandler.hovered
        repeat: false
        onTriggered: {
            controlsVisible = false
        }
    }

    Shortcut {
        sequence: "Esc"
        enabled: window.visibility === Window.FullScreen
        onActivated: {
            window.visibility = Window.Windowed
        }
    }

    // --- Mute & Notification Properties & Helpers ---
    property bool isMuted: false

    Timer {
        id: messageTimer
        interval: 3000
        repeat: false
        onTriggered: messageArea.text = ""
    }

    function showMessage(msg) {
        messageArea.text = msg
        messageTimer.restart()
    }

    function togglePlayPause() {
        if (currentTrackIndex === -1 && playlist.length > 0) {
            loadTrack(0)
            player.play()
        } else if (player.playbackState === MediaPlayer.PlayingState) {
            player.pause()
        } else {
            player.play()
        }
    }

    function seekRelative(offsetSeconds) {
        if (player.duration > 0) {
            var newPos = player.position + (offsetSeconds * 1000)
            player.position = Math.max(0, Math.min(player.duration, newPos))
            showMessage((offsetSeconds > 0 ? "Forward " : "Backward ") + Math.abs(offsetSeconds) + "s")
        }
    }

    function changeVolume(delta) {
        var newVol = Math.max(0, Math.min(100, volumeSlider.value + delta))
        volumeSlider.value = newVol
        showMessage("Volume: " + Math.round(newVol) + "%")
    }

    function toggleMute() {
        isMuted = !isMuted
        showMessage(isMuted ? "Muted" : "Unmuted")
    }

    function playNext() {
        if (playlist.length > 0) {
            var nextIndex = (currentTrackIndex + 1) % playlist.length
            loadTrack(nextIndex)
            player.play()
            showMessage("Next: " + playlist[nextIndex].title)
        }
    }

    function playPrev() {
        if (playlist.length > 0) {
            var prevIndex = (currentTrackIndex - 1 + playlist.length) % playlist.length
            loadTrack(prevIndex)
            player.play()
            showMessage("Previous: " + playlist[prevIndex].title)
        }
    }

    // --- Keyboard Shortcuts ---
    Shortcut {
        sequence: "Space"
        onActivated: togglePlayPause()
    }

    Shortcut {
        sequence: "f"
        onActivated: toggleFullscreen()
    }

    Shortcut {
        sequence: "Right"
        onActivated: seekRelative(5)
    }

    Shortcut {
        sequence: "Left"
        onActivated: seekRelative(-5)
    }

    Shortcut {
        sequence: "Up"
        onActivated: changeVolume(5)
    }

    Shortcut {
        sequence: "Down"
        onActivated: changeVolume(-5)
    }

    Shortcut {
        sequence: "m"
        onActivated: toggleMute()
    }

    Shortcut {
        sequence: "n"
        onActivated: playNext()
    }

    Shortcut {
        sequence: "p"
        onActivated: playPrev()
    }

    // Dynamic background colors updated from C++ PlayerController
    property color bgBaseColor: "#0f172a"      // Slate-900 (Default)
    property color containerColor: "#1e293b"   // Slate-800 (Default)
    property color accentColor: "#3b82f6"      // Blue-500 (Default)

    // Custom background transitions
    Behavior on bgBaseColor {
        ColorAnimation { duration: 600; easing.type: Easing.InOutQuad }
    }
    Behavior on containerColor {
        ColorAnimation { duration: 600; easing.type: Easing.InOutQuad }
    }

    // --- C++ Backend Elements ---
    PlayerController {
        id: controller
        videoSink: videoOutput.videoSink
        
        onBackgroundColorChanged: (hexColor) => {
            var c = Qt.color(hexColor)
            // Calculate perceived luminance (0.0 to 1.0)
            var luminance = 0.299 * c.r + 0.587 * c.g + 0.114 * c.b
            
            // Tint and heavily darken the background base color based on luminance
            // If the source color is extremely light, we darken it much more aggressively
            var bgDarken = luminance > 0.7 ? 5.5 : (luminance > 0.5 ? 4.5 : 3.0)
            bgBaseColor = Qt.darker(hexColor, bgDarken)
            
            // Styled panel background: semi-transparent, very dark tint of the color
            // This guarantees high contrast for white text/labels under any dynamic video/album art
            var panelDarken = luminance > 0.7 ? 4.5 : (luminance > 0.5 ? 3.5 : 2.2)
            var darkTint = Qt.darker(hexColor, panelDarken)
            containerColor = Qt.rgba(darkTint.r, darkTint.g, darkTint.b, 0.75)
            
            accentColor = hexColor
        }
        
        onThumbnailCaptured: (trackUrl, base64) => {
            currentThumbnailDataUrl = "data:image/png;base64," + base64
        }

        onTimelinePreviewsReady: (trackUrl, spriteSheetPath) => {
            console.log("[DEBUG] timelinePreviewsReady signal received. trackUrl:", trackUrl, "spriteSheetPath:", spriteSheetPath)
            var currentSource = player.source.toString()
            console.log("[DEBUG] Current player source:", currentSource)
            if (currentSource === trackUrl || currentSource.indexOf(trackUrl) !== -1 || trackUrl.indexOf(currentSource) !== -1) {
                currentTimelinePreviewSheet = "file://" + spriteSheetPath
                console.log("[DEBUG] Loaded timeline preview sheet:", currentTimelinePreviewSheet)
            } else {
                console.log("[DEBUG] Warning: Track URL mismatch!")
            }
        }
    }

    SubtitleGenerator {
        id: subGenerator
        
        onProgressChanged: (progress) => {
            transcriptionProgress.value = progress
        }
        
        onSubtitlesReady: (chunks) => {
            subtitleChunks = chunks
            transcriptionProgress.value = 100
            currentView = "lyrics"
            showMessage("Subtitles generated successfully!")
        }
        
        onErrorOccurred: (errorMsg) => {
            showMessage("Error: " + errorMsg)
        }
    }

    ModelDownloader {
        id: modelDownloader
        
        onProgressChanged: (progress) => {
            downloadProgressBar.value = progress
        }
        
        onDownloadFinished: (filePath) => {
            showMessage("Model downloaded successfully! Ready to transcribe.")
            var selected = modelSelector.currentIndex === 0 ? "tiny" : "base"
            var lang = languageSelector.currentText
            var translate = taskSelector.currentIndex === 1
            subGenerator.generateSubtitles(playlist[currentTrackIndex].url, filePath, lang, translate)
        }
        
        onDownloadError: (errorMsg) => {
            showMessage("Download Error: " + errorMsg)
        }
    }

    // --- Native Media Player ---
    MediaPlayer {
        id: player
        audioOutput: AudioOutput {
            volume: volumeSlider.value / 100.0
            muted: isMuted
        }
        videoOutput: videoOutput
        
        onErrorOccurred: (error, errorString) => {
            showMessage("Media Error: " + errorString)
        }

        onDurationChanged: {
            console.log("[DEBUG] MediaPlayer duration changed to:", duration, "source:", player.source.toString())
            if (duration > 0 && player.source.toString() !== "") {
                var lowerUrl = player.source.toString().toLowerCase()
                var isVideo = lowerUrl.endsWith(".mp4") || lowerUrl.endsWith(".mkv") || 
                              lowerUrl.endsWith(".webm") || lowerUrl.endsWith(".avi") || 
                              lowerUrl.endsWith(".mov") || lowerUrl.endsWith(".flv") || 
                              lowerUrl.endsWith(".m4v") || lowerUrl.endsWith(".ogv") || 
                              lowerUrl.endsWith(".ts")
                if (isVideo) {
                    console.log("[DEBUG] Generating timeline previews for:", player.source.toString())
                    controller.generateTimelinePreviews(player.source.toString(), duration / 1000.0)
                } else {
                    console.log("[DEBUG] Track is not a video file.")
                }
            }
        }

        onPositionChanged: {
            if (!seekSlider.pressed && player.duration > 0) {
                seekSlider.value = (player.position / player.duration) * 100
            }
            
            // Sync subtitles overlay & list view highlight
            if (subtitleChunks.length > 0) {
                var posSec = player.position / 1000.0
                var activeIdx = -1
                for (var i = 0; i < subtitleChunks.length; i++) {
                    var chunk = subtitleChunks[i]
                    if (posSec >= chunk.start && posSec <= chunk.end) {
                        activeSubtitleText = chunk.text
                        activeIdx = i
                        break
                    }
                }
                
                if (activeIdx !== -1) {
                    currentActiveSubtitleIndex = activeIdx
                    // Only auto-scroll the list when not searching, so the user can browse freely
                    if (transcriptListView.visible && transcriptSearchQuery.trim() === "") {
                        if (transcriptListView.currentIndex !== activeIdx) {
                            transcriptListView.currentIndex = activeIdx
                            transcriptListView.positionViewAtIndex(activeIdx, ListView.Center)
                        }
                    }
                } else {
                    activeSubtitleText = ""
                    currentActiveSubtitleIndex = -1
                }
            }
        }

        onPlaybackStateChanged: {
            if (player.playbackState === MediaPlayer.StoppedState && playlist.length > 0) {
                if (controller.loadLoop()) {
                    loadTrack((currentTrackIndex + 1) % playlist.length)
                    player.play()
                } else if (currentTrackIndex < playlist.length - 1) {
                    loadTrack(currentTrackIndex + 1)
                    player.play()
                } else {
                    currentTrackIndex = -1
                    resetTheme()
                }
            }
        }
    }

    // --- File Dialogs ---
    FileDialog {
        id: mediaFileDialog
        title: "Select Video/Audio File"
        nameFilters: ["Media Files (*.mp4 *.webm *.mp3 *.wav *.ogg)"]
        onAccepted: {
            var fileUrl = selectedFile.toString()
            var fileName = controller.getCleanFileName(fileUrl)
            playlist = [{ url: fileUrl, title: fileName }]
            currentTrackIndex = 0
            loadTrack(0)
            player.play()
            sidebarOpen = false
        }
    }

    FileDialog {
        id: xspfFileDialog
        title: "Select XSPF Playlist"
        nameFilters: ["XSPF Playlists (*.xspf)"]
        onAccepted: {
            var fileUrl = selectedFile.toString()
            var request = new XMLHttpRequest()
            request.open("GET", fileUrl, true)
            request.onreadystatechange = function() {
                if (request.readyState === XMLHttpRequest.DONE && request.status === 200) {
                    parseXspf(request.responseText)
                }
            }
            request.send()
            sidebarOpen = false
        }
    }

    FileDialog {
        id: lyricsFileDialog
        title: "Select Lyrics or Subtitles File"
        nameFilters: ["Lyrics/Subtitles Files (*.txt *.srt)"]
        onAccepted: {
            var fileUrl = selectedFile.toString()
            var request = new XMLHttpRequest()
            request.open("GET", fileUrl, true)
            request.onreadystatechange = function() {
                if (request.readyState === XMLHttpRequest.DONE && (request.status === 200 || request.status === 0)) {
                    var lower = fileUrl.toLowerCase()
                    if (lower.endsWith(".srt")) {
                        var chunks = parseSRT(request.responseText)
                        if (chunks.length > 0) {
                            subtitleChunks = chunks
                            currentLyrics = ""
                            currentView = "lyrics"
                            showMessage("Subtitles loaded.")
                        } else {
                            showMessage("Failed to parse subtitles file.")
                        }
                    } else {
                        currentLyrics = request.responseText
                        subtitleChunks = []
                        currentView = "lyrics"
                        showMessage("Lyrics loaded.")
                    }
                }
            }
            request.send()
            sidebarOpen = false
        }
    }

    // Tracks the pending export format ("srt" | "vtt" | "txt")
    property string pendingExportFormat: "srt"

    FileDialog {
        id: exportFileDialog
        title: "Export Subtitles As…"
        fileMode: FileDialog.SaveFile
        nameFilters: {
            if (pendingExportFormat === "srt")       return ["SubRip Subtitles (*.srt)"]
            else if (pendingExportFormat === "vtt")  return ["WebVTT Subtitles (*.vtt)"]
            else                                     return ["Plain Text (*.txt)"]
        }
        onAccepted: {
            var destPath = selectedFile.toString()
            var content = ""
            if (pendingExportFormat === "srt")       content = formatSRTContent()
            else if (pendingExportFormat === "vtt")  content = formatVTTContent()
            else                                     content = formatTXTContent()

            var ok = controller.writeTextToFile(destPath, content)
            showMessage(ok ? "Exported " + pendingExportFormat.toUpperCase() + " successfully." : "Export failed.")
        }
    }

    // --- Drag and Drop File Support Helper ---
    function handleDroppedFile(fileUrl) {
        var urlStr = fileUrl.toString();
        var lower = urlStr.toLowerCase();
        
        if (lower.endsWith(".xspf")) {
            var request = new XMLHttpRequest()
            request.open("GET", urlStr, true)
            request.onreadystatechange = function() {
                if (request.readyState === XMLHttpRequest.DONE && (request.status === 200 || request.status === 0)) {
                    parseXspf(request.responseText)
                    showMessage("Playlist loaded.")
                }
            }
            request.send()
            sidebarOpen = false
        } 
        else if (lower.endsWith(".txt")) {
            var request = new XMLHttpRequest()
            request.open("GET", urlStr, true)
            request.onreadystatechange = function() {
                if (request.readyState === XMLHttpRequest.DONE && (request.status === 200 || request.status === 0)) {
                    currentLyrics = request.responseText
                    subtitleChunks = []
                    currentView = "lyrics"
                    showMessage("Lyrics loaded.")
                }
            }
            request.send()
            sidebarOpen = false
        } 
        else if (lower.endsWith(".srt")) {
            var request = new XMLHttpRequest()
            request.open("GET", urlStr, true)
            request.onreadystatechange = function() {
                if (request.readyState === XMLHttpRequest.DONE && (request.status === 200 || request.status === 0)) {
                    var chunks = parseSRT(request.responseText)
                    if (chunks.length > 0) {
                        subtitleChunks = chunks
                        currentLyrics = ""
                        currentView = "lyrics"
                        showMessage("Subtitles loaded.")
                    } else {
                        showMessage("Failed to parse subtitles file.")
                    }
                }
            }
            request.send()
            sidebarOpen = false
        }
        else {
            var fileName = controller.getCleanFileName(urlStr)
            playlist = [{ url: urlStr, title: fileName }]
            currentTrackIndex = 0
            loadTrack(0)
            player.play()
            sidebarOpen = false
            showMessage("Media track loaded.")
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
        
        onDropped: (drag) => {
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
    RowLayout {
        anchors.fill: parent
        spacing: 0

        // 1. Left Fixed Vertical Panel (Always Visible)
        Rectangle {
            id: leftPanel
            Layout.fillHeight: true
            width: 155
            color: "#0f172a" // Deep Slate-900
            visible: window.visibility !== Window.FullScreen

            // Decorative separator border
            Rectangle {
                anchors.right: parent.right
                width: 1
                height: parent.height
                color: "#1e293b" // Slate-800
            }

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 14
                spacing: 14

                // Logo/Header Space
                Item {
                    Layout.preferredHeight: 50
                    Layout.fillWidth: true
                    RowLayout {
                        anchors.centerIn: parent
                        spacing: 8
                        Text {
                            text: "MAPL"
                            color: "white"
                            font.bold: true
                            font.pixelSize: 18
                            font.letterSpacing: 1.5
                        }
                    }
                }

                // Open Files Button (Modern flat look matching Electron)
                Button {
                    id: openFilesBtn
                    Layout.fillWidth: true
                    Layout.preferredHeight: 38
                    flat: true
                    padding: 0
                    scale: openFilesBtn.hovered ? 1.03 : 1.0
                    Behavior on scale { NumberAnimation { duration: 100 } }
                    background: Rectangle {
                        color: openFilesBtn.pressed ? "#3b82f6" : (openFilesBtn.hovered ? "#63b3ed" : "#4a5568")
                        radius: 12
                    }
                    contentItem: Text {
                        text: "📂 Open Files"
                        color: "white"
                        font.pixelSize: 13
                        font.bold: true
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                        elide: Text.ElideRight
                    }
                    onClicked: sidebarOpen = !sidebarOpen
                }

                Rectangle {
                    Layout.fillWidth: true
                    height: 1
                    color: "#1e293b"
                }

                Button {
                    id: audioTabBtn
                    Layout.fillWidth: true
                    Layout.preferredHeight: 38
                    flat: true
                    padding: 0
                    scale: audioTabBtn.hovered ? 1.02 : 1.0
                    Behavior on scale { NumberAnimation { duration: 100 } }
                    background: Rectangle {
                        color: currentView === "audio" ? "#1d4ed8" : (audioTabBtn.hovered ? "#4a5568" : "transparent")
                        radius: 12
                    }
                    contentItem: Text {
                        text: "🎵 Audio View"
                        color: currentView === "audio" ? "white" : (audioTabBtn.hovered ? "white" : "#d1d5db")
                        font.bold: currentView === "audio"
                        font.pixelSize: 13
                        horizontalAlignment: Text.AlignLeft
                        leftPadding: 12
                        verticalAlignment: Text.AlignVCenter
                        elide: Text.ElideRight
                    }
                    onClicked: currentView = "audio"
                }

                Button {
                    id: videoTabBtn
                    Layout.fillWidth: true
                    Layout.preferredHeight: 38
                    flat: true
                    enabled: currentTrackIndex !== -1
                    padding: 0
                    scale: videoTabBtn.hovered && videoTabBtn.enabled ? 1.02 : 1.0
                    Behavior on scale { NumberAnimation { duration: 100 } }
                    background: Rectangle {
                        color: currentView === "video" ? "#1d4ed8" : (videoTabBtn.hovered ? "#4a5568" : "transparent")
                        radius: 12
                        opacity: videoTabBtn.enabled ? 1.0 : 0.4
                    }
                    contentItem: Text {
                        text: "📺 Video View"
                        color: currentView === "video" ? "white" : (videoTabBtn.hovered ? "white" : "#d1d5db")
                        font.bold: currentView === "video"
                        font.pixelSize: 13
                        horizontalAlignment: Text.AlignLeft
                        leftPadding: 12
                        verticalAlignment: Text.AlignVCenter
                        elide: Text.ElideRight
                    }
                    onClicked: currentView = "video"
                }

                // View Tabs (Flat Sidebar Buttons matching Electron)
                Button {
                    id: lyricsTabBtn
                    Layout.fillWidth: true
                    Layout.preferredHeight: 38
                    flat: true
                    padding: 0
                    scale: lyricsTabBtn.hovered ? 1.02 : 1.0
                    Behavior on scale { NumberAnimation { duration: 100 } }
                    background: Rectangle {
                        color: currentView === "lyrics" ? "#1d4ed8" : (lyricsTabBtn.hovered ? "#4a5568" : "transparent")
                        radius: 12
                    }
                    contentItem: Text {
                        text: "📝 Lyrics & Subs"
                        color: currentView === "lyrics" ? "white" : (lyricsTabBtn.hovered ? "white" : "#d1d5db")
                        font.bold: currentView === "lyrics"
                        font.pixelSize: 13
                        horizontalAlignment: Text.AlignLeft
                        leftPadding: 12
                        verticalAlignment: Text.AlignVCenter
                        elide: Text.ElideRight
                    }
                    onClicked: currentView = "lyrics"
                }

                Button {
                    id: playlistTabBtn
                    Layout.fillWidth: true
                    Layout.preferredHeight: 38
                    flat: true
                    padding: 0
                    scale: playlistTabBtn.hovered ? 1.02 : 1.0
                    Behavior on scale { NumberAnimation { duration: 100 } }
                    background: Rectangle {
                        color: currentView === "playlist" ? "#1d4ed8" : (playlistTabBtn.hovered ? "#4a5568" : "transparent")
                        radius: 12
                    }
                    contentItem: Text {
                        text: "📋 Playlist"
                        color: currentView === "playlist" ? "white" : (playlistTabBtn.hovered ? "white" : "#d1d5db")
                        font.bold: currentView === "playlist"
                        font.pixelSize: 13
                        horizontalAlignment: Text.AlignLeft
                        leftPadding: 12
                        verticalAlignment: Text.AlignVCenter
                        elide: Text.ElideRight
                    }
                    onClicked: currentView = "playlist"
                }

                Button {
                    id: captureTabBtn
                    Layout.fillWidth: true
                    Layout.preferredHeight: 38
                    flat: true
                    padding: 0
                    visible: currentView === "video"
                    scale: captureTabBtn.hovered ? 1.02 : 1.0
                    Behavior on scale { NumberAnimation { duration: 100 } }
                    background: Rectangle {
                        color: captureTabBtn.hovered ? "#4a5568" : "transparent"
                        radius: 12
                    }
                    contentItem: Text {
                        text: "📷 Capture Cover"
                        color: captureTabBtn.hovered ? "white" : "#d1d5db"
                        font.pixelSize: 13
                        horizontalAlignment: Text.AlignLeft
                        leftPadding: 12
                        verticalAlignment: Text.AlignVCenter
                        elide: Text.ElideRight
                    }
                    onClicked: {
                        if (currentTrackIndex !== -1) {
                            controller.captureThumbnail(playlist[currentTrackIndex].url)
                            showMessage("Thumbnail frame captured!")
                        }
                    }
                }

                Item { Layout.fillHeight: true } // Spacer

                // About Button (matches panel view layout)
                Button {
                    id: aboutTabBtn
                    Layout.fillWidth: true
                    Layout.preferredHeight: 36
                    flat: true
                    padding: 0
                    background: Rectangle {
                        color: aboutTabBtn.hovered ? "#4a5568" : "transparent"
                        radius: 12
                    }
                    contentItem: Text {
                        text: "ℹ️ About Application"
                        color: aboutTabBtn.hovered ? "white" : "#d1d5db"
                        font.pixelSize: 12
                        horizontalAlignment: Text.AlignLeft
                        leftPadding: 12
                        verticalAlignment: Text.AlignVCenter
                        elide: Text.ElideRight
                    }
                    onClicked: aboutModal.open()
                }
            }
        }

        // 2. Main Content Wrapper
        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            // Global Title
            RowLayout {
                id: titleLayout
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.topMargin: 12
                anchors.leftMargin: (window.visibility === Window.FullScreen ? 0 : (currentView === "video" ? parent.width * 0.01 : parent.width * 0.03) + 8)
                spacing: 12
                z: 100
                visible: window.visibility !== Window.FullScreen

                Text {
                    text: currentView === "video" ? "📺" : (currentView === "lyrics" ? "📝" : "🎵")
                    font.pixelSize: 22
                }
                Text {
                    text: currentView === "video" ? "Video View" : (currentView === "lyrics" ? "Lyrics & Subtitles" : "Audio View")
                    color: "white"
                    font.pixelSize: 20
                    font.bold: true
                    font.letterSpacing: 0.5
                }
            }

            // Central Player Box Container
            Rectangle {
                id: centralPlayerBox
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top: parent.top
                anchors.topMargin: window.visibility === Window.FullScreen ? 0 : 48
                // Video mode: use most of the available space; other modes keep a little breathing room
                width: window.visibility === Window.FullScreen ? parent.width
                     : (currentView === "video" ? parent.width * 0.98 : parent.width * 0.94)
                height: window.visibility === Window.FullScreen ? parent.height
                      : (currentView === "video" ? parent.height - 64 : parent.height - 72)
                color: containerColor
                radius: window.visibility === Window.FullScreen ? 0 : 16
                border.color: window.visibility === Window.FullScreen ? "transparent" : "#334155"
                border.width: window.visibility === Window.FullScreen ? 0 : 1
                clip: true

                Behavior on color { ColorAnimation { duration: 400 } }
                Behavior on width  { NumberAnimation { duration: 250; easing.type: Easing.InOutQuad } }
                Behavior on height { NumberAnimation { duration: 250; easing.type: Easing.InOutQuad } }



                // Dynamic Views Container
                Item {
                    id: viewsContainer
                    anchors.top: parent.top
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.bottom: (currentView === "video") ? parent.bottom : controlsPanel.top
                    // Video mode: minimal inset so the video uses max space
                    anchors.margins: (currentView === "video") ? 0 : 24
                    anchors.topMargin: (currentView === "video") ? 0 : 36

                    // 2a. Audio View — full-area immersive layout
                    Item {
                        anchors.fill: parent
                        visible: currentView === "audio"

                        // Blurred ambient art backdrop
                        Image {
                            anchors.fill: parent
                            fillMode: Image.PreserveAspectCrop
                            visible: currentThumbnailDataUrl !== ""
                            source: currentThumbnailDataUrl
                            opacity: 0.12
                            layer.enabled: true
                            layer.effect: null  // no shader needed; opacity alone creates a subtle glow
                        }

                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: 32
                            spacing: 40

                            // ── Left: large cover art ───────────────────
                            Rectangle {
                                Layout.preferredWidth: Math.min(parent.height * 0.72, 340)
                                Layout.preferredHeight: Layout.preferredWidth
                                Layout.alignment: Qt.AlignVCenter
                                color: "#090d16"
                                radius: 20
                                border.color: accentColor !== "" ? accentColor : "#334155"
                                border.width: 2
                                clip: true

                                // Gradient placeholder
                                Rectangle {
                                    anchors.fill: parent
                                    visible: currentThumbnailDataUrl === ""
                                    gradient: Gradient {
                                        GradientStop { position: 0.0; color: "#1e293b" }
                                        GradientStop { position: 1.0; color: "#090d16" }
                                    }
                                }
                                Image {
                                    anchors.fill: parent
                                    fillMode: Image.PreserveAspectCrop
                                    visible: currentThumbnailDataUrl !== ""
                                    source: currentThumbnailDataUrl
                                }
                                Text {
                                    anchors.centerIn: parent
                                    text: "🎵"
                                    font.pixelSize: 96
                                    visible: currentThumbnailDataUrl === ""
                                    opacity: 0.4
                                }
                            }

                            // ── Right: metadata + equaliser bars ────────
                            ColumnLayout {
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                spacing: 12

                                Item { Layout.fillHeight: true }

                                Text {
                                    text: "NOW PLAYING"
                                    color: accentColor !== "" ? accentColor : "#3b82f6"
                                    font.pixelSize: 10
                                    font.bold: true
                                    font.letterSpacing: 3.0
                                }

                                Text {
                                    id: currentTrackTitleText
                                    text: currentTrackIndex >= 0 ? playlist[currentTrackIndex].title : "No file loaded"
                                    color: "white"
                                    font.pixelSize: 22
                                    font.bold: true
                                    wrapMode: Text.WordWrap
                                    Layout.fillWidth: true
                                    maximumLineCount: 2
                                    elide: Text.ElideRight
                                }

                                Text {
                                    text: currentTrackIndex >= 0 ? playlist[currentTrackIndex].artist || "Unknown Artist" : ""
                                    color: "#94a3b8"
                                    font.pixelSize: 14
                                    Layout.fillWidth: true
                                    elide: Text.ElideRight
                                    visible: text !== ""
                                }

                                // Mini equaliser visualiser (animated bars)
                                Row {
                                    spacing: 5
                                    Layout.topMargin: 4
                                    visible: player.playbackState === MediaPlayer.PlayingState

                                    Repeater {
                                        model: 9
                                        delegate: Rectangle {
                                            width: 5
                                            radius: 3
                                            color: accentColor !== "" ? accentColor : "#3b82f6"
                                            opacity: 0.85

                                            property real barPhase: index * 0.7
                                            property real barHeight: 8 + 24 * Math.abs(Math.sin((Date.now() / 400.0) + barPhase))
                                            height: barHeight
                                            anchors.bottom: parent ? parent.bottom : undefined

                                            NumberAnimation on barHeight {
                                                from: 8; to: 32
                                                duration: 350 + index * 60
                                                easing.type: Easing.SineCurve
                                                loops: Animation.Infinite
                                                running: player.playbackState === MediaPlayer.PlayingState
                                            }
                                        }
                                    }

                                    // Fixed height wrapper so bars anchor to bottom
                                    Item { width: 0; height: 32 }
                                }

                                Item { height: 10 }

                                // Live Subtitles Card
                                Rectangle {
                                    id: liveSubsCard
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 92
                                    color: Qt.rgba(15/255.0, 23/255.0, 42/255.0, 0.45)
                                    radius: 12
                                    border.color: accentColor !== "" ? Qt.rgba(Qt.color(accentColor).r, Qt.color(accentColor).g, Qt.color(accentColor).b, 0.25) : "#1e293b"
                                    border.width: 1

                                    MouseArea {
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        onClicked: currentView = "lyrics"
                                        cursorShape: Qt.PointingHandCursor
                                    }

                                    ColumnLayout {
                                        anchors.fill: parent
                                        anchors.margins: 12
                                        spacing: 4

                                        Text {
                                            text: "📝 LIVE SUBTITLES"
                                            color: accentColor !== "" ? accentColor : "#3b82f6"
                                            font.pixelSize: 9
                                            font.bold: true
                                            font.letterSpacing: 1.5
                                        }

                                        Text {
                                            Layout.fillWidth: true
                                            Layout.fillHeight: true
                                            text: activeSubtitleText !== "" 
                                                  ? activeSubtitleText 
                                                  : (currentLyrics !== "" ? "Plain lyrics loaded. Click to view." : "No subtitles loaded. Click to generate.")
                                            color: activeSubtitleText !== "" ? "white" : "#64748b"
                                            font.bold: activeSubtitleText !== ""
                                            font.pixelSize: 13
                                            wrapMode: Text.WordWrap
                                            elide: Text.ElideRight
                                            maximumLineCount: 2
                                            verticalAlignment: Text.AlignVCenter
                                        }
                                    }
                                }

                                // Up Next Card
                                Rectangle {
                                    id: upNextCard
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 76
                                    color: Qt.rgba(15/255.0, 23/255.0, 42/255.0, 0.35)
                                    radius: 12
                                    border.color: "#1e293b"
                                    border.width: 1
                                    visible: playlist.length > 1

                                    MouseArea {
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        onClicked: playNext()
                                        cursorShape: Qt.PointingHandCursor
                                    }

                                    ColumnLayout {
                                        anchors.fill: parent
                                        anchors.margins: 10
                                        spacing: 4

                                        Text {
                                            text: "📋 UP NEXT"
                                            color: "#64748b"
                                            font.pixelSize: 9
                                            font.bold: true
                                            font.letterSpacing: 1.5
                                        }

                                        RowLayout {
                                            Layout.fillWidth: true
                                            spacing: 8

                                            Text {
                                                text: "⏭️"
                                                font.pixelSize: 14
                                                Layout.alignment: Qt.AlignVCenter
                                            }

                                            ColumnLayout {
                                                Layout.fillWidth: true
                                                spacing: 2

                                                Text {
                                                    Layout.fillWidth: true
                                                    text: {
                                                        var nextIdx = (currentTrackIndex + 1) % playlist.length;
                                                        return playlist[nextIdx] ? playlist[nextIdx].title : "End of Playlist"
                                                    }
                                                    color: "white"
                                                    font.bold: true
                                                    font.pixelSize: 12
                                                    elide: Text.ElideRight
                                                }

                                                Text {
                                                    Layout.fillWidth: true
                                                    text: {
                                                        var nextIdx = (currentTrackIndex + 1) % playlist.length;
                                                        return playlist[nextIdx] ? (playlist[nextIdx].artist || "Unknown Artist") : ""
                                                    }
                                                    color: "#64748b"
                                                    font.pixelSize: 11
                                                    elide: Text.ElideRight
                                                    visible: text !== ""
                                                }
                                            }
                                        }
                                    }
                                }

                                Item { height: 10 }

                                // Playback stats row
                                RowLayout {
                                    spacing: 20
                                    Layout.fillWidth: true

                                    Column {
                                        spacing: 3
                                        Text { text: "FORMAT"; color: "#64748b"; font.pixelSize: 9; font.letterSpacing: 1.5 }
                                        Text {
                                            text: {
                                                var url = currentTrackIndex >= 0 ? playlist[currentTrackIndex].url : ""
                                                var ext = url.split('.').pop().toUpperCase()
                                                return ext || "—"
                                            }
                                            color: "#cbd5e1"; font.pixelSize: 13; font.bold: true
                                        }
                                    }
                                    Column {
                                        spacing: 3
                                        Text { text: "DURATION"; color: "#64748b"; font.pixelSize: 9; font.letterSpacing: 1.5 }
                                        Text {
                                            text: player.duration > 0 ? formatTime(player.duration / 1000) : "—"
                                            color: "#cbd5e1"; font.pixelSize: 13; font.bold: true
                                        }
                                    }
                                    Column {
                                        spacing: 3
                                        Text { text: "TRACK"; color: "#64748b"; font.pixelSize: 9; font.letterSpacing: 1.5 }
                                        Text {
                                            text: currentTrackIndex >= 0 ? (currentTrackIndex + 1) + " / " + playlist.length : "—"
                                            color: "#cbd5e1"; font.pixelSize: 13; font.bold: true
                                        }
                                    }
                                }

                                Item { Layout.fillHeight: true }
                            }
                        }
                    }

                    // 2b. Native Video View
                    Item {
                        anchors.fill: parent
                        visible: currentView === "video"

                        VideoOutput {
                            id: videoOutput
                            anchors.fill: parent

                            // Mouse area to capture hover and double clicks for fullscreen
                            MouseArea {
                                id: videoMouseArea
                                anchors.fill: parent
                                hoverEnabled: true
                                preventStealing: true
                                
                                cursorShape: (window.visibility === Window.FullScreen && !controlsVisible) ? Qt.BlankCursor : Qt.ArrowCursor
                                
                                onPositionChanged: {
                                    if (window.visibility === Window.FullScreen) {
                                        controlsVisible = true
                                        controlsHideTimer.restart()
                                    }
                                }
                                onDoubleClicked: {
                                    toggleFullscreen()
                                }
                                onClicked: (mouse) => {
                                    if (player.playbackState === MediaPlayer.PlayingState) {
                                        player.pause()
                                    } else {
                                        player.play()
                                    }
                                }
                            }
                            
                            
                        }
                    }

                    // 2c. Combined Lyrics and Synced Subtitles View
                    Item {
                        id: lyricsPanel
                        anchors.fill: parent
                        visible: currentView === "lyrics"

                        // ── Local state ──────────────────────────────────
                        property bool settingsOpen: false

                        ColumnLayout {
                            anchors.fill: parent
                            spacing: 0

                            // ── Top toolbar ─────────────────────────────
                            Rectangle {
                                id: toolbarCard
                                Layout.fillWidth: true
                                Layout.preferredHeight: 52
                                color: "#0f172a" // Deep Slate-900
                                radius: 8
                                border.color: "#1e293b" // Slate-800
                                border.width: 1
                                visible: subtitleChunks.length > 0 || currentLyrics !== ""

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: 10
                                    anchors.rightMargin: 10
                                    spacing: 8

                                    // Search field (only meaningful with synced subs)
                                    TextField {
                                        id: transcriptSearchField
                                        Layout.fillWidth: true
                                        Layout.preferredHeight: 34
                                        visible: subtitleChunks.length > 0
                                        placeholderText: "🔍 Search transcript…"
                                        color: "white"
                                        font.pixelSize: 13
                                        background: Rectangle {
                                            color: "#020617" // extra contrast background
                                            radius: 7
                                            border.color: transcriptSearchField.activeFocus ? "#3b82f6" : "#334155"
                                            border.width: 1
                                            Behavior on border.color { ColorAnimation { duration: 150 } }
                                        }
                                        onTextChanged: transcriptSearchQuery = text
                                    }

                                    // Settings toggle (⚙)
                                    Button {
                                        id: subSettingsToggleBtn
                                        flat: true
                                        Layout.preferredWidth:  36
                                        Layout.preferredHeight: 36
                                        padding: 0
                                        visible: subtitleChunks.length > 0 || currentLyrics !== ""
                                        background: Rectangle {
                                            color: lyricsPanel.settingsOpen
                                                   ? "#1d4ed8"
                                                   : (subSettingsToggleBtn.hovered ? "#334155" : "transparent")
                                            radius: 7
                                            border.color: lyricsPanel.settingsOpen ? "#3b82f6" : "#475569"
                                            border.width: 1
                                            Behavior on color { ColorAnimation { duration: 150 } }
                                        }
                                        contentItem: Text {
                                            text: "⚙"
                                            color: "white"
                                            font.pixelSize: 18
                                            horizontalAlignment: Text.AlignHCenter
                                            verticalAlignment: Text.AlignVCenter
                                        }
                                        onClicked: lyricsPanel.settingsOpen = !lyricsPanel.settingsOpen
                                    }

                                    // Load file button
                                    Button {
                                        id: loadTextFileBtnNew
                                        flat: true
                                        Layout.preferredWidth: 36
                                        Layout.preferredHeight: 36
                                        padding: 0
                                        background: Rectangle {
                                            color: loadTextFileBtnNew.pressed ? "#1e293b"
                                                 : (loadTextFileBtnNew.hovered ? "#334155" : "transparent")
                                            radius: 7
                                            border.color: "#475569"
                                            border.width: 1
                                        }
                                        contentItem: Text {
                                            text: "📄"
                                            color: "white"
                                            font.pixelSize: 16
                                            horizontalAlignment: Text.AlignHCenter
                                            verticalAlignment: Text.AlignVCenter
                                        }
                                        onClicked: lyricsFileDialog.open()
                                    }

                                    // Clear button
                                    Button {
                                        id: clearSubsBtnNew
                                        flat: true
                                        Layout.preferredWidth: 36
                                        Layout.preferredHeight: 36
                                        padding: 0
                                        background: Rectangle {
                                            color: clearSubsBtnNew.pressed ? "#991b1b"
                                                 : (clearSubsBtnNew.hovered ? "#7f1d1d" : "transparent")
                                            radius: 7
                                            border.color: "#991b1b"
                                            border.width: 1
                                        }
                                        contentItem: Text {
                                            text: "🗑️"
                                            color: "#fca5a5"
                                            font.pixelSize: 16
                                            horizontalAlignment: Text.AlignHCenter
                                            verticalAlignment: Text.AlignVCenter
                                        }
                                        onClicked: {
                                            subtitleChunks = []
                                            currentLyrics = ""
                                            transcriptSearchQuery = ""
                                        }
                                    }
                                }
                            }

                            // ── Collapsible settings panel ───────────────
                            Rectangle {
                                id: settingsPanel
                                Layout.fillWidth: true

                                // Drive layout height via an animatable property so the
                                // ColumnLayout reflows correctly while the panel opens/closes.
                                property real targetHeight: (lyricsPanel.settingsOpen && (subtitleChunks.length > 0 || currentLyrics !== ""))
                                                           ? (settingsPanelContent.implicitHeight + 20)
                                                           : 0
                                Behavior on targetHeight {
                                    NumberAnimation { duration: 200; easing.type: Easing.InOutQuad }
                                }
                                Layout.preferredHeight: targetHeight
                                // clip hides children while collapsed; no need to set visible: false
                                clip: true
                                color: "#0a111e"
                                radius: 8
                                border.color: targetHeight > 0 ? "#1e3a5f" : "transparent"
                                border.width: 1

                                ColumnLayout {
                                    id: settingsPanelContent
                                    anchors { left: parent.left; right: parent.right; top: parent.top; margins: 10 }
                                    spacing: 10

                                    // ── Subtitle Customizer ─────────────
                                    Text {
                                        text: "Subtitle Appearance"
                                        color: "#94a3b8"
                                        font.pixelSize: 10
                                        font.bold: true
                                        font.letterSpacing: 1.2
                                    }

                                    // Font size
                                    RowLayout {
                                        Layout.fillWidth: true
                                        spacing: 8
                                        Text { text: "Size"; color: "#cbd5e1"; font.pixelSize: 11; Layout.preferredWidth: 36 }
                                        Slider {
                                            id: fontSizeSlider
                                            Layout.fillWidth: true
                                            from: 12; to: 36; value: subtitleFontSize; stepSize: 1
                                            onValueChanged: subtitleFontSize = value
                                            background: Rectangle {
                                                x: fontSizeSlider.leftPadding
                                                y: fontSizeSlider.topPadding + fontSizeSlider.availableHeight / 2 - height / 2
                                                width: fontSizeSlider.availableWidth; height: 4; radius: 2; color: "#334155"
                                                Rectangle { width: fontSizeSlider.visualPosition * parent.width; height: parent.height; color: "#3b82f6"; radius: 2 }
                                            }
                                            handle: Rectangle {
                                                x: fontSizeSlider.leftPadding + fontSizeSlider.visualPosition * (fontSizeSlider.availableWidth - width)
                                                y: fontSizeSlider.topPadding + fontSizeSlider.availableHeight / 2 - height / 2
                                                width: 14; height: 14; radius: 7; color: "#3b82f6"; border.color: "white"; border.width: 2
                                            }
                                        }
                                        Text { text: subtitleFontSize + "px"; color: "#60a5fa"; font.pixelSize: 11; Layout.preferredWidth: 32 }
                                    }

                                    // Background opacity
                                    RowLayout {
                                        Layout.fillWidth: true
                                        spacing: 8
                                        Text { text: "BG α"; color: "#cbd5e1"; font.pixelSize: 11; Layout.preferredWidth: 36 }
                                        Slider {
                                            id: bgOpacitySlider
                                            Layout.fillWidth: true
                                            from: 0; to: 1; value: subtitleBgOpacity; stepSize: 0.05
                                            onValueChanged: subtitleBgOpacity = value
                                            background: Rectangle {
                                                x: bgOpacitySlider.leftPadding
                                                y: bgOpacitySlider.topPadding + bgOpacitySlider.availableHeight / 2 - height / 2
                                                width: bgOpacitySlider.availableWidth; height: 4; radius: 2; color: "#334155"
                                                Rectangle { width: bgOpacitySlider.visualPosition * parent.width; height: parent.height; color: "#3b82f6"; radius: 2 }
                                            }
                                            handle: Rectangle {
                                                x: bgOpacitySlider.leftPadding + bgOpacitySlider.visualPosition * (bgOpacitySlider.availableWidth - width)
                                                y: bgOpacitySlider.topPadding + bgOpacitySlider.availableHeight / 2 - height / 2
                                                width: 14; height: 14; radius: 7; color: "#3b82f6"; border.color: "white"; border.width: 2
                                            }
                                        }
                                        Text { text: Math.round(subtitleBgOpacity * 100) + "%"; color: "#60a5fa"; font.pixelSize: 11; Layout.preferredWidth: 32 }
                                    }

                                    // Text colour row
                                    RowLayout {
                                        Layout.fillWidth: true
                                        spacing: 8
                                        Text { text: "Color"; color: "#cbd5e1"; font.pixelSize: 11; Layout.preferredWidth: 36 }
                                        Repeater {
                                            model: ["#ffffff", "#facc15", "#4ade80", "#f87171", "#93c5fd", "#f0abfc"]
                                            delegate: Rectangle {
                                                width: 20; height: 20; radius: 4; color: modelData
                                                border.color: subtitleTextColor === modelData ? "white" : "transparent"
                                                border.width: 2
                                                Behavior on border.color { ColorAnimation { duration: 100 } }
                                                MouseArea { anchors.fill: parent; onClicked: subtitleTextColor = modelData }
                                            }
                                        }
                                    }

                                    // ── Re-sync controls ────────────────
                                    Rectangle { Layout.fillWidth: true; height: 1; color: "#1e3a5f" }

                                    Text {
                                        text: "Timing Offset"
                                        color: subtitleChunks.length > 0 ? "#94a3b8" : "#475569"
                                        font.pixelSize: 10
                                        font.bold: true
                                        font.letterSpacing: 1.2
                                    }

                                    RowLayout {
                                        Layout.fillWidth: true
                                        spacing: 6
                                        Repeater {
                                            model: [
                                                { label: "−2s",  delta: -2.0 },
                                                { label: "−0.5s",delta: -0.5 },
                                                { label: "+0.5s",delta:  0.5 },
                                                { label: "+2s",  delta:  2.0 }
                                            ]
                                            delegate: Button {
                                                flat: true
                                                Layout.fillWidth: true
                                                Layout.preferredHeight: 28
                                                enabled: subtitleChunks.length > 0
                                                padding: 0
                                                background: Rectangle {
                                                    color: parent.pressed ? "#1e3a5f"
                                                         : (parent.hovered  ? "#1e293b" : "#0f172a")
                                                    radius: 6
                                                    border.color: "#334155"
                                                    border.width: 1
                                                }
                                                contentItem: Text {
                                                    text: modelData.label
                                                    color: subtitleChunks.length > 0 ? "#93c5fd" : "#475569"
                                                    font.pixelSize: 11
                                                    font.bold: true
                                                    horizontalAlignment: Text.AlignHCenter
                                                    verticalAlignment: Text.AlignVCenter
                                                }
                                                onClicked: shiftSubtitles(modelData.delta)
                                            }
                                        }
                                    }

                                    // ── Export buttons ──────────────────
                                    Rectangle { Layout.fillWidth: true; height: 1; color: "#1e3a5f" }

                                    Text {
                                        text: "Export"
                                        color: "#94a3b8"
                                        font.pixelSize: 10
                                        font.bold: true
                                        font.letterSpacing: 1.2
                                    }

                                    RowLayout {
                                        Layout.fillWidth: true
                                        spacing: 6
                                        Repeater {
                                            model: ["SRT", "VTT", "TXT"]
                                            delegate: Button {
                                                flat: true
                                                Layout.fillWidth: true
                                                Layout.preferredHeight: 34
                                                enabled: modelData === "TXT" ? (subtitleChunks.length > 0 || currentLyrics !== "") : (subtitleChunks.length > 0)
                                                padding: 0
                                                background: Rectangle {
                                                    color: parent.pressed ? "#1e3a5f"
                                                         : (parent.hovered  ? "#1e293b" : "#0f172a")
                                                    radius: 6
                                                    border.color: "#334155"
                                                    border.width: 1
                                                }
                                                contentItem: Text {
                                                    text: "💾 " + modelData
                                                    color: (modelData === "TXT" ? (subtitleChunks.length > 0 || currentLyrics !== "") : (subtitleChunks.length > 0)) ? "#6ee7b7" : "#475569"
                                                    font.pixelSize: 11
                                                    font.bold: true
                                                    horizontalAlignment: Text.AlignHCenter
                                                    verticalAlignment: Text.AlignVCenter
                                                }
                                                onClicked: {
                                                    pendingExportFormat = modelData.toLowerCase()
                                                    exportFileDialog.open()
                                                }
                                            }
                                        }
                                    }

                                    Item { height: 2 }
                                }
                            }

                            // ── Case A: Filtered synced subtitle list ────
                            ListView {
                                id: transcriptListView
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                visible: subtitleChunks.length > 0
                                clip: true
                                model: filteredSubtitleChunks

                                highlightRangeMode: ListView.ApplyRange
                                preferredHighlightBegin: height / 3
                                preferredHighlightEnd: height / 2

                                // Keep the highlight tracking the active subtitle when searching
                                onModelChanged: {
                                    if (transcriptSearchQuery.trim() === "") {
                                        currentIndex = currentActiveSubtitleIndex
                                    }
                                }

                                delegate: ItemDelegate {
                                    width: transcriptListView.width
                                    implicitHeight: delegateRowLayout.implicitHeight + 16
                                    padding: 8

                                    // When filtering, compare against originalIndex if available
                                    property int origIdx: modelData.originalIndex !== undefined
                                                          ? modelData.originalIndex
                                                          : index
                                    property bool isActive: origIdx === currentActiveSubtitleIndex

                                    contentItem: RowLayout {
                                        id: delegateRowLayout
                                        spacing: 12
                                        Text {
                                            text: formatTime(modelData.start)
                                            color: isActive ? "#60a5fa" : "#64748b"
                                            font.bold: true
                                            font.pixelSize: isActive ? 14 : 12
                                        }
                                        Text {
                                            text: modelData.text
                                            color: isActive ? "white" : "#94a3b8"
                                            font.bold: isActive
                                            font.pixelSize: isActive ? 15 : 13
                                            wrapMode: Text.WordWrap
                                            Layout.fillWidth: true
                                        }
                                    }
                                    background: Rectangle {
                                        color: isActive
                                               ? Qt.rgba(59/255.0, 130/255.0, 246/255.0, 0.15)
                                               : (hovered ? "#334155" : "transparent")
                                        radius: 8
                                        border.color: isActive ? "#3b82f6" : "transparent"
                                        border.width: 1
                                    }
                                    onClicked: {
                                        player.position = modelData.start * 1000.0
                                    }
                                }
                            }

                            // ── Case B: Scrollable plain lyrics sheet ────
                            ScrollView {
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                visible: subtitleChunks.length === 0 && currentLyrics !== ""
                                clip: true

                                Text {
                                    width: parent.width
                                    text: currentLyrics
                                    color: subtitleTextColor
                                    font.pixelSize: subtitleFontSize
                                    lineHeight: 1.5
                                    horizontalAlignment: Text.AlignHCenter
                                    wrapMode: Text.WordWrap
                                }
                            }

                            // ── Case C: Unloaded state (Generator Interface) ──
                            Item {
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                visible: subtitleChunks.length === 0 && currentLyrics === ""

                                ColumnLayout {
                                    anchors.centerIn: parent
                                    spacing: 20
                                    width: parent.width * 0.9

                                    Text {
                                        text: "No Lyrics or Subtitles loaded."
                                        color: "#94a3b8"
                                        font.pixelSize: 14
                                        font.bold: true
                                        Layout.alignment: Qt.AlignHCenter
                                    }

                                    Button {
                                        id: loadLyricsPromptBtn
                                        flat: true
                                        Layout.preferredHeight: 36
                                        Layout.alignment: Qt.AlignHCenter
                                        scale: loadLyricsPromptBtn.hovered ? 1.03 : 1.0
                                        Behavior on scale { NumberAnimation { duration: 100 } }
                                        padding: 0
                                        background: Rectangle {
                                            color: loadLyricsPromptBtn.pressed ? "#0f172a" : (loadLyricsPromptBtn.hovered ? "#334155" : "#1e293b")
                                            radius: 8
                                            border.color: "#475569"
                                            border.width: 1
                                        }
                                        contentItem: Text {
                                            text: "📂 Load Lyrics or Subtitles (.txt, .srt)"
                                            color: "white"
                                            font.bold: true
                                            font.pixelSize: 13
                                            horizontalAlignment: Text.AlignHCenter
                                            verticalAlignment: Text.AlignVCenter
                                            leftPadding: 16
                                            rightPadding: 16
                                        }
                                        onClicked: lyricsFileDialog.open()
                                    }

                                    Rectangle {
                                        Layout.fillWidth: true
                                        height: 1
                                        color: "#334155"
                                    }

                                    Text {
                                        text: "Local Speech-to-Text Generator"
                                        color: "white"
                                        font.pixelSize: 14
                                        font.bold: true
                                        Layout.alignment: Qt.AlignHCenter
                                    }

                                    // High Contrast Custom Grids for Inputs
                                    GridLayout {
                                        columns: 2
                                        rowSpacing: 12
                                        columnSpacing: 18
                                        Layout.alignment: Qt.AlignHCenter

                                        Text {
                                            text: "Whisper Model:"
                                            color: "#cbd5e0"
                                            font.pixelSize: 12
                                        }
                                        ComboBox {
                                             id: modelSelector
                                             Layout.preferredWidth: 160
                                             Layout.preferredHeight: 30
                                             model: ["Tiny (Fast, 77MB)", "Base (Accurate, 140MB)"]
                                             currentIndex: 0
                                             padding: 0
                                             
                                             contentItem: Text {
                                                 text: modelSelector.displayText
                                                 color: "white"
                                                 font.pixelSize: 12
                                                 verticalAlignment: Text.AlignVCenter
                                                 leftPadding: 8
                                                 rightPadding: 8
                                                 elide: Text.ElideRight
                                             }
                                             background: Rectangle {
                                                 color: "#1e293b"
                                                 radius: 6
                                                 border.color: "#475569"
                                                 border.width: 1
                                             }
                                             delegate: ItemDelegate {
                                                 width: modelSelector.width
                                                 padding: 0
                                                 contentItem: Text {
                                                     text: modelData
                                                     color: hovered ? "white" : "#cbd5e0"
                                                     font.pixelSize: 12
                                                     verticalAlignment: Text.AlignVCenter
                                                     leftPadding: 8
                                                     rightPadding: 8
                                                 }
                                                 background: Rectangle {
                                                     color: hovered ? "#2563eb" : "#1e293b"
                                                 }
                                             }
                                             popup: Popup {
                                                 y: modelSelector.height
                                                 width: modelSelector.width
                                                 implicitHeight: contentItem.implicitHeight + 2
                                                 padding: 1
                                                 contentItem: ListView {
                                                     clip: true
                                                     implicitHeight: contentHeight
                                                     model: modelSelector.popup.visible ? modelSelector.delegateModel : null
                                                     currentIndex: modelSelector.highlightedIndex
                                                     ScrollIndicator.vertical: ScrollIndicator { }
                                                 }
                                                 background: Rectangle {
                                                     color: "#1e293b"
                                                     border.color: "#475569"
                                                     border.width: 1
                                                     radius: 6
                                                 }
                                             }
                                         }

                                        Text {
                                            text: "Transcription Mode:"
                                            color: "#cbd5e0"
                                            font.pixelSize: 12
                                        }
                                        ComboBox {
                                             id: taskSelector
                                             Layout.preferredWidth: 160
                                             Layout.preferredHeight: 30
                                             model: ["Transcribe (Original)", "Translate to English"]
                                             currentIndex: 0
                                             padding: 0
                                             
                                             contentItem: Text {
                                                 text: taskSelector.displayText
                                                 color: "white"
                                                 font.pixelSize: 12
                                                 verticalAlignment: Text.AlignVCenter
                                                 leftPadding: 8
                                                 rightPadding: 8
                                                 elide: Text.ElideRight
                                             }
                                             background: Rectangle {
                                                 color: "#1e293b"
                                                 radius: 6
                                                 border.color: "#475569"
                                                 border.width: 1
                                             }
                                             delegate: ItemDelegate {
                                                 width: taskSelector.width
                                                 padding: 0
                                                 contentItem: Text {
                                                     text: modelData
                                                     color: hovered ? "white" : "#cbd5e0"
                                                     font.pixelSize: 12
                                                     verticalAlignment: Text.AlignVCenter
                                                     leftPadding: 8
                                                     rightPadding: 8
                                                 }
                                                 background: Rectangle {
                                                     color: hovered ? "#2563eb" : "#1e293b"
                                                 }
                                             }
                                             popup: Popup {
                                                 y: taskSelector.height
                                                 width: taskSelector.width
                                                 implicitHeight: contentItem.implicitHeight + 2
                                                 padding: 1
                                                 contentItem: ListView {
                                                     clip: true
                                                     implicitHeight: contentHeight
                                                     model: taskSelector.popup.visible ? taskSelector.delegateModel : null
                                                     currentIndex: taskSelector.highlightedIndex
                                                     ScrollIndicator.vertical: ScrollIndicator { }
                                                 }
                                                 background: Rectangle {
                                                     color: "#1e293b"
                                                     border.color: "#475569"
                                                     border.width: 1
                                                     radius: 6
                                                 }
                                             }
                                         }

                                        Text {
                                            text: "Audio Language:"
                                            color: "#cbd5e0"
                                            font.pixelSize: 12
                                        }
                                        ComboBox {
                                             id: languageSelector
                                             Layout.preferredWidth: 160
                                             Layout.preferredHeight: 30
                                             model: ["Auto-Detect", "English", "Spanish", "French", "German", "Japanese", "Chinese", "Korean", "Russian", "Portuguese", "Italian"]
                                             currentIndex: 0
                                             enabled: taskSelector.currentIndex === 0
                                             padding: 0
                                             
                                             contentItem: Text {
                                                 text: languageSelector.displayText
                                                 color: "white"
                                                 font.pixelSize: 12
                                                 verticalAlignment: Text.AlignVCenter
                                                 leftPadding: 8
                                                 rightPadding: 8
                                                 elide: Text.ElideRight
                                             }
                                             background: Rectangle {
                                                 color: "#1e293b"
                                                 radius: 6
                                                 border.color: "#475569"
                                                 border.width: 1
                                             }
                                             delegate: ItemDelegate {
                                                 width: languageSelector.width
                                                 padding: 0
                                                 contentItem: Text {
                                                     text: modelData
                                                     color: hovered ? "white" : "#cbd5e0"
                                                     font.pixelSize: 12
                                                     verticalAlignment: Text.AlignVCenter
                                                     leftPadding: 8
                                                     rightPadding: 8
                                                 }
                                                 background: Rectangle {
                                                     color: hovered ? "#2563eb" : "#1e293b"
                                                 }
                                             }
                                             popup: Popup {
                                                 y: languageSelector.height
                                                 width: languageSelector.width
                                                 implicitHeight: contentItem.implicitHeight + 2
                                                 padding: 1
                                                 contentItem: ListView {
                                                     clip: true
                                                     implicitHeight: contentHeight
                                                     model: languageSelector.popup.visible ? languageSelector.delegateModel : null
                                                     currentIndex: languageSelector.highlightedIndex
                                                     ScrollIndicator.vertical: ScrollIndicator { }
                                                 }
                                                 background: Rectangle {
                                                     color: "#1e293b"
                                                     border.color: "#475569"
                                                     border.width: 1
                                                     radius: 6
                                                 }
                                             }
                                         }
                                    }

                                    Button {
                                        id: startSubsGenBtn
                                        flat: true
                                        Layout.preferredHeight: 38
                                        Layout.alignment: Qt.AlignHCenter
                                        enabled: currentTrackIndex !== -1
                                        scale: startSubsGenBtn.enabled && startSubsGenBtn.hovered ? 1.03 : 1.0
                                        Behavior on scale { NumberAnimation { duration: 100 } }
                                        padding: 0
                                        background: Rectangle {
                                            color: startSubsGenBtn.enabled ? (startSubsGenBtn.pressed ? "#15803d" : (startSubsGenBtn.hovered ? "#22c55e" : "#16a34a")) : "#334155"
                                            radius: 8
                                            border.color: startSubsGenBtn.enabled && startSubsGenBtn.hovered ? "#4ade80" : "transparent"
                                            border.width: 1
                                        }
                                        contentItem: Text {
                                            text: "✨ Generate Synced Lyrics & Subs"
                                            color: startSubsGenBtn.enabled ? "white" : "#94a3b8"
                                            font.bold: true
                                            font.pixelSize: 13
                                            horizontalAlignment: Text.AlignHCenter
                                            verticalAlignment: Text.AlignVCenter
                                            leftPadding: 18
                                            rightPadding: 18
                                        }
                                        onClicked: {
                                            var selected = modelSelector.currentIndex === 0 ? "tiny" : "base"
                                            if (!modelDownloader.checkModelExists(selected)) {
                                                modelDownloader.startDownload(selected)
                                            } else {
                                                var lang = languageSelector.currentText
                                                var translate = taskSelector.currentIndex === 1
                                                subGenerator.generateSubtitles(playlist[currentTrackIndex].url, modelDownloader.getModelPath(selected), lang, translate)
                                            }
                                        }
                                    }

                                    // Downloader progress layout (Custom ProgressBar)
                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        visible: modelDownloader.isDownloading
                                        spacing: 8
                                        Text {
                                            text: "Downloading Whisper model weights (first-run only)..."
                                            color: "white"
                                            font.pixelSize: 12
                                        }
                                        ProgressBar {
                                            id: downloadProgressBar
                                            Layout.fillWidth: true
                                            from: 0
                                            to: 100
                                            background: Rectangle {
                                                implicitHeight: 6
                                                color: "#334155"
                                                radius: 3
                                            }
                                            contentItem: Item {
                                                implicitHeight: 6
                                                Rectangle {
                                                    width: downloadProgressBar.visualPosition * parent.width
                                                    height: parent.height
                                                    color: "#3b82f6"
                                                    radius: 3
                                                }
                                            }
                                        }
                                    }

                                    // Transcription progress layout (Custom ProgressBar)
                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        visible: subGenerator.isProcessing
                                        spacing: 8
                                        Text {
                                            text: "Transcribing audio locally..."
                                            color: "white"
                                            font.pixelSize: 12
                                        }
                                        ProgressBar {
                                            id: transcriptionProgress
                                            Layout.fillWidth: true
                                            from: 0
                                            to: 100
                                            background: Rectangle {
                                                implicitHeight: 6
                                                color: "#334155"
                                                radius: 3
                                            }
                                            contentItem: Item {
                                                implicitHeight: 6
                                                Rectangle {
                                                    width: transcriptionProgress.visualPosition * parent.width
                                                    height: parent.height
                                                    color: "#22c55e"
                                                    radius: 3
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // 2d. Playlist View

                    // 2d. Playlist View
                    Item {
                        anchors.fill: parent
                        visible: currentView === "playlist"

                        ColumnLayout {
                            anchors.fill: parent
                            spacing: 12

                            TextField {
                                id: filterField
                                Layout.fillWidth: true
                                placeholderText: "🔍 Filter playlist..."
                                color: "white"
                                font.pixelSize: 13
                                background: Rectangle {
                                    color: "#0f172a"
                                    radius: 8
                                    border.color: "#334155"
                                }
                            }

                            ListView {
                                id: playlistListView
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                clip: true
                                model: playlist.filter(track => track.title.toLowerCase().indexOf(filterField.text.toLowerCase()) !== -1)
                                delegate: ItemDelegate {
                                    width: playlistListView.width
                                    height: 38
                                    property bool isCurrent: modelData.url === playlist[currentTrackIndex]?.url

                                    contentItem: Text {
                                        text: (index + 1) + ". " + modelData.title
                                        color: isCurrent ? "#3b82f6" : "#e2e8f0"
                                        font.bold: isCurrent
                                        font.pixelSize: 13
                                        verticalAlignment: Text.AlignVCenter
                                    }
                                    background: Rectangle {
                                        color: hovered ? "#334155" : "transparent"
                                        radius: 6
                                    }
                                    onClicked: {
                                        var origIndex = playlist.indexOf(modelData)
                                        loadTrack(origIndex)
                                        player.play()
                                    }
                                }
                            }
                        }
                    }
                }

                // Subtitle Overlay (sibling of viewsContainer and controlsPanel)
                Rectangle {
                    id: videoSubOverlay
                    anchors.bottom: (controlsPanel.visible && controlsPanel.opacity > 0.01) ? controlsPanel.top : parent.bottom
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.bottomMargin: (controlsPanel.visible && controlsPanel.opacity > 0.01) ? 12 : 20
                    width: Math.min(parent.width - 48, subText.implicitWidth + 32)
                    height: subText.implicitHeight + 16
                    color: Qt.rgba(15/255.0, 23/255.0, 42/255.0, subtitleBgOpacity)
                    radius: 8
                    border.color: "#334155"
                    border.width: 1
                    visible: (currentView === "video") && activeSubtitleText !== ""
                    z: 50

                    Text {
                        id: subText
                        anchors.centerIn: parent
                        text: activeSubtitleText
                        color: subtitleTextColor
                        font.pixelSize: subtitleFontSize
                        font.bold: true
                        wrapMode: Text.WordWrap
                        horizontalAlignment: Text.AlignHCenter
                    }
                }

                // Bottom Controls area Panel (for contrast guard in fullscreen)
                Rectangle {
                    id: controlsPanel
                    anchors.bottom: parent.bottom
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.margins: (window.visibility === Window.FullScreen || currentView === "video") ? 16 : 24
                    height: controlsContainer.implicitHeight + ((window.visibility === Window.FullScreen || currentView === "video") ? 24 : 0)
                    color: (window.visibility === Window.FullScreen || currentView === "video") ? Qt.rgba(15/255.0, 23/255.0, 42/255.0, 0.92) : "transparent"
                    radius: 12
                    border.color: (window.visibility === Window.FullScreen || currentView === "video") ? "#1e293b" : "transparent"
                    border.width: (window.visibility === Window.FullScreen || currentView === "video") ? 1 : 0
                    z: 100
                    
                    opacity: (window.visibility === Window.FullScreen) ? (controlsVisible ? 1.0 : 0.0) : 1.0
                    Behavior on opacity {
                        NumberAnimation { duration: 300 }
                    }
                    visible: opacity > 0.0

                    HoverHandler {
                        id: controlsHoverHandler
                    }

                    Column {
                        id: controlsContainer
                        anchors.fill: parent
                        anchors.margins: (window.visibility === Window.FullScreen || currentView === "video") ? 12 : 0
                        spacing: 12

                        // Seekbar Slider
                        RowLayout {
                            spacing: 12
                            width: parent.width

                            Text {
                                text: formatTime(player.position / 1000.0)
                                color: "#94a3b8"
                                font.pixelSize: 11
                                font.bold: true
                            }

                            Slider {
                                id: seekSlider
                                Layout.fillWidth: true
                                implicitHeight: 24
                                leftPadding: 7
                                rightPadding: 7
                                topPadding: 0
                                bottomPadding: 0
                                from: 0
                                to: 100
                                value: 0
                                
                                background: Rectangle {
                                    x: seekSlider.leftPadding
                                    y: seekSlider.topPadding + seekSlider.availableHeight / 2 - height / 2
                                    width: seekSlider.availableWidth
                                    height: 6
                                    radius: 3
                                    color: "#334155"
                                    Rectangle {
                                        width: seekSlider.visualPosition * parent.width
                                        height: parent.height
                                        color: "#3b82f6"
                                        radius: 3
                                    }
                                }
                                handle: Rectangle {
                                    x: seekSlider.leftPadding + seekSlider.visualPosition * (seekSlider.availableWidth - width)
                                    y: seekSlider.topPadding + seekSlider.availableHeight / 2 - height / 2
                                    width: 14
                                    height: 14
                                    radius: 7
                                    color: "white"
                                    border.color: "#3b82f6"
                                    border.width: 2
                                }

                                onMoved: {
                                    if (player.duration > 0) {
                                        player.position = (value / 100) * player.duration
                                    }
                                }
                            }

                            // Sibling container for hover previews that sits above the seekSlider
                            Item {
                                anchors.fill: seekSlider
                                z: 9999
                                
                                MouseArea {
                                    id: seekHoverArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    acceptedButtons: Qt.NoButton
                                    onEntered: console.log("[DEBUG] Mouse entered seekHoverArea. containsMouse:", containsMouse)
                                    onExited: console.log("[DEBUG] Mouse exited seekHoverArea. containsMouse:", containsMouse)
                                    onPositionChanged: (mouse) => {
                                        // console.log("[DEBUG] Mouse position changed to X:", mouse.x)
                                    }
                                }
                                
                                Rectangle {
                                    id: previewCard
                                    visible: seekHoverArea.containsMouse && currentTimelinePreviewSheet !== "" && player.duration > 0
                                    width: 164
                                    height: 114
                                    color: Qt.rgba(15/255.0, 23/255.0, 42/255.0, 0.95)
                                    border.color: "#3b82f6"
                                    border.width: 1.5
                                    radius: 6
                                    
                                    x: Math.max(0, Math.min(seekSlider.width - width, seekHoverArea.mouseX - width / 2))
                                    y: -height - 8
                                    
                                    Column {
                                        anchors.fill: parent
                                        anchors.margins: 2
                                        spacing: 2
                                        
                                        Item {
                                            width: 160
                                            height: 90
                                            clip: true
                                            
                                            Rectangle {
                                                anchors.fill: parent
                                                color: "#0f172a"
                                                radius: 4
                                                clip: true
                                                
                                                Image {
                                                    id: previewImage
                                                    source: currentTimelinePreviewSheet
                                                    sourceClipRect: {
                                                        if (player.duration <= 0 || seekSlider.width <= 0) return Qt.rect(0, 0, 160, 90);
                                                        var trackWidth = seekSlider.width - seekSlider.leftPadding - seekSlider.rightPadding;
                                                        var localX = Math.max(0, Math.min(trackWidth, seekHoverArea.mouseX - seekSlider.leftPadding));
                                                        var pct = localX / trackWidth;
                                                        var index = Math.max(0, Math.min(99, Math.floor(pct * 100)));
                                                        var col = index % 10;
                                                        var row = Math.floor(index / 10);
                                                        return Qt.rect(col * 160, row * 90, 160, 90);
                                                    }
                                                    width: 160
                                                    height: 90
                                                    fillMode: Image.Stretch
                                                    asynchronous: true
                                                }
                                            }
                                        }
                                        
                                        Text {
                                            width: parent.width
                                            horizontalAlignment: Text.AlignHCenter
                                            color: "#e2e8f0"
                                            font.pixelSize: 11
                                            font.bold: true
                                            font.family: "Inter"
                                            text: {
                                                if (seekSlider.width <= 0) return "0:00";
                                                var trackWidth = seekSlider.width - seekSlider.leftPadding - seekSlider.rightPadding;
                                                var localX = Math.max(0, Math.min(trackWidth, seekHoverArea.mouseX - seekSlider.leftPadding));
                                                var pct = localX / trackWidth;
                                                var sec = pct * (player.duration / 1000.0);
                                                return formatTime(sec);
                                            }
                                        }
                                    }
                                }
                            }

                            Text {
                                text: player.duration > 0 ? ("-" + formatTime(Math.max(0, player.duration - player.position) / 1000.0) + " / " + formatTime(player.duration / 1000.0)) : "0:00"
                                color: "#94a3b8"
                                font.pixelSize: 11
                                font.bold: true
                            }
                        }

                        RowLayout {
                            id: bottomButtonsBar
                            width: parent.width
                            implicitHeight: 48
                            spacing: isNarrow ? 4 : 8
                            
                            property bool isNarrow: width < 660
                            property bool rightControlsAtBottom: true

                            Component.onCompleted: {
                                console.log("bottomButtonsBar init width:", width)
                            }
                            onWidthChanged: {
                                console.log("bottomButtonsBar width changed:", width)
                            }

                            // Left side container (symmetrical width to right side)
                                // Left side spacer (symmetrical to right controls for centering)
                                Item {
                                    id: leftSideContainer
                                    visible: !bottomButtonsBar.isNarrow && bottomButtonsBar.rightControlsAtBottom
                                    Layout.preferredWidth: bottomButtonsBar.isNarrow ? 0 : rightControlsLayout.implicitWidth
                                    Layout.minimumWidth: 0
                                    Layout.preferredHeight: 32
                                    Layout.alignment: Qt.AlignVCenter
                                }

                            // Spacer to push center controls to the middle
                            Item {
                                Layout.fillWidth: true
                                onWidthChanged: console.log("Spacer 1 width:", width)
                            }

                            // Playback Control Buttons (Centered)
                            RowLayout {
                                id: playbackControlsLayout
                                spacing: bottomButtonsBar.isNarrow ? 8 : 12
                                Layout.alignment: Qt.AlignVCenter

                                Button {
                                    id: prevBtn
                                    flat: true
                                    implicitWidth: 40
                                    implicitHeight: 40
                                    Layout.alignment: Qt.AlignVCenter
                                    scale: prevBtn.hovered ? 1.05 : 1.0
                                    Behavior on scale { NumberAnimation { duration: 100 } }
                                    padding: 0
                                    leftPadding: 0
                                    rightPadding: 0
                                    topPadding: 0
                                    bottomPadding: 0
                                    
                                    background: Rectangle {
                                        radius: 20
                                        color: prevBtn.pressed ? "#1e293b" : (prevBtn.hovered ? "#334155" : "#1e293b")
                                        border.color: prevBtn.hovered ? "#475569" : "#334155"
                                        border.width: 1
                                    }
                                    
                                    contentItem: Canvas {
                                        id: prevCanvas
                                        onWidthChanged: requestPaint()
                                        onHeightChanged: requestPaint()
                                        onPaint: {
                                            var ctx = getContext("2d");
                                            ctx.reset();
                                            ctx.fillStyle = prevBtn.hovered ? "#60a5fa" : "#cbd5e1";
                                            
                                            var w = width;
                                            var h = height;
                                            var iconW = 16;
                                            var iconH = 16;
                                            var cx = w / 2;
                                            var cy = h / 2;
                                            var left = cx - iconW / 2;
                                            var top = cy - iconH / 2;
                                            var right = left + iconW;
                                            var bottom = top + iconH;

                                            // Draw vertical bar on the left
                                            ctx.fillRect(left, top, 3.5, iconH);

                                            // Draw left-pointing triangle
                                            ctx.beginPath();
                                            ctx.moveTo(left + 6.0, cy);
                                            ctx.lineTo(right, top);
                                            ctx.lineTo(right, bottom);
                                            ctx.closePath();
                                            ctx.fill();
                                        }
                                        Connections {
                                            target: prevBtn
                                            function onHoveredChanged() { prevCanvas.requestPaint(); }
                                        }
                                    }
                                    
                                    onClicked: {
                                        playPrev()
                                    }
                                }

                                Button {
                                    id: back5sBtn
                                    flat: true
                                    implicitWidth: 40
                                    implicitHeight: 40
                                    Layout.alignment: Qt.AlignVCenter
                                    scale: back5sBtn.hovered ? 1.05 : 1.0
                                    Behavior on scale { NumberAnimation { duration: 100 } }
                                    padding: 0
                                    leftPadding: 0
                                    rightPadding: 0
                                    topPadding: 0
                                    bottomPadding: 0
                                    
                                    background: Rectangle {
                                        radius: 20
                                        color: back5sBtn.pressed ? "#1e293b" : (back5sBtn.hovered ? "#334155" : "#1e293b")
                                        border.color: back5sBtn.hovered ? "#475569" : "#334155"
                                        border.width: 1
                                    }
                                    
                                    contentItem: Canvas {
                                        id: back5sCanvas
                                        onWidthChanged: requestPaint()
                                        onHeightChanged: requestPaint()
                                        onPaint: {
                                            var ctx = getContext("2d");
                                            ctx.reset();
                                            var color = back5sBtn.hovered ? "#60a5fa" : "#cbd5e1";
                                            ctx.strokeStyle = color;
                                            ctx.fillStyle = color;
                                            ctx.lineWidth = 2.2;
                                            ctx.lineCap = "round";
                                            ctx.lineJoin = "round";
                                            
                                            var cx = width / 2;
                                            var cy = height / 2;
                                            
                                            ctx.beginPath();
                                            ctx.arc(cx, cy, 11, 1.7 * Math.PI, 0.35 * Math.PI, true); // counter-clockwise
                                            ctx.stroke();
                                            
                                            // Arrowhead at 1.7 * Math.PI
                                            var ax = cx + 11 * Math.cos(1.7 * Math.PI);
                                            var ay = cy + 11 * Math.sin(1.7 * Math.PI);
                                            ctx.beginPath();
                                            ctx.moveTo(ax - 4.5, ay - 3.0);
                                            ctx.lineTo(ax, ay);
                                            ctx.lineTo(ax + 3.0, ay + 4.5);
                                            ctx.stroke();
                                            
                                            ctx.font = "bold 12px sans-serif";
                                            ctx.textAlign = "center";
                                            ctx.textBaseline = "middle";
                                            ctx.fillText("5", cx - 0.5, cy + 0.5);
                                        }
                                        Connections {
                                            target: back5sBtn
                                            function onHoveredChanged() { back5sCanvas.requestPaint(); }
                                        }
                                    }
                                    
                                    onClicked: {
                                        seekRelative(-5)
                                    }
                                }

                                Button {
                                    id: playPauseBtn
                                    flat: true
                                    implicitWidth: 48
                                    implicitHeight: 48
                                    Layout.alignment: Qt.AlignVCenter
                                    scale: playPauseBtn.hovered ? 1.05 : 1.0
                                    Behavior on scale { NumberAnimation { duration: 100 } }
                                    padding: 0
                                    leftPadding: 0
                                    rightPadding: 0
                                    topPadding: 0
                                    bottomPadding: 0

                                    background: Rectangle {
                                        radius: 24
                                        color: playPauseBtn.pressed ? "#1d4ed8" : (playPauseBtn.hovered ? "#2563eb" : "#3b82f6")
                                        border.color: playPauseBtn.pressed ? "#1e40af" : "#60a5fa"
                                        border.width: 1
                                    }
                                    contentItem: Canvas {
                                        id: playPauseCanvas
                                        onWidthChanged: requestPaint()
                                        onHeightChanged: requestPaint()
                                        onPaint: {
                                            var ctx = getContext("2d");
                                            ctx.reset();
                                            ctx.fillStyle = "white";
                                            
                                            var w = width;
                                            var h = height;
                                            var cx = w / 2;
                                            var cy = h / 2;
                                            var iconW = 14;
                                            var iconH = 16;
                                            var left = cx - iconW / 2;
                                            var top = cy - iconH / 2;
                                            var right = left + iconW;
                                            var bottom = top + iconH;

                                            var isPlaying = (player.playbackState === MediaPlayer.PlayingState);
                                            if (isPlaying) {
                                                // Draw Pause (two vertical rectangles)
                                                ctx.fillRect(left, top, 4, iconH);
                                                ctx.fillRect(right - 4, top, 4, iconH);
                                            } else {
                                                // Draw Play triangle (slightly offset right for visual balance)
                                                ctx.beginPath();
                                                ctx.moveTo(left + 1.5, top);
                                                ctx.lineTo(right + 1.5, cy);
                                                ctx.lineTo(left + 1.5, bottom);
                                                ctx.closePath();
                                                ctx.fill();
                                            }
                                        }
                                        
                                        Connections {
                                            target: player
                                            function onPlaybackStateChanged() { playPauseCanvas.requestPaint(); }
                                        }
                                        Connections {
                                            target: playPauseBtn
                                            function onHoveredChanged() { playPauseCanvas.requestPaint(); }
                                        }
                                    }
                                    onClicked: {
                                        togglePlayPause()
                                    }
                                }

                                Button {
                                    id: forward5sBtn
                                    flat: true
                                    implicitWidth: 40
                                    implicitHeight: 40
                                    Layout.alignment: Qt.AlignVCenter
                                    scale: forward5sBtn.hovered ? 1.05 : 1.0
                                    Behavior on scale { NumberAnimation { duration: 100 } }
                                    padding: 0
                                    leftPadding: 0
                                    rightPadding: 0
                                    topPadding: 0
                                    bottomPadding: 0
                                    
                                    background: Rectangle {
                                        radius: 20
                                        color: forward5sBtn.pressed ? "#1e293b" : (forward5sBtn.hovered ? "#334155" : "#1e293b")
                                        border.color: forward5sBtn.hovered ? "#475569" : "#334155"
                                        border.width: 1
                                    }
                                    
                                    contentItem: Canvas {
                                        id: forward5sCanvas
                                        onWidthChanged: requestPaint()
                                        onHeightChanged: requestPaint()
                                        onPaint: {
                                            var ctx = getContext("2d");
                                            ctx.reset();
                                            var color = forward5sBtn.hovered ? "#60a5fa" : "#cbd5e1";
                                            ctx.strokeStyle = color;
                                            ctx.fillStyle = color;
                                            ctx.lineWidth = 2.2;
                                            ctx.lineCap = "round";
                                            ctx.lineJoin = "round";
                                            
                                            var cx = width / 2;
                                            var cy = height / 2;
                                            
                                            ctx.beginPath();
                                            ctx.arc(cx, cy, 11, 1.3 * Math.PI, 0.65 * Math.PI, false); // clockwise
                                            ctx.stroke();
                                            
                                            // Arrowhead at 1.3 * Math.PI
                                            var ax = cx + 11 * Math.cos(1.3 * Math.PI);
                                            var ay = cy + 11 * Math.sin(1.3 * Math.PI);
                                            ctx.beginPath();
                                            ctx.moveTo(ax + 4.5, ay - 3.0);
                                            ctx.lineTo(ax, ay);
                                            ctx.lineTo(ax - 3.0, ay + 4.5);
                                            ctx.stroke();
                                            
                                            ctx.font = "bold 12px sans-serif";
                                            ctx.textAlign = "center";
                                            ctx.textBaseline = "middle";
                                            ctx.fillText("5", cx - 0.5, cy + 0.5);
                                        }
                                        Connections {
                                            target: forward5sBtn
                                            function onHoveredChanged() { forward5sCanvas.requestPaint(); }
                                        }
                                    }
                                    
                                    onClicked: {
                                        seekRelative(5)
                                    }
                                }

                                Button {
                                    id: nextBtn
                                    flat: true
                                    implicitWidth: 40
                                    implicitHeight: 40
                                    Layout.alignment: Qt.AlignVCenter
                                    scale: nextBtn.hovered ? 1.05 : 1.0
                                    Behavior on scale { NumberAnimation { duration: 100 } }
                                    padding: 0
                                    leftPadding: 0
                                    rightPadding: 0
                                    topPadding: 0
                                    bottomPadding: 0
                                    
                                    background: Rectangle {
                                        radius: 20
                                        color: nextBtn.pressed ? "#1e293b" : (nextBtn.hovered ? "#334155" : "#1e293b")
                                        border.color: nextBtn.hovered ? "#475569" : "#334155"
                                        border.width: 1
                                    }
                                    
                                    contentItem: Canvas {
                                        id: nextCanvas
                                        onWidthChanged: requestPaint()
                                        onHeightChanged: requestPaint()
                                        onPaint: {
                                            var ctx = getContext("2d");
                                            ctx.reset();
                                            ctx.fillStyle = nextBtn.hovered ? "#60a5fa" : "#cbd5e1";
                                            
                                            var w = width;
                                            var h = height;
                                            var iconW = 16;
                                            var iconH = 16;
                                            var cx = w / 2;
                                            var cy = h / 2;
                                            var left = cx - iconW / 2;
                                            var top = cy - iconH / 2;
                                            var right = left + iconW;
                                            var bottom = top + iconH;

                                            // Draw right-pointing triangle
                                            ctx.beginPath();
                                            ctx.moveTo(right - 6.0, cy);
                                            ctx.lineTo(left, top);
                                            ctx.lineTo(left, bottom);
                                            ctx.closePath();
                                            ctx.fill();

                                            // Draw vertical bar on the right
                                            ctx.fillRect(right - 3.5, top, 3.5, iconH);
                                        }
                                        Connections {
                                            target: nextBtn
                                            function onHoveredChanged() { nextCanvas.requestPaint(); }
                                        }
                                    }
                                    
                                    onClicked: {
                                        playNext()
                                    }
                                }
                            }

                            // Spacer to push right controls container to the right
                            Item {
                                Layout.fillWidth: true
                            }

                            // Right side container (symmetrical width to left side)
                            Item {
                                id: rightSideContainer
                                visible: bottomButtonsBar.rightControlsAtBottom
                                Layout.preferredWidth: bottomButtonsBar.isNarrow ? 0 : rightControlsLayout.implicitWidth
                                Layout.minimumWidth: bottomButtonsBar.rightControlsAtBottom ? rightControlsLayout.implicitWidth : 0
                                Layout.preferredHeight: 32
                                Layout.alignment: Qt.AlignVCenter

                                Item {
                                    id: bottomRowAnchorItem
                                    anchors.right: parent.right
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: rightControlsLayout.implicitWidth
                                    height: 32
                                    visible: bottomButtonsBar.rightControlsAtBottom
                                }
                            }
                        }

                        // Message Area (inside layout card for clean contrast layout)
                        Text {
                            id: messageArea
                            anchors.horizontalCenter: parent.horizontalCenter
                            color: "#ef4444"
                            font.pixelSize: 12
                            font.bold: true
                            visible: text !== ""
                        }
                    }
                }

                // Right controls layout (always parented to bottomRowAnchorItem at bottom right)
                RowLayout {
                    id: rightControlsLayout
                    parent: bottomRowAnchorItem
                    spacing: bottomButtonsBar.isNarrow ? 8 : 12
                    z: 1
                    
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    
                    opacity: (window.visibility === Window.FullScreen) ? (controlsVisible ? 1.0 : 0.0) : 1.0
                    Behavior on opacity {
                        NumberAnimation { duration: 300 }
                    }
                    visible: opacity > 0.0
                    
                    // Loop Toggle (Flat circle with Canvas vector icon)
                    Button {
                        id: loopToggleBtn
                        flat: true
                        implicitWidth: 44
                        implicitHeight: 44
                        padding: 0
                        leftPadding: 0
                        rightPadding: 0
                        topPadding: 0
                        bottomPadding: 0
                        property bool looping: controller.loadLoop()
                        property color iconColor: looping ? "#60a5fa" : (loopToggleBtn.hovered ? "#60a5fa" : "#94a3b8")
                        
                        background: Rectangle {
                            color: loopToggleBtn.pressed ? Qt.rgba(255, 255, 255, 0.1) : (loopToggleBtn.hovered ? Qt.rgba(255, 255, 255, 0.05) : "transparent")
                            radius: 18
                        }
                        
                        contentItem: Canvas {
                            id: loopIconCanvas
                            onWidthChanged: requestPaint()
                            onHeightChanged: requestPaint()
                            onPaint: {
                                var ctx = getContext("2d");
                                ctx.reset();
                                ctx.strokeStyle = loopToggleBtn.iconColor;
                                ctx.lineWidth = 2.2;
                                ctx.lineCap = "round";
                                ctx.lineJoin = "round";
                                
                                var w = width;
                                var h = height;
                                var cx = w / 2;
                                var cy = h / 2;
                                
                                // Path 1 (top half, left arrow)
                                ctx.beginPath();
                                ctx.moveTo(cx + 7, cy - 5);
                                ctx.lineTo(cx - 4, cy - 5);
                                ctx.arcTo(cx - 9, cy - 5, cx - 9, cy, 5);
                                ctx.lineTo(cx - 9, cy + 3);
                                ctx.stroke();
                                
                                // Arrow head (pointing left)
                                ctx.beginPath();
                                ctx.moveTo(cx - 1, cy - 9);
                                ctx.lineTo(cx - 4, cy - 5);
                                ctx.lineTo(cx - 1, cy - 1);
                                ctx.stroke();

                                // Path 2 (bottom half, right arrow)
                                ctx.beginPath();
                                ctx.moveTo(cx - 7, cy + 5);
                                ctx.lineTo(cx + 4, cy + 5);
                                ctx.arcTo(cx + 9, cy + 5, cx + 9, cy, 5);
                                ctx.lineTo(cx + 9, cy - 3);
                                ctx.stroke();
                                
                                // Arrow head (pointing right)
                                ctx.beginPath();
                                ctx.moveTo(cx + 1, cy + 1);
                                ctx.lineTo(cx + 4, cy + 5);
                                ctx.lineTo(cx + 1, cy + 9);
                                ctx.stroke();
                            }
                            
                            Connections {
                                target: loopToggleBtn
                                function onLoopingChanged() { loopIconCanvas.requestPaint(); }
                                function onHoveredChanged() { loopIconCanvas.requestPaint(); }
                                function onIconColorChanged() { loopIconCanvas.requestPaint(); }
                            }
                        }
                        
                        onClicked: {
                            looping = !looping
                            controller.saveLoop(looping)
                            showMessage("Playlist looping: " + (looping ? "On" : "Off"))
                        }
                    }

                    // Hoverable Volume Control (Custom Speaker + Precise Slider margins)
                    MouseArea {
                        id: volumeHoverArea
                        Layout.preferredWidth: volumeLayout.implicitWidth
                        Layout.preferredHeight: 44
                        width: Layout.preferredWidth
                        height: 44
                        hoverEnabled: true

                        RowLayout {
                            id: volumeLayout
                            spacing: 8
                            anchors.verticalCenter: parent.verticalCenter

                            Button {
                                id: volumeIconBtn
                                flat: true
                                implicitWidth: 44
                                implicitHeight: 44
                                padding: 0
                                leftPadding: 0
                                rightPadding: 0
                                topPadding: 0
                                bottomPadding: 0
                                property color iconColor: volumeHoverArea.containsMouse || volumeIconBtn.hovered ? "#60a5fa" : "#94a3b8"
                                
                                background: Rectangle {
                                    color: volumeIconBtn.pressed ? Qt.rgba(255, 255, 255, 0.1) : (volumeIconBtn.hovered ? Qt.rgba(255, 255, 255, 0.05) : "transparent")
                                    radius: 18
                                }
                                
                                contentItem: Canvas {
                                    id: volumeIconCanvas
                                    onWidthChanged: requestPaint()
                                    onHeightChanged: requestPaint()
                                    onPaint: {
                                        var ctx = getContext("2d");
                                        ctx.reset();
                                        ctx.fillStyle = volumeIconBtn.iconColor;
                                        ctx.strokeStyle = volumeIconBtn.iconColor;
                                        ctx.lineWidth = 2.0;
                                        ctx.lineCap = "round";
                                        
                                        var w = width;
                                        var h = height;
                                        var cx = w / 2;
                                        var cy = h / 2;
                                        var left = cx - 10;
                                        var speakerRight = left + 9;
                                        
                                        // Speaker body
                                        ctx.beginPath();
                                        ctx.moveTo(left, cy - 4.5);
                                        ctx.lineTo(left + 4, cy - 4.5);
                                        ctx.lineTo(speakerRight, cy - 9);
                                        ctx.lineTo(speakerRight, cy + 9);
                                        ctx.lineTo(left + 4, cy + 4.5);
                                        ctx.lineTo(left, cy + 4.5);
                                        ctx.closePath();
                                        ctx.fill();
                                        
                                        // Sound waves
                                        var vol = isMuted ? 0 : volumeSlider.value
                                        if (vol > 0) {
                                            ctx.beginPath();
                                            ctx.arc(speakerRight, cy, 6, -Math.PI/4, Math.PI/4, false);
                                            ctx.stroke();
                                        }
                                        if (vol > 50) {
                                            ctx.beginPath();
                                            ctx.arc(speakerRight, cy, 11, -Math.PI/4, Math.PI/4, false);
                                            ctx.stroke();
                                        }
                                    }
                                    
                                    Connections {
                                        target: volumeSlider
                                        function onValueChanged() { volumeIconCanvas.requestPaint(); }
                                    }
                                    Connections {
                                        target: volumeIconBtn
                                        function onIconColorChanged() { volumeIconCanvas.requestPaint(); }
                                    }
                                    Connections {
                                        target: window
                                        function onIsMutedChanged() { volumeIconCanvas.requestPaint(); }
                                    }
                                }
                                
                                onClicked: {
                                    toggleMute()
                                }
                            }

                            Rectangle {
                                id: sliderContainer
                                property int targetWidth: volumeHoverArea.containsMouse ? 100 : 0
                                Layout.preferredWidth: targetWidth
                                Layout.preferredHeight: 40
                                width: targetWidth
                                height: 40
                                color: "transparent"
                                clip: true
                                Behavior on targetWidth { NumberAnimation { duration: 250; easing.type: Easing.InOutQuad } }

                                Slider {
                                    id: volumeSlider
                                    anchors.fill: parent
                                    anchors.leftMargin: 4
                                    anchors.rightMargin: 4
                                    implicitHeight: 24
                                    leftPadding: 0
                                    rightPadding: 0
                                    topPadding: 0
                                    bottomPadding: 0
                                    from: 0
                                    to: 100
                                    value: controller.loadVolume()
                                    
                                    background: Rectangle {
                                        x: volumeSlider.leftPadding
                                        y: volumeSlider.topPadding + volumeSlider.availableHeight / 2 - height / 2
                                        width: volumeSlider.availableWidth
                                        height: 4
                                        radius: 2
                                        color: "#475569"
                                        Rectangle {
                                            width: volumeSlider.visualPosition * parent.width
                                            height: parent.height
                                            color: "#3b82f6"
                                            radius: 2
                                        }
                                    }
                                    handle: Rectangle {
                                        x: volumeSlider.leftPadding + volumeSlider.visualPosition * (volumeSlider.availableWidth - width)
                                        y: volumeSlider.topPadding + volumeSlider.availableHeight / 2 - height / 2
                                        width: 10
                                        height: 10
                                        radius: 5
                                        color: "white"
                                        border.color: "#3b82f6"
                                        border.width: 1
                                    }
                                    
                                    onValueChanged: {
                                        controller.saveVolume(value)
                                        if (value > 0 && isMuted) {
                                            isMuted = false
                                        }
                                        volumeIconCanvas.requestPaint()
                                    }
                                }
                            }

                            Text {
                                text: Math.round(volumeSlider.value) + "%"
                                color: "#94a3b8"
                                font.pixelSize: 13
                                font.bold: true
                                Layout.alignment: Qt.AlignVCenter
                            }
                        }
                    }

                    // Fullscreen Toggle Button
                    Button {
                        id: fullscreenBtn
                        flat: true
                        implicitWidth: 44
                        implicitHeight: 44
                        padding: 0
                        leftPadding: 0
                        rightPadding: 0
                        topPadding: 0
                        bottomPadding: 0
                        
                        background: Rectangle {
                            color: fullscreenBtn.pressed ? Qt.rgba(255, 255, 255, 0.1) : (fullscreenBtn.hovered ? Qt.rgba(255, 255, 255, 0.05) : "transparent")
                            radius: 18
                        }
                        
                        contentItem: Canvas {
                            id: fullscreenIconCanvas
                            onWidthChanged: requestPaint()
                            onHeightChanged: requestPaint()
                            onPaint: {
                                var ctx = getContext("2d");
                                ctx.reset();
                                ctx.strokeStyle = fullscreenBtn.hovered ? "#60a5fa" : "#94a3b8";
                                ctx.lineWidth = 2.2;
                                ctx.lineCap = "round";
                                ctx.lineJoin = "round";
                                
                                var cx = width / 2;
                                var cy = height / 2;
                                var isFS = window.visibility === Window.FullScreen;
                                
                                if (!isFS) {
                                    // Outward corners
                                    // Top-left
                                    ctx.beginPath();
                                    ctx.moveTo(cx - 4, cy - 9);
                                    ctx.lineTo(cx - 9, cy - 9);
                                    ctx.lineTo(cx - 9, cy - 4);
                                    ctx.stroke();
                                    // Top-right
                                    ctx.beginPath();
                                    ctx.moveTo(cx + 4, cy - 9);
                                    ctx.lineTo(cx + 9, cy - 9);
                                    ctx.lineTo(cx + 9, cy - 4);
                                    ctx.stroke();
                                    // Bottom-left
                                    ctx.beginPath();
                                    ctx.moveTo(cx - 4, cy + 9);
                                    ctx.lineTo(cx - 9, cy + 9);
                                    ctx.lineTo(cx - 9, cy + 4);
                                    ctx.stroke();
                                    // Bottom-right
                                    ctx.beginPath();
                                    ctx.moveTo(cx + 4, cy + 9);
                                    ctx.lineTo(cx + 9, cy + 9);
                                    ctx.lineTo(cx + 9, cy + 4);
                                    ctx.stroke();
                                } else {
                                    // Inward corners
                                    // Top-left
                                    ctx.beginPath();
                                    ctx.moveTo(cx - 9, cy - 4);
                                    ctx.lineTo(cx - 4, cy - 4);
                                    ctx.lineTo(cx - 4, cy - 9);
                                    ctx.stroke();
                                    // Top-right
                                    ctx.beginPath();
                                    ctx.moveTo(cx + 9, cy - 4);
                                    ctx.lineTo(cx + 4, cy - 4);
                                    ctx.lineTo(cx + 4, cy - 9);
                                    ctx.stroke();
                                    // Bottom-left
                                    ctx.beginPath();
                                    ctx.moveTo(cx - 9, cy + 4);
                                    ctx.lineTo(cx - 4, cy + 4);
                                    ctx.lineTo(cx - 4, cy + 9);
                                    ctx.stroke();
                                    // Bottom-right
                                    ctx.beginPath();
                                    ctx.moveTo(cx + 9, cy + 4);
                                    ctx.lineTo(cx + 4, cy + 4);
                                    ctx.lineTo(cx + 4, cy + 9);
                                    ctx.stroke();
                                }
                            }
                            
                            Connections {
                                target: window
                                function onVisibilityChanged() { fullscreenIconCanvas.requestPaint(); }
                            }
                            Connections {
                                target: fullscreenBtn
                                function onHoveredChanged() { fullscreenIconCanvas.requestPaint(); }
                            }
                        }
                        
                        onClicked: {
                            toggleFullscreen()
                        }
                    }
                }
            }
        }
    }

    // 3. Sliding Menu Drawer (For Loaders)
    Rectangle {
        id: sidebarDrawer
        z: 1000
        x: sidebarOpen ? 155 : -width
        y: 0
        width: 300
        height: parent.height
        color: "#0f172a" // Deep Slate-900

        Rectangle {
            anchors.right: parent.right
            width: 1
            height: parent.height
            color: "#1e293b"
        }

        Behavior on x { NumberAnimation { duration: 250; easing.type: Easing.InOutQuad } }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 24
            spacing: 24

            Text {
                text: "Load Files"
                color: "white"
                font.pixelSize: 18
                font.bold: true
            }

            ColumnLayout {
                spacing: 14
                Layout.fillWidth: true

                Button {
                    id: selectVideoBtn
                    Layout.fillWidth: true
                    Layout.preferredHeight: 38
                    flat: true
                    padding: 0
                    scale: selectVideoBtn.hovered ? 1.02 : 1.0
                    Behavior on scale { NumberAnimation { duration: 100 } }
                    background: Rectangle {
                        color: selectVideoBtn.pressed ? "#0f172a" : (selectVideoBtn.hovered ? "#1e293b" : "transparent")
                        radius: 8
                        border.color: "#334155"
                        border.width: 1
                    }
                    contentItem: Text {
                        text: "🎥 Select Video (MP4/WebM)"
                        color: "white"
                        font.pixelSize: 13
                        leftPadding: 8
                        verticalAlignment: Text.AlignVCenter
                    }
                    onClicked: mediaFileDialog.open()
                }

                Button {
                    id: selectPlaylistBtn
                    Layout.fillWidth: true
                    Layout.preferredHeight: 38
                    flat: true
                    padding: 0
                    scale: selectPlaylistBtn.hovered ? 1.02 : 1.0
                    Behavior on scale { NumberAnimation { duration: 100 } }
                    background: Rectangle {
                        color: selectPlaylistBtn.pressed ? "#0f172a" : (selectPlaylistBtn.hovered ? "#1e293b" : "transparent")
                        radius: 8
                        border.color: "#334155"
                        border.width: 1
                    }
                    contentItem: Text {
                        text: "📋 Select Playlist (.xspf)"
                        color: "white"
                        font.pixelSize: 13
                        leftPadding: 8
                        verticalAlignment: Text.AlignVCenter
                    }
                    onClicked: xspfFileDialog.open()
                }

                Button {
                    id: selectLyricsBtn
                    Layout.fillWidth: true
                    Layout.preferredHeight: 38
                    flat: true
                    padding: 0
                    scale: selectLyricsBtn.hovered ? 1.02 : 1.0
                    Behavior on scale { NumberAnimation { duration: 100 } }
                    background: Rectangle {
                        color: selectLyricsBtn.pressed ? "#0f172a" : (selectLyricsBtn.hovered ? "#1e293b" : "transparent")
                        radius: 8
                        border.color: "#334155"
                        border.width: 1
                    }
                    contentItem: Text {
                        text: "📄 Select Lyrics/Subs (.txt/.srt)"
                        color: "white"
                        font.pixelSize: 13
                        leftPadding: 8
                        verticalAlignment: Text.AlignVCenter
                    }
                    onClicked: lyricsFileDialog.open()
                }
            }

            Item { Layout.fillHeight: true } // Spacer

            Button {
                id: closeDrawerBtn
                Layout.fillWidth: true
                Layout.preferredHeight: 38
                flat: true
                padding: 0
                background: Rectangle {
                    color: closeDrawerBtn.pressed ? "#7f1d1d" : (closeDrawerBtn.hovered ? "#991b1b" : "transparent")
                    radius: 8
                    border.color: "#ef4444"
                    border.width: 1
                }
                contentItem: Text {
                    text: "Close Menu"
                    color: "#f87171"
                    font.bold: true
                    font.pixelSize: 13
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
                onClicked: sidebarOpen = false
            }
        }
    }

    // Overlay
    Rectangle {
        anchors.fill: parent
        color: "#90000000"
        z: 999
        visible: sidebarOpen
        
        MouseArea {
            anchors.fill: parent
            onClicked: sidebarOpen = false
        }
    }

    // About Modal
    Dialog {
        id: aboutModal
        x: (parent.width - width) / 2
        y: (parent.height - height) / 2
        width: 320
        modal: true
        padding: 20

        background: Rectangle {
            color: "#1e293b"
            radius: 12
            border.color: "#334155"
            border.width: 1
        }

        ColumnLayout {
            anchors.fill: parent
            spacing: 14
            Text {
                text: "MAPL Player (Native)"
                font.pixelSize: 18
                font.bold: true
                color: "white"
                horizontalAlignment: Text.AlignHCenter
                Layout.fillWidth: true
            }
            Text {
                text: "Version 1.0.0 (C++ / Qt6)"
                horizontalAlignment: Text.AlignHCenter
                color: "#94a3b8"
                font.pixelSize: 12
                Layout.fillWidth: true
            }
            Text {
                text: "Featuring offline Speech-to-Text translation via whisper.cpp."
                wrapMode: Text.WordWrap
                horizontalAlignment: Text.AlignHCenter
                color: "#cbd5e0"
                font.pixelSize: 13
                Layout.fillWidth: true
            }
            Item { Layout.preferredHeight: 8 }
            Button {
                id: closeAboutBtn
                Layout.alignment: Qt.AlignHCenter
                Layout.preferredWidth: 100
                Layout.preferredHeight: 32
                padding: 0
                background: Rectangle {
                    color: closeAboutBtn.pressed ? "#1d4ed8" : (closeAboutBtn.hovered ? "#3b82f6" : "#2563eb")
                    radius: 6
                }
                contentItem: Text {
                    text: "OK"
                    color: "white"
                    font.bold: true
                    font.pixelSize: 12
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
                onClicked: aboutModal.close()
            }
        }
    }

    // --- Helper Functions ---
    function formatTime(seconds) {
        if (isNaN(seconds) || seconds < 0) return "0:00"
        var mins = Math.floor(seconds / 60)
        var secs = Math.floor(seconds % 60)
        return mins + ":" + (secs < 10 ? "0" : "") + secs
    }

    function parseSRT(srtText) {
        var chunks = [];
        var text = srtText.replace(/\r\n/g, "\n").replace(/\r/g, "\n");
        var blocks = text.split("\n\n");
        
        for (var i = 0; i < blocks.length; i++) {
            var block = blocks[i].trim();
            if (block === "") continue;
            
            var lines = block.split("\n");
            if (lines.length < 2) continue;
            
            var timeLine = lines[1];
            var times = timeLine.split("-->");
            if (times.length !== 2) {
                timeLine = lines[0];
                times = timeLine.split("-->");
                if (times.length !== 2) continue;
                lines.unshift(""); 
            }
            
            var startStr = times[0].trim();
            var endStr = times[1].trim();
            
            var startSec = parseSRTTime(startStr);
            var endSec = parseSRTTime(endStr);
            
            var textLines = [];
            for (var j = 2; j < lines.length; j++) {
                textLines.push(lines[j]);
            }
            var textStr = textLines.join("\n").trim();
            textStr = textStr.replace(/<[^>]*>/g, "");
            
            chunks.push({
                start: startSec,
                end: endSec,
                text: textStr
            });
        }
        
        return chunks;
    }

    function parseSRTTime(timeStr) {
        var parts = timeStr.replace(",", ".").split(":");
        if (parts.length !== 3) return 0;
        
        var hours = parseFloat(parts[0]);
        var minutes = parseFloat(parts[1]);
        var seconds = parseFloat(parts[2]);
        
        return hours * 3600 + minutes * 60 + seconds;
    }

    function checkForAutoSubtitles(mediaUrl) {
        var baseStr = mediaUrl.toString();
        var lastDotIdx = baseStr.lastIndexOf(".");
        if (lastDotIdx === -1) return;
        
        var srtUrl = baseStr.substring(0, lastDotIdx) + ".srt";
        
        var request = new XMLHttpRequest()
        request.open("GET", srtUrl, true)
        request.onreadystatechange = function() {
            if (request.readyState === XMLHttpRequest.DONE) {
                if (request.status === 200 || (request.status === 0 && request.responseText !== "")) {
                    var chunks = parseSRT(request.responseText);
                    if (chunks.length > 0) {
                        subtitleChunks = chunks;
                        currentLyrics = "";
                        
                        showMessage("Auto-detected subtitles file (.srt).")
                    }
                }
            }
        }
        request.send()
    }

    function formatVttTime(seconds) {
        var hrs = Math.floor(seconds / 3600)
        var mins = Math.floor((seconds - hrs * 3600) / 60)
        var secs = Math.floor(seconds - hrs * 3600 - mins * 60)
        var ms = Math.floor((seconds % 1) * 1000)
        return (hrs < 10 ? "0" : "") + hrs + ":" + (mins < 10 ? "0" : "") + mins + ":" + (secs < 10 ? "0" : "") + secs + "." + (ms < 100 ? (ms < 10 ? "00" : "0") : "") + ms
    }

    function loadTrack(index) {
        if (index >= 0 && index < playlist.length) {
            var track = playlist[index]
            player.source = track.url
            // title now derived reactively from currentTrackIndex
            
            subtitleChunks = []
            activeSubtitleText = ""
            currentLyrics = ""
            currentTimelinePreviewSheet = ""
            
            currentTrackIndex = index
            
            var lowerUrl = track.url.toString().toLowerCase()
            var isVideo = lowerUrl.endsWith(".mp4") || lowerUrl.endsWith(".mkv") || 
                          lowerUrl.endsWith(".webm") || lowerUrl.endsWith(".avi") || 
                          lowerUrl.endsWith(".mov") || lowerUrl.endsWith(".flv") || 
                          lowerUrl.endsWith(".m4v") || lowerUrl.endsWith(".ogv") || 
                          lowerUrl.endsWith(".ts")
            currentView = isVideo ? "video" : "audio"
            
            var savedThumb = controller.getThumbnail(track.url)
            if (savedThumb !== "") {
                currentThumbnailDataUrl = "data:image/png;base64," + savedThumb
            } else {
                currentThumbnailDataUrl = ""
                resetTheme()
            }
            
            checkForAutoSubtitles(track.url)
        }
    }

    function resetTheme() {
        bgBaseColor = "#0f172a"
        containerColor = "#1e293b"
        accentColor = "#3b82f6"
    }

    function parseXspf(xmlString) {
        var tracks = []
        var trackRegex = /<track>([\s\S]*?)<\/track>/g
        var locationRegex = /<location>([\s\S]*?)<\/location>/
        var titleRegex = /<title>([\s\S]*?)<\/title>/
        var match
        while ((match = trackRegex.exec(xmlString)) !== null) {
            var trackXml = match[1]
            var locMatch = locationRegex.exec(trackXml)
            var titleMatch = titleRegex.exec(trackXml)
            if (locMatch) {
                var location = locMatch[1].trim()
                var title = titleMatch ? titleMatch[1].trim() : location.substring(location.lastIndexOf('/') + 1)
                tracks.push({ url: location, title: title })
            }
        }

        if (tracks.length > 0) {
            playlist = tracks
            currentTrackIndex = 0
            loadTrack(0)
            showMessage("Playlist loaded with " + tracks.length + " tracks.")
            currentView = "playlist"
        } else {
            showMessage("Error: No valid tracks found in XSPF.")
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
        showMessage("Subtitles shifted by " + (seconds > 0 ? "+" : "") + seconds + "s")
    }

    function formatSRTContent() {
        var srt = "";
        for (var i = 0; i < subtitleChunks.length; i++) {
            var chunk = subtitleChunks[i];
            srt += (i + 1) + "\n";
            srt += formatSRTTime(chunk.start) + " --> " + formatSRTTime(chunk.end) + "\n";
            srt += chunk.text + "\n\n";
        }
        return srt;
    }

    function formatSRTTime(seconds) {
        var hrs = Math.floor(seconds / 3600);
        var mins = Math.floor((seconds % 3600) / 60);
        var secs = Math.floor(seconds % 60);
        var ms = Math.floor((seconds % 1) * 1000);
        return pad(hrs, 2) + ":" + pad(mins, 2) + ":" + pad(secs, 2) + "," + pad(ms, 3);
    }

    function formatVTTContent() {
        var vtt = "WEBVTT\n\n";
        for (var i = 0; i < subtitleChunks.length; i++) {
            var chunk = subtitleChunks[i];
            vtt += (i + 1) + "\n";
            vtt += formatVTTTime(chunk.start) + " --> " + formatVTTTime(chunk.end) + "\n";
            vtt += chunk.text + "\n\n";
        }
        return vtt;
    }

    function formatVTTTime(seconds) {
        var hrs = Math.floor(seconds / 3600);
        var mins = Math.floor((seconds % 3600) / 60);
        var secs = Math.floor(seconds % 60);
        var ms = Math.floor((seconds % 1) * 1000);
        return pad(hrs, 2) + ":" + pad(mins, 2) + ":" + pad(secs, 2) + "." + pad(ms, 3);
    }

    function formatTXTContent() {
        if (subtitleChunks.length === 0) {
            return currentLyrics;
        }
        var txt = "";
        for (var i = 0; i < subtitleChunks.length; i++) {
            var chunk = subtitleChunks[i];
            txt += "[" + formatTime(chunk.start) + "] " + chunk.text + "\n";
        }
        return txt;
    }

    // Helper padding function
    function pad(num, size) {
        var s = num + "";
        while (s.length < size) s = "0" + s;
        return s;
    }
}
