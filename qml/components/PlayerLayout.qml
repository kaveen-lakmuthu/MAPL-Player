import QtQuick
import QtQuick.Window
import QtQuick.Layouts

ColumnLayout {
    id: root
    required property var app
    property alias videoOutput: playerContent.videoOutput
    property alias audioLevelIndicator: playerContent.audioLevelIndicator
    property alias transcriptListView: playerContent.transcriptListView
    property alias seekSlider: playerContent.seekSlider
    property alias volumeSlider: playerContent.volumeSlider
    readonly property bool controlsHovered: playerContent.controlsHovered
    readonly property bool controlsInteracting: playerContent.controlsInteracting
    readonly property bool menuOpen: toolbar.menuOpen
    anchors.fill: parent
    spacing: 0

    DesktopToolbar {
        id: toolbar
        app: root.app
        Layout.fillWidth: true
        visible: app.visibility !== Window.FullScreen || app.mediaView === "audio"
    }
    PlayerContent {
        id: playerContent
        app: root.app
        Layout.fillWidth: true
        Layout.fillHeight: true
    }
}
