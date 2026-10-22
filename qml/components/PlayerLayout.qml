import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

RowLayout {
    id: root
    required property var app
    readonly property real sidebarWidth: leftPanel.width
    property alias videoOutput: playerContent.videoOutput
    property alias transcriptListView: playerContent.transcriptListView
    property alias seekSlider: playerContent.seekSlider
    property alias volumeSlider: playerContent.volumeSlider
    readonly property bool controlsHovered: playerContent.controlsHovered

    anchors.fill: parent
    spacing: 0

    // 1. Left Fixed Vertical Panel (Always Visible)
    NavigationSidebar {
        id: leftPanel
        app: root.app
    }

    // 2. Main Content Wrapper
    PlayerContent {
        id: playerContent
        app: root.app
    }
}
