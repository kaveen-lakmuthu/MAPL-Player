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
    readonly property bool overlayControls: app.visibility === Window.FullScreen && app.mediaView === "video" && !app.panelExpanded

    RowLayout {
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: root.overlayControls ? parent.bottom : controlsPanel.top
        spacing: 0

        Rectangle {
            id: mediaSurface
            objectName: "playerSurface"
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: !app.panelExpanded
            clip: true
            color: app.mediaView === "video" ? "#000000" : app.bgBaseColor
            // Keep the same VideoOutput alive while opening panels or changing views.
            AudioView { app: root.app }
            VideoView { id: videoView; app: root.app }
            VolumeWheelHandler { app: root.app }

            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.bottom
                anchors.bottomMargin: root.overlayControls && controlsPanel.visible ? controlsPanel.height + 12 : 16
                width: Math.min(parent.width - 32, subText.implicitWidth + 24)
                height: subText.implicitHeight + 12
                color: Qt.rgba(0, 0, 0, app.subtitleBgOpacity)
                radius: 4
                visible: app.mediaView === "video" && app.activeSubtitleText !== ""
                Text {
                    id: subText
                    anchors.centerIn: parent
                    width: parent.width - 24
                    text: app.activeSubtitleText
                    color: app.subtitleTextColor
                    font.pixelSize: app.subtitleFontSize
                    font.bold: true
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.WordWrap
                }
            }
        }

        Rectangle {
            objectName: "sidePanel"
            Layout.fillHeight: true
            Layout.fillWidth: app.panelExpanded
            Layout.preferredWidth: app.panelExpanded ? -1 : Math.min(360, Math.max(290, root.width * 0.29))
            visible: app.panelView !== ""
            color: app.containerColor

            RowLayout {
                id: panelHeader
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.margins: 8
                height: 30
                Text {
                    text: app.panelView === "lyrics" ? "Lyrics & Subs" : "Playlist · " + app.playlist.length
                    color: "#edf3fa"
                    font.pixelSize: 12
                    font.bold: true
                    Layout.fillWidth: true
                }
                DesktopButton {
                    objectName: "expandPanelButton"
                    glyph: app.panelExpanded ? "restore" : "expand"
                    hint: app.panelExpanded ? "Return to side panel" : "Expand panel"
                    onClicked: app.setPanelExpanded(!app.panelExpanded)
                }
                DesktopButton { objectName: "closePanelButton"; glyph: "close"; hint: "Close panel"; onClicked: app.closePanel() }
            }
            Item {
                anchors.top: panelHeader.bottom
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.margins: 8
                TranscriptView { id: transcriptView; app: root.app }
                PlaylistView { app: root.app }
            }
        }
    }

    PlaybackControls {
        id: controlsPanel
        app: root.app
        overlay: root.overlayControls
    }

    // Notifications and long-running jobs do not resize the picture or controls.
    Rectangle {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: controlsPanel.top
        anchors.bottomMargin: 10
        width: Math.min(parent.width - 24, messageLabel.implicitWidth + 24)
        height: messageLabel.implicitHeight + 14
        radius: 5
        color: "#e6202c38"
        visible: app.messageText !== ""
        z: 200
        Text {
            id: messageLabel
            anchors.centerIn: parent
            width: Math.min(implicitWidth, root.width - 48)
            text: app.messageText
            color: "#edf3fa"
            font.pixelSize: 12
            wrapMode: Text.WordWrap
        }
    }
    DesktopButton {
        objectName: "cancelSubtitleGeneration"
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.margins: 8
        visible: app.subtitleGenerator.isProcessing
        enabled: !app.subtitleGenerator.isCancelling
        text: app.subtitleGenerator.isCancelling ? "Cancelling…" : "Transcribing " + Math.round(app.transcriptionProgressValue) + "% · Cancel"
        hint: "Cancel subtitle generation"
        onClicked: app.cancelSubtitleGeneration()
        z: 201
    }
}
