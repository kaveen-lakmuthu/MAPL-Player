import QtQuick
import QtQuick.Window
import QtQuick.Controls
import QtQuick.Layouts
import "../views"

Item {
    id: root
    required property var app
    property alias videoOutput: videoView.output
    property alias transcriptListView: transcriptView.listView
    property alias seekSlider: controlsPanel.seekSlider
    property alias volumeSlider: controlsPanel.volumeSlider
    readonly property bool controlsHovered: controlsPanel.controlsHovered

    Layout.fillWidth: true
    Layout.fillHeight: true

    Button {
        objectName: "cancelSubtitleGeneration"
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.margins: 10
        z: 200
        visible: app.subtitleGenerator.isProcessing
        enabled: !app.subtitleGenerator.isCancelling
        text: app.subtitleGenerator.isCancelling ? "Cancelling…" : "Cancel transcription"
        onClicked: app.cancelSubtitleGeneration()
    }

    // Global Title
    RowLayout {
        id: titleLayout
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.topMargin: 12
        anchors.leftMargin: (app.visibility === Window.FullScreen ? 0 : (app.currentView === "video" ? parent.width * 0.01 : parent.width * 0.03) + 8)
        spacing: 12
        z: 100
        visible: app.visibility !== Window.FullScreen

        // Expand button — only visible when sidebar is collapsed
        Button {
            id: toggleSidebarBtn
            implicitWidth: 32
            implicitHeight: 32
            flat: true
            padding: 0
            Layout.alignment: Qt.AlignVCenter
            visible: !app.sidebarExpanded

            background: Rectangle {
                color: toggleSidebarBtn.hovered ? "#1e293b" : "transparent"
                radius: 6
                border.color: toggleSidebarBtn.hovered ? "#334155" : "transparent"
                border.width: 1
            }

            contentItem: Text {
                text: "☰"
                color: toggleSidebarBtn.hovered ? "white" : "#94a3b8"
                font.pixelSize: 18
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
            }

            onClicked: app.sidebarExpanded = true
        }

        Text {
            text: app.currentView === "video" ? "📺" : (app.currentView === "lyrics" ? "📝" : "🎵")
            font.pixelSize: 22
        }
        Text {
            text: app.currentView === "video" ? "Video View" : (app.currentView === "lyrics" ? "Lyrics & Subtitles" : "Audio View")
            color: "white"
            font.pixelSize: 20
            font.bold: true
            font.letterSpacing: 0.5
        }
    }

    // Central Player Box Container
    Rectangle {
        id: centralPlayerBox
        objectName: "playerSurface"
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        anchors.topMargin: app.visibility === Window.FullScreen ? 0 : 48
        // Video mode: use most of the available space; other modes keep a little breathing room
        width: app.visibility === Window.FullScreen ? parent.width : (app.currentView === "video" ? parent.width * 0.98 : parent.width * 0.94)
        height: app.visibility === Window.FullScreen ? parent.height : (app.currentView === "video" ? parent.height - 64 : parent.height - 72)
        color: app.containerColor
        radius: app.visibility === Window.FullScreen ? 0 : 16
        border.color: app.visibility === Window.FullScreen ? "transparent" : "#334155"
        border.width: app.visibility === Window.FullScreen ? 0 : 1
        clip: true

        VolumeWheelHandler {
            app: root.app
            acceptsVolume: app.currentView === "audio" || app.currentView === "video"
        }

        Behavior on color {
            ColorAnimation {
                duration: 400
            }
        }
        // No separate width/height Behavior — centralPlayerBox is a percentage child
        // of the RowLayout's right Item, which already reflows smoothly with leftPanel.

        // Dynamic Views Container
        Item {
            id: viewsContainer
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: (app.currentView === "video" && app.visibility === Window.FullScreen) ? parent.bottom : controlsPanel.top
            // Video mode: minimal inset so the video uses max space
            anchors.margins: (app.currentView === "video") ? 0 : 24
            anchors.topMargin: (app.currentView === "video") ? 0 : 36

            // 2a. Audio View — full-area immersive layout
            AudioView {
                app: root.app
            }

            // 2b. Native Video View
            VideoView {
                id: videoView
                app: root.app
            }

            // 2c. Combined Lyrics and Synced Subtitles View
            TranscriptView {
                id: transcriptView
                app: root.app
            }

            // 2d. Playlist View

            // 2d. Playlist View
            PlaylistView {
                app: root.app
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
            color: Qt.rgba(15 / 255.0, 23 / 255.0, 42 / 255.0, app.subtitleBgOpacity)
            radius: 8
            border.color: "#334155"
            border.width: 1
            visible: (app.currentView === "video") && app.activeSubtitleText !== ""
            z: 50

            Text {
                id: subText
                anchors.centerIn: parent
                width: parent.width - 32
                text: app.activeSubtitleText
                color: app.subtitleTextColor
                font.pixelSize: app.subtitleFontSize
                font.bold: true
                font.family: "Inter, Noto Sans Sinhala, Noto Sans, sans-serif"
                wrapMode: Text.WordWrap
                horizontalAlignment: Text.AlignHCenter
            }
        }

        // Bottom Controls area Panel (for contrast guard in fullscreen)
        PlaybackControls {
            id: controlsPanel
            app: root.app
        }
    }
}
