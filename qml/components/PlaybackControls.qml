import QtQuick
import QtQuick.Window
import QtQuick.Controls
import QtQuick.Layouts

Rectangle {
    id: root
    required property var app
    property alias seekSlider: timeline.slider
    property alias volumeSlider: transportControls.volumeSlider
    readonly property bool controlsHovered: controlsHoverHandler.hovered

    anchors.bottom: parent.bottom
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.margins: (app.visibility === Window.FullScreen || app.currentView === "video") ? 16 : 24
    height: controlsContainer.implicitHeight + ((app.visibility === Window.FullScreen || app.currentView === "video") ? 24 : 0)
    color: (app.visibility === Window.FullScreen || app.currentView === "video") ? Qt.rgba(15 / 255.0, 23 / 255.0, 42 / 255.0, 0.92) : "transparent"
    radius: 12
    border.color: (app.visibility === Window.FullScreen || app.currentView === "video") ? "#1e293b" : "transparent"
    border.width: (app.visibility === Window.FullScreen || app.currentView === "video") ? 1 : 0
    z: 100

    opacity: (app.visibility === Window.FullScreen) ? (app.controlsVisible ? 1.0 : 0.0) : 1.0
    Behavior on opacity {
        NumberAnimation {
            duration: 300
        }
    }
    visible: opacity > 0.0

    HoverHandler {
        id: controlsHoverHandler
    }

    Column {
        id: controlsContainer
        anchors.fill: parent
        anchors.margins: (app.visibility === Window.FullScreen || app.currentView === "video") ? 12 : 0
        spacing: 12

        // Seekbar Slider
        Timeline {
            id: timeline
            app: root.app
        }

        TransportControls {
            id: transportControls
            app: root.app
        }

        // Message Area (inside layout card for clean contrast layout)
        Text {
            id: messageArea
            text: app.messageText
            anchors.horizontalCenter: parent.horizontalCenter
            color: "#ef4444"
            font.pixelSize: 12
            font.bold: true
            visible: text !== ""
        }
    }
}
