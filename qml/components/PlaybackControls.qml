import QtQuick
import QtQuick.Layouts

Rectangle {
    id: root
    required property var app
    property bool overlay: false
    property alias seekSlider: timeline.slider
    property alias volumeSlider: transport.volumeSlider
    readonly property bool controlsHovered: hover.hovered
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.bottom: parent.bottom
    height: 72
    color: app.chromeColor
    z: 100
    opacity: overlay && !app.controlsVisible ? 0 : 1
    visible: opacity > 0
    Behavior on opacity { NumberAnimation { duration: app.reduceMotion ? 0 : 180 } }
    HoverHandler { id: hover }
    ColumnLayout {
        anchors.fill: parent
        anchors.leftMargin: 12
        anchors.rightMargin: 12
        anchors.topMargin: 2
        anchors.bottomMargin: 6
        spacing: 0
        Timeline { id: timeline; app: root.app; Layout.fillWidth: true }
        TransportControls { id: transport; app: root.app; Layout.fillWidth: true }
    }
}
