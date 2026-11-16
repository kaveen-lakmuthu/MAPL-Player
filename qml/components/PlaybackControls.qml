import QtQuick
import QtQuick.Layouts

Rectangle {
    id: root
    objectName: "playbackControls"
    required property var app
    property bool overlay: false
    readonly property bool audioPresentation: app.mediaView === "audio" && !app.panelExpanded
    property alias seekSlider: timeline.slider
    property alias volumeSlider: transport.volumeSlider
    readonly property bool controlsHovered: hover.hovered
    readonly property bool controlsInteracting: seekSlider.pressed || volumeSlider.pressed
    onControlsHoveredChanged: {
        if (!overlay) return;
        if (controlsHovered) {
            app.controlsVisible = true;
            app.fullscreenCursorVisible = true;
        }
    }
    anchors.horizontalCenter: parent.horizontalCenter
    anchors.bottom: parent.bottom
    anchors.bottomMargin: overlay ? 12 : 0
    width: overlay ? Math.min(1000, parent.width - 24) : parent.width
    height: audioPresentation ? 116 : (overlay ? 64 : 72)
    radius: overlay ? 6 : 0
    color: overlay ? Qt.rgba(app.chromeColor.r, app.chromeColor.g, app.chromeColor.b, 0.88) : app.chromeColor
    z: 100
    opacity: overlay && !app.controlsVisible ? 0 : 1
    visible: opacity > 0
    Behavior on opacity { NumberAnimation { duration: app.reduceMotion ? 0 : 100 } }
    HoverHandler { id: hover }
    ColumnLayout {
        anchors.fill: parent
        anchors.leftMargin: root.audioPresentation ? Math.max(20, (root.width - 1000) / 2) : 12
        anchors.rightMargin: anchors.leftMargin
        anchors.topMargin: root.audioPresentation ? 8 : 2
        anchors.bottomMargin: root.audioPresentation ? 10 : (root.overlay ? 2 : 6)
        spacing: root.audioPresentation ? 8 : 0
        Timeline { id: timeline; app: root.app; Layout.fillWidth: true }
        TransportControls { id: transport; app: root.app; spacious: root.audioPresentation; Layout.fillWidth: true }
    }
}
