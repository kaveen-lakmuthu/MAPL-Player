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
    
    // View state: 'audio' | 'video' | 'lyrics' | 'playlist'
    property string currentView: "audio"
    property bool sidebarOpen: false
    property string currentThumbnailDataUrl: ""
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
            messageArea.text = "Subtitles generated successfully!"
        }
        
        onErrorOccurred: (errorMsg) => {
            messageArea.text = "Error: " + errorMsg
        }
    }

    ModelDownloader {
        id: modelDownloader
        
        onProgressChanged: (progress) => {
            downloadProgressBar.value = progress
        }
        
        onDownloadFinished: (filePath) => {
            messageArea.text = "Model downloaded successfully! Ready to transcribe."
            var selected = modelSelector.currentIndex === 0 ? "tiny" : "base"
            var lang = languageSelector.currentText
            var translate = taskSelector.currentIndex === 1
            subGenerator.generateSubtitles(playlist[currentTrackIndex].url, filePath, lang, translate)
        }
        
        onDownloadError: (errorMsg) => {
            messageArea.text = "Download Error: " + errorMsg
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
            messageArea.text = "Media Error: " + errorString
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
                    if (transcriptListView.visible && transcriptListView.currentIndex !== activeIdx) {
                        transcriptListView.currentIndex = activeIdx
                        transcriptListView.positionViewAtIndex(activeIdx, ListView.Center)
                    }
                } else {
                    activeSubtitleText = ""
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
                    currentTrackTitleText.text = "Playback Finished"
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
                            messageArea.text = "Subtitles loaded."
                        } else {
                            messageArea.text = "Failed to parse subtitles file."
                        }
                    } else {
                        currentLyrics = request.responseText
                        subtitleChunks = []
                        currentView = "lyrics"
                        messageArea.text = "Lyrics loaded."
                    }
                }
            }
            request.send()
            sidebarOpen = false
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
                    messageArea.text = "Playlist loaded."
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
                    messageArea.text = "Lyrics loaded."
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
                        messageArea.text = "Subtitles loaded."
                    } else {
                        messageArea.text = "Failed to parse subtitles file."
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
            messageArea.text = "Media track loaded."
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
                            messageArea.text = "Thumbnail frame captured!"
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
                anchors.margins: 24
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
                anchors.centerIn: parent
                width: window.visibility === Window.FullScreen ? parent.width : parent.width * 0.94
                height: window.visibility === Window.FullScreen ? parent.height : parent.height * 0.82
                color: containerColor
                radius: window.visibility === Window.FullScreen ? 0 : 16
                border.color: window.visibility === Window.FullScreen ? "transparent" : "#334155"
                border.width: window.visibility === Window.FullScreen ? 0 : 1
                clip: true

                Behavior on color { ColorAnimation { duration: 400 } }



                // Dynamic Views Container
                Item {
                    id: viewsContainer
                    anchors.top: parent.top
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.bottom: (currentView === "video" && window.visibility === Window.FullScreen) ? parent.bottom : controlsPanel.top
                    anchors.margins: (currentView === "video" && window.visibility === Window.FullScreen) ? 0 : 32
                    anchors.topMargin: (currentView === "video" && window.visibility === Window.FullScreen) ? 0 : 48

                    // 2a. Audio Thumbnail View
                    Item {
                        anchors.fill: parent
                        visible: currentView === "audio"

                        ColumnLayout {
                            anchors.centerIn: parent
                            spacing: 20
                            
                            Rectangle {
                                Layout.preferredWidth: 280
                                Layout.preferredHeight: 280
                                Layout.alignment: Qt.AlignHCenter
                                color: "#090d16"
                                radius: 16
                                border.color: accentColor !== "" ? accentColor : "#334155"
                                border.width: 2
                                clip: true

                                // Styled rich gradient background for placeholder
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
                                    font.pixelSize: 80
                                    visible: currentThumbnailDataUrl === ""
                                    opacity: 0.45
                                }
                            }

                            Text {
                                id: currentTrackTitleText
                                text: "No file loaded"
                                color: "white"
                                font.pixelSize: 16
                                font.bold: true
                                Layout.fillWidth: true
                                Layout.alignment: Qt.AlignHCenter
                                horizontalAlignment: Text.AlignHCenter
                                elide: Text.ElideRight
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
                                    controlsVisible = true
                                    controlsHideTimer.restart()
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
                            
                            Rectangle {
                                anchors.bottom: parent.bottom
                                anchors.horizontalCenter: parent.horizontalCenter
                                anchors.bottomMargin: 20
                                width: Math.min(parent.width - 48, subText.implicitWidth + 32)
                                height: subText.implicitHeight + 16
                                color: "#cc0f172a"
                                radius: 8
                                border.color: "#334155"
                                border.width: 1
                                visible: activeSubtitleText !== ""
                                z: 10 // Ensure subtitles render on top of MouseArea

                                Text {
                                    id: subText
                                    anchors.centerIn: parent
                                    text: activeSubtitleText
                                    color: "white"
                                    font.pixelSize: 15
                                    font.bold: true
                                    wrapMode: Text.WordWrap
                                    horizontalAlignment: Text.AlignHCenter
                                }
                            }
                        }
                    }

                    // 2c. Combined Lyrics and Synced Subtitles View
                    Item {
                        anchors.fill: parent
                        visible: currentView === "lyrics"

                        // Sub-header buttons
                        RowLayout {
                            id: textHeader
                            anchors.top: parent.top
                            anchors.right: parent.right
                            z: 10
                            spacing: 8
                            visible: subtitleChunks.length > 0 || currentLyrics !== ""

                            Button {
                                id: loadTextFileBtn
                                flat: true
                                Layout.preferredHeight: 28
                                padding: 0
                                background: Rectangle {
                                    color: loadTextFileBtn.pressed ? "#1e293b" : (loadTextFileBtn.hovered ? "#334155" : "transparent")
                                    radius: 6
                                    border.color: "#475569"
                                    border.width: 1
                                }
                                contentItem: Text {
                                    text: "📄 Load text file"
                                    color: "white"
                                    font.pixelSize: 11
                                    horizontalAlignment: Text.AlignHCenter
                                    verticalAlignment: Text.AlignVCenter
                                    leftPadding: 8
                                    rightPadding: 8
                                }
                                onClicked: lyricsFileDialog.open()
                            }

                            Button {
                                id: clearSubsBtn
                                flat: true
                                Layout.preferredHeight: 28
                                padding: 0
                                background: Rectangle {
                                    color: clearSubsBtn.pressed ? "#991b1b" : (clearSubsBtn.hovered ? "#7f1d1d" : "transparent")
                                    radius: 6
                                    border.color: "#991b1b"
                                    border.width: 1
                                }
                                contentItem: Text {
                                    text: "🗑️ Clear view"
                                    color: "#fca5a5"
                                    font.pixelSize: 11
                                    horizontalAlignment: Text.AlignHCenter
                                    verticalAlignment: Text.AlignVCenter
                                    leftPadding: 8
                                    rightPadding: 8
                                }
                                onClicked: {
                                    subtitleChunks = []
                                    currentLyrics = ""
                                }
                            }
                        }

                        // Case A: Sync Subtitle List (Dynamic height and clean padding)
                        ListView {
                            id: transcriptListView
                            anchors.fill: parent
                            anchors.topMargin: 32
                            visible: subtitleChunks.length > 0
                            clip: true
                            model: subtitleChunks
                            
                            highlightRangeMode: ListView.ApplyRange
                            preferredHighlightBegin: parent.height / 3
                            preferredHighlightEnd: parent.height / 2

                            delegate: ItemDelegate {
                                width: transcriptListView.width
                                implicitHeight: contentLayout.implicitHeight + 16
                                padding: 8
                                property bool isActive: index === transcriptListView.currentIndex

                                contentItem: RowLayout {
                                    id: contentLayout
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
                                    color: isActive ? Qt.rgba(59, 130, 246, 0.15) : (hovered ? "#334155" : "transparent")
                                    radius: 8
                                    border.color: isActive ? "#3b82f6" : "transparent"
                                    border.width: 1
                                }
                                onClicked: {
                                    player.position = modelData.start * 1000.0
                                }
                            }
                        }

                        // Case B: Scrollable plain lyrics sheet
                        ScrollView {
                            anchors.fill: parent
                            anchors.topMargin: 32
                            visible: subtitleChunks.length === 0 && currentLyrics !== ""
                            clip: true

                            Text {
                                width: parent.width
                                text: currentLyrics
                                color: "#f8fafc"
                                font.pixelSize: 15
                                lineHeight: 1.5
                                horizontalAlignment: Text.AlignHCenter
                                wrapMode: Text.WordWrap
                            }
                        }

                        // Case C: Unloaded state (Generator Interface)
                        Item {
                            anchors.fill: parent
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
                                        text: "📂 Load plain lyrics (.txt)"
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

                // Bottom Controls area Panel (for contrast guard in fullscreen)
                Rectangle {
                    id: controlsPanel
                    anchors.bottom: parent.bottom
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.margins: window.visibility === Window.FullScreen ? 16 : 24
                    height: controlsContainer.implicitHeight + (window.visibility === Window.FullScreen ? 24 : 0)
                    color: window.visibility === Window.FullScreen ? Qt.rgba(15/255.0, 23/255.0, 42/255.0, 0.92) : "transparent"
                    radius: 12
                    border.color: window.visibility === Window.FullScreen ? "#1e293b" : "transparent"
                    border.width: window.visibility === Window.FullScreen ? 1 : 0
                    z: 100
                    
                    opacity: (window.visibility === Window.FullScreen) ? (controlsVisible ? 1.0 : 0.0) : 1.0
                    Behavior on opacity {
                        NumberAnimation { duration: 300 }
                    }
                    visible: opacity > 0.0

                    HoverHandler {
                        id: controlsHoverHandler
                    }

                    ColumnLayout {
                        id: controlsContainer
                        anchors.fill: parent
                        anchors.margins: window.visibility === Window.FullScreen ? 12 : 0
                        spacing: 12

                        // Seekbar Slider
                        RowLayout {
                            spacing: 12
                            Layout.fillWidth: true

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

                            Text {
                                text: player.duration > 0 ? ("-" + formatTime(Math.max(0, player.duration - player.position) / 1000.0) + " / " + formatTime(player.duration / 1000.0)) : "0:00"
                                color: "#94a3b8"
                                font.pixelSize: 11
                                font.bold: true
                            }
                        }

                        Item {
                            id: bottomButtonsBar
                            Layout.fillWidth: true
                            implicitHeight: 48
                            
                            // Bottom right controls anchor (for fullscreen)
                            Item {
                                id: bottomRowAnchorItem
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                width: rightControlsLayout.implicitWidth
                                height: 32
                            }
                            
                            // Audio / Video Toggle
                            RowLayout {
                                spacing: 8
                                anchors.left: parent.left
                                anchors.verticalCenter: parent.verticalCenter
                                
                                Button {
                                    id: audioModeBtn
                                    flat: true
                                    Layout.preferredWidth: 72
                                    Layout.preferredHeight: 32
                                    padding: 0
                                    scale: audioModeBtn.hovered ? 1.03 : 1.0
                                    Behavior on scale { NumberAnimation { duration: 100 } }
                                    background: Rectangle {
                                        gradient: Gradient {
                                            GradientStop { position: 0.0; color: currentView === "audio" ? "#3b82f6" : "#1e293b" }
                                            GradientStop { position: 1.0; color: currentView === "audio" ? "#1d4ed8" : "#0f172a" }
                                        }
                                        radius: 6
                                        border.color: currentView === "audio" ? "#60a5fa" : "#475569"
                                        border.width: 1
                                    }
                                    contentItem: Text {
                                        text: "Audio"
                                        color: "white"
                                        font.bold: true
                                        font.pixelSize: 13
                                        horizontalAlignment: Text.AlignHCenter
                                        verticalAlignment: Text.AlignVCenter
                                    }
                                    onClicked: currentView = "audio"
                                }
                                Button {
                                    id: videoModeBtn
                                    flat: true
                                    enabled: currentTrackIndex !== -1
                                    Layout.preferredWidth: 72
                                    Layout.preferredHeight: 32
                                    padding: 0
                                    scale: videoModeBtn.hovered && videoModeBtn.enabled ? 1.03 : 1.0
                                    Behavior on scale { NumberAnimation { duration: 100 } }
                                    background: Rectangle {
                                        gradient: Gradient {
                                            GradientStop { position: 0.0; color: currentView === "video" ? "#3b82f6" : "#1e293b" }
                                            GradientStop { position: 1.0; color: currentView === "video" ? "#1d4ed8" : "#0f172a" }
                                        }
                                        radius: 6
                                        border.color: currentView === "video" ? "#60a5fa" : "#475569"
                                        border.width: 1
                                        opacity: videoModeBtn.enabled ? 1.0 : 0.4
                                    }
                                    contentItem: Text {
                                        text: "Video"
                                        color: "white"
                                        font.bold: true
                                        font.pixelSize: 13
                                        horizontalAlignment: Text.AlignHCenter
                                        verticalAlignment: Text.AlignVCenter
                                    }
                                    onClicked: currentView = "video"
                                }
                            }

                            // Playback Control Buttons (Centered)
                            RowLayout {
                                id: playbackControlsLayout
                                spacing: 12
                                anchors.horizontalCenter: parent.horizontalCenter
                                anchors.verticalCenter: parent.verticalCenter

                                Button {
                                    id: prevBtn
                                    flat: true
                                    implicitWidth: 36
                                    implicitHeight: 36
                                    scale: prevBtn.hovered ? 1.05 : 1.0
                                    Behavior on scale { NumberAnimation { duration: 100 } }
                                    padding: 0
                                    leftPadding: 0
                                    rightPadding: 0
                                    topPadding: 0
                                    bottomPadding: 0
                                    
                                    background: Rectangle {
                                        radius: 18
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
                                            var iconW = 11;
                                            var iconH = 12;
                                            var cx = w / 2;
                                            var cy = h / 2;
                                            var left = cx - iconW / 2;
                                            var top = cy - iconH / 2;
                                            var right = left + iconW;
                                            var bottom = top + iconH;

                                            // Draw vertical bar on the left
                                            ctx.fillRect(left, top, 2.5, iconH);

                                            // Draw left-pointing triangle
                                            ctx.beginPath();
                                            ctx.moveTo(left + 4.5, cy);
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
                                    implicitWidth: 36
                                    implicitHeight: 36
                                    scale: back5sBtn.hovered ? 1.05 : 1.0
                                    Behavior on scale { NumberAnimation { duration: 100 } }
                                    padding: 0
                                    leftPadding: 0
                                    rightPadding: 0
                                    topPadding: 0
                                    bottomPadding: 0
                                    
                                    background: Rectangle {
                                        radius: 18
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
                                            ctx.lineWidth = 1.8;
                                            ctx.lineCap = "round";
                                            ctx.lineJoin = "round";
                                            
                                            var cx = width / 2;
                                            var cy = height / 2;
                                            
                                            ctx.beginPath();
                                            ctx.arc(cx, cy, 8, 1.7 * Math.PI, 0.35 * Math.PI, true); // counter-clockwise
                                            ctx.stroke();
                                            
                                            // Arrowhead at 1.7 * Math.PI
                                            var ax = cx + 8 * Math.cos(1.7 * Math.PI);
                                            var ay = cy + 8 * Math.sin(1.7 * Math.PI);
                                            ctx.beginPath();
                                            ctx.moveTo(ax - 3, ay - 2);
                                            ctx.lineTo(ax, ay);
                                            ctx.lineTo(ax + 2, ay + 3);
                                            ctx.stroke();
                                            
                                            ctx.font = "bold 9px sans-serif";
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
                                    implicitWidth: 36
                                    implicitHeight: 36
                                    scale: forward5sBtn.hovered ? 1.05 : 1.0
                                    Behavior on scale { NumberAnimation { duration: 100 } }
                                    padding: 0
                                    leftPadding: 0
                                    rightPadding: 0
                                    topPadding: 0
                                    bottomPadding: 0
                                    
                                    background: Rectangle {
                                        radius: 18
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
                                            ctx.lineWidth = 1.8;
                                            ctx.lineCap = "round";
                                            ctx.lineJoin = "round";
                                            
                                            var cx = width / 2;
                                            var cy = height / 2;
                                            
                                            ctx.beginPath();
                                            ctx.arc(cx, cy, 8, 1.3 * Math.PI, 0.65 * Math.PI, false); // clockwise
                                            ctx.stroke();
                                            
                                            // Arrowhead at 1.3 * Math.PI
                                            var ax = cx + 8 * Math.cos(1.3 * Math.PI);
                                            var ay = cy + 8 * Math.sin(1.3 * Math.PI);
                                            ctx.beginPath();
                                            ctx.moveTo(ax + 3, ay - 2);
                                            ctx.lineTo(ax, ay);
                                            ctx.lineTo(ax - 2, ay + 3);
                                            ctx.stroke();
                                            
                                            ctx.font = "bold 9px sans-serif";
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
                                    implicitWidth: 36
                                    implicitHeight: 36
                                    scale: nextBtn.hovered ? 1.05 : 1.0
                                    Behavior on scale { NumberAnimation { duration: 100 } }
                                    padding: 0
                                    leftPadding: 0
                                    rightPadding: 0
                                    topPadding: 0
                                    bottomPadding: 0
                                    
                                    background: Rectangle {
                                        radius: 18
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
                                            var iconW = 11;
                                            var iconH = 12;
                                            var cx = w / 2;
                                            var cy = h / 2;
                                            var left = cx - iconW / 2;
                                            var top = cy - iconH / 2;
                                            var right = left + iconW;
                                            var bottom = top + iconH;

                                            // Draw right-pointing triangle
                                            ctx.beginPath();
                                            ctx.moveTo(right - 4.5, cy);
                                            ctx.lineTo(left, top);
                                            ctx.lineTo(left, bottom);
                                            ctx.closePath();
                                            ctx.fill();

                                            // Draw vertical bar on the right
                                            ctx.fillRect(right - 2.5, top, 2.5, iconH);
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

                            RowLayout {
                                id: rightControlsLayout
                                parent: window.visibility === Window.FullScreen ? bottomRowAnchorItem : centralPlayerBox
                                spacing: 12
                                z: parent === centralPlayerBox ? 200 : 1
                                
                                anchors.top: parent === centralPlayerBox ? parent.top : undefined
                                anchors.right: parent.right
                                anchors.margins: parent === centralPlayerBox ? 18 : 0
                                anchors.verticalCenter: parent === bottomRowAnchorItem ? parent.verticalCenter : undefined
                                
                                opacity: (window.visibility === Window.FullScreen) ? (controlsVisible ? 1.0 : 0.0) : 1.0
                                Behavior on opacity {
                                    NumberAnimation { duration: 300 }
                                }
                                visible: opacity > 0.0
                                
                                // Loop Toggle (Flat circle with Canvas vector icon)
                                Button {
                                    id: loopToggleBtn
                                    flat: true
                                    implicitWidth: 32
                                    implicitHeight: 32
                                    padding: 0
                                    leftPadding: 0
                                    rightPadding: 0
                                    topPadding: 0
                                    bottomPadding: 0
                                    property bool looping: controller.loadLoop()
                                    property color iconColor: looping ? "#60a5fa" : (loopToggleBtn.hovered ? "#60a5fa" : "#94a3b8")
                                    
                                    background: Rectangle {
                                        color: loopToggleBtn.pressed ? Qt.rgba(255, 255, 255, 0.1) : (loopToggleBtn.hovered ? Qt.rgba(255, 255, 255, 0.05) : "transparent")
                                        radius: 16
                                    }
                                    
                                    contentItem: Canvas {
                                        id: loopIconCanvas
                                        onWidthChanged: requestPaint()
                                        onHeightChanged: requestPaint()
                                        onPaint: {
                                            var ctx = getContext("2d");
                                            ctx.reset();
                                            ctx.strokeStyle = loopToggleBtn.iconColor;
                                            ctx.lineWidth = 1.8;
                                            ctx.lineCap = "round";
                                            ctx.lineJoin = "round";
                                            
                                            var w = width;
                                            var h = height;
                                            var cx = w / 2;
                                            var cy = h / 2;
                                            
                                            // Path 1 (top half, left arrow)
                                            ctx.beginPath();
                                            ctx.moveTo(cx + 5, cy - 4);
                                            ctx.lineTo(cx - 3, cy - 4);
                                            ctx.arcTo(cx - 7, cy - 4, cx - 7, cy, 4);
                                            ctx.lineTo(cx - 7, cy + 2);
                                            ctx.stroke();
                                            
                                            // Arrow head (pointing left)
                                            ctx.beginPath();
                                            ctx.moveTo(cx, cy - 7);
                                            ctx.lineTo(cx - 3, cy - 4);
                                            ctx.lineTo(cx, cy - 1);
                                            ctx.stroke();

                                            // Path 2 (bottom half, right arrow)
                                            ctx.beginPath();
                                            ctx.moveTo(cx - 5, cy + 4);
                                            ctx.lineTo(cx + 3, cy + 4);
                                            ctx.arcTo(cx + 7, cy + 4, cx + 7, cy, 4);
                                            ctx.lineTo(cx + 7, cy - 2);
                                            ctx.stroke();
                                            
                                            // Arrow head (pointing right)
                                            ctx.beginPath();
                                            ctx.moveTo(cx, cy + 1);
                                            ctx.lineTo(cx + 3, cy + 4);
                                            ctx.lineTo(cx, cy + 7);
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
                                    Layout.preferredHeight: 32
                                    width: Layout.preferredWidth
                                    height: 32
                                    hoverEnabled: true

                                    RowLayout {
                                        id: volumeLayout
                                        spacing: 8
                                        anchors.verticalCenter: parent.verticalCenter

                                        Button {
                                            id: volumeIconBtn
                                            flat: true
                                            implicitWidth: 32
                                            implicitHeight: 32
                                            padding: 0
                                            leftPadding: 0
                                            rightPadding: 0
                                            topPadding: 0
                                            bottomPadding: 0
                                            property color iconColor: volumeHoverArea.containsMouse || volumeIconBtn.hovered ? "#60a5fa" : "#94a3b8"
                                            
                                            background: Rectangle {
                                                color: volumeIconBtn.pressed ? Qt.rgba(255, 255, 255, 0.1) : (volumeIconBtn.hovered ? Qt.rgba(255, 255, 255, 0.05) : "transparent")
                                                radius: 16
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
                                                    ctx.lineWidth = 1.5;
                                                    ctx.lineCap = "round";
                                                    
                                                    var w = width;
                                                    var h = height;
                                                    var cx = w / 2;
                                                    var cy = h / 2;
                                                    var left = cx - 7;
                                                    var speakerRight = left + 7;
                                                    
                                                    // Speaker body
                                                    ctx.beginPath();
                                                    ctx.moveTo(left, cy - 3);
                                                    ctx.lineTo(left + 3, cy - 3);
                                                    ctx.lineTo(speakerRight, cy - 6);
                                                    ctx.lineTo(speakerRight, cy + 6);
                                                    ctx.lineTo(left + 3, cy + 3);
                                                    ctx.lineTo(left, cy + 3);
                                                    ctx.closePath();
                                                    ctx.fill();
                                                    
                                                    // Sound waves
                                                    var vol = isMuted ? 0 : volumeSlider.value
                                                    if (vol > 0) {
                                                        ctx.beginPath();
                                                        ctx.arc(speakerRight, cy, 4, -Math.PI/4, Math.PI/4, false);
                                                        ctx.stroke();
                                                    }
                                                    if (vol > 50) {
                                                        ctx.beginPath();
                                                        ctx.arc(speakerRight, cy, 7, -Math.PI/4, Math.PI/4, false);
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
                                            Layout.preferredHeight: 32
                                            width: targetWidth
                                            height: 32
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
                                            font.pixelSize: 11
                                            font.bold: true
                                            Layout.alignment: Qt.AlignVCenter
                                        }
                                    }
                                }

                                // Fullscreen Toggle Button
                                Button {
                                    id: fullscreenBtn
                                    flat: true
                                    implicitWidth: 32
                                    implicitHeight: 32
                                    padding: 0
                                    leftPadding: 0
                                    rightPadding: 0
                                    topPadding: 0
                                    bottomPadding: 0
                                    
                                    background: Rectangle {
                                        color: fullscreenBtn.pressed ? Qt.rgba(255, 255, 255, 0.1) : (fullscreenBtn.hovered ? Qt.rgba(255, 255, 255, 0.05) : "transparent")
                                        radius: 16
                                    }
                                    
                                    contentItem: Canvas {
                                        id: fullscreenIconCanvas
                                        onWidthChanged: requestPaint()
                                        onHeightChanged: requestPaint()
                                        onPaint: {
                                            var ctx = getContext("2d");
                                            ctx.reset();
                                            ctx.strokeStyle = fullscreenBtn.hovered ? "#60a5fa" : "#94a3b8";
                                            ctx.lineWidth = 1.8;
                                            ctx.lineCap = "round";
                                            ctx.lineJoin = "round";
                                            
                                            var cx = width / 2;
                                            var cy = height / 2;
                                            var isFS = window.visibility === Window.FullScreen;
                                            
                                            if (!isFS) {
                                                // Outward corners
                                                // Top-left
                                                ctx.beginPath();
                                                ctx.moveTo(cx - 3, cy - 7);
                                                ctx.lineTo(cx - 7, cy - 7);
                                                ctx.lineTo(cx - 7, cy - 3);
                                                ctx.stroke();
                                                // Top-right
                                                ctx.beginPath();
                                                ctx.moveTo(cx + 3, cy - 7);
                                                ctx.lineTo(cx + 7, cy - 7);
                                                ctx.lineTo(cx + 7, cy - 3);
                                                ctx.stroke();
                                                // Bottom-left
                                                ctx.beginPath();
                                                ctx.moveTo(cx - 3, cy + 7);
                                                ctx.lineTo(cx - 7, cy + 7);
                                                ctx.lineTo(cx - 7, cy + 3);
                                                ctx.stroke();
                                                // Bottom-right
                                                ctx.beginPath();
                                                ctx.moveTo(cx + 3, cy + 7);
                                                ctx.lineTo(cx + 7, cy + 7);
                                                ctx.lineTo(cx + 7, cy + 3);
                                                ctx.stroke();
                                            } else {
                                                // Inward corners
                                                // Top-left
                                                ctx.beginPath();
                                                ctx.moveTo(cx - 7, cy - 3);
                                                ctx.lineTo(cx - 3, cy - 3);
                                                ctx.lineTo(cx - 3, cy - 7);
                                                ctx.stroke();
                                                // Top-right
                                                ctx.beginPath();
                                                ctx.moveTo(cx + 7, cy - 3);
                                                ctx.lineTo(cx + 3, cy - 3);
                                                ctx.lineTo(cx + 3, cy - 7);
                                                ctx.stroke();
                                                // Bottom-left
                                                ctx.beginPath();
                                                ctx.moveTo(cx - 7, cy + 3);
                                                ctx.lineTo(cx - 3, cy + 3);
                                                ctx.lineTo(cx - 3, cy + 7);
                                                ctx.stroke();
                                                // Bottom-right
                                                ctx.beginPath();
                                                ctx.moveTo(cx + 7, cy + 3);
                                                ctx.lineTo(cx + 3, cy + 3);
                                                ctx.lineTo(cx + 3, cy + 7);
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

                        // Message Area (inside layout card for clean contrast layout)
                        Text {
                            id: messageArea
                            Layout.alignment: Qt.AlignHCenter
                            color: "#ef4444"
                            font.pixelSize: 12
                            font.bold: true
                            visible: text !== ""
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
                        currentView = "lyrics";
                        messageArea.text = "Auto-detected subtitles file (.srt).";
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
            currentTrackTitleText.text = track.title
            
            subtitleChunks = []
            activeSubtitleText = ""
            currentLyrics = ""
            
            currentTrackIndex = index
            
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
            messageArea.text = "Playlist loaded with " + tracks.length + " tracks."
            currentView = "playlist"
        } else {
            messageArea.text = "Error: No valid tracks found in XSPF."
        }
    }
}
