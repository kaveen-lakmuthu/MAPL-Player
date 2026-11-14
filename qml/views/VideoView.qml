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
            anchors.fill: parent
            hoverEnabled: true
            preventStealing: true

            cursorShape: (app.visibility === Window.FullScreen && !app.controlsVisible) ? Qt.BlankCursor : Qt.ArrowCursor

            onPositionChanged: {
                if (app.visibility === Window.FullScreen) {
                    app.controlsVisible = true;
                    app.restartControlsHideTimer();
                }
            }
            onDoubleClicked: {
                app.toggleFullscreen();
            }
            onClicked: mouse => {
                if (app.mediaPlayer.playbackState === MediaPlayer.PlayingState) {
                    app.mediaPlayer.pause();
                } else {
                    app.playCurrentTrack();
                }
            }
        }
    }
}
