import QtQuick
import QtQuick.Window
import QtQuick.Controls
import QtQuick.Layouts
import QtMultimedia

Item {
    id: root
    required property var app
    property alias output: videoOutput

    anchors.fill: parent
    visible: app.mediaView === "video"

    VideoOutput {
        id: videoOutput
        anchors.fill: parent

        // Mouse area to capture hover and double clicks for fullscreen
        MouseArea {
            id: videoMouseArea
            objectName: "videoPointerArea"
            anchors.fill: parent
            hoverEnabled: true
            preventStealing: true

            cursorShape: (app.fullscreenVideo && !app.fullscreenCursorVisible) ? Qt.BlankCursor : Qt.ArrowCursor

            // Reveal from the bottom edge, without summoning the bar over the
            // picture whenever the mouse moves. Cursor inactivity is separate.
            onEntered: app.handleFullscreenPointer(mouseY >= height - 20)
            onPositionChanged: app.handleFullscreenPointer(mouseY >= height - 20)
            onVisibleChanged: {
                if (!visible && singleClickTimer) singleClickTimer.stop();
            }
            onDoubleClicked: mouse => {
                mouse.accepted = true;
                singleClickTimer.stop();
                app.toggleFullscreen();
            }
            onClicked: {
                singleClickTimer.mediaRevision = app.mediaRevision;
                singleClickTimer.restart();
            }
            Timer {
                id: singleClickTimer
                property int mediaRevision: -1
                // The first click also belongs to a double click. Wait until
                // it can be treated as a single click without pausing first.
                interval: Qt.styleHints.mouseDoubleClickInterval
                onTriggered: {
                    if (root.visible && !app.modalDialogOpen && mediaRevision === app.mediaRevision)
                        app.togglePlayPause();
                }
            }
        }
    }
}
