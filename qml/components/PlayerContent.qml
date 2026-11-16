import QtQuick
import QtQuick.Window
import QtQuick.Controls
import QtQuick.Layouts
import "../views"

Item {
    id: root
    required property var app
    property alias videoOutput: videoView.output
    property alias audioLevelIndicator: audioView.levelIndicator
    property alias transcriptListView: transcriptView.listView
    property alias seekSlider: controlsPanel.seekSlider
    property alias volumeSlider: controlsPanel.volumeSlider
    readonly property bool controlsHovered: controlsPanel.controlsHovered
    readonly property bool controlsInteracting: controlsPanel.controlsInteracting
    readonly property bool overlayControls: app.fullscreenVideo

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
            AudioView { id: audioView; app: root.app }
            VideoView { id: videoView; app: root.app }
            VolumeWheelHandler { app: root.app }

            Rectangle {
                objectName: "videoSubtitleOverlay"
                readonly property real preferredBottomMargin: Math.max(
                    Math.round(parent.height * app.subtitleBottomMarginPercent / 100),
                    root.overlayControls ? controlsPanel.height + controlsPanel.anchors.bottomMargin + 12 : 24)
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.bottom
                // Scale the reading position with the picture area and leave
                // room for tall captions without shifting when controls hide.
                anchors.bottomMargin: Math.min(preferredBottomMargin, Math.max(12, parent.height - height - 12))
                width: Math.min(parent.width - 32, subText.implicitWidth + 24)
                height: subText.implicitHeight + 12
                color: Qt.rgba(0, 0, 0, app.subtitleBgOpacity)
                radius: 4
                visible: app.mediaView === "video" && app.activeSubtitleText !== ""
                Text {
                    id: subText
                    objectName: "videoSubtitleText"
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
                spacing: 8
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.margins: 12
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
                anchors.margins: 12
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

    // Keep brief messages clear of captions and side-panel header buttons.
    Rectangle {
        objectName: "playbackNotification"
        parent: mediaSurface.visible ? mediaSurface : root
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.topMargin: parent === root ? panelHeader.height + panelHeader.anchors.topMargin + 12 : 12
        anchors.rightMargin: 12
        width: Math.min(360, parent.width - 24, messageLabel.implicitWidth + 24)
        height: messageLabel.implicitHeight + 14
        radius: 5
        color: "#e6202c38"
        visible: app.messageText !== ""
        z: 200
        Text {
            id: messageLabel
            anchors.centerIn: parent
            width: parent.width - 24
            text: app.messageText
            color: "#edf3fa"
            font.pixelSize: 12
            wrapMode: Text.Wrap
        }
    }
}
