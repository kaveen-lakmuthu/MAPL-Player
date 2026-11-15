import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
    id: root
    objectName: "audioVisualizer"
    required property var app
    readonly property bool showingSpectrum: app.audioLevels.available && !app.reduceMotion
    readonly property var spectrum: app.audioLevels.spectrum
    implicitHeight: 62
    implicitWidth: 280
    Accessible.role: Accessible.Indicator
    Accessible.name: showingSpectrum ? "Audio visualizer, bass to treble" : status.text
    HoverHandler { id: hover }
    ToolTip.visible: hover.hovered && root.showingSpectrum
    ToolTip.delay: 600
    ToolTip.text: "Audio visualizer · bass on the left, treble on the right"

    Item {
        anchors.fill: parent
        visible: root.showingSpectrum
        Row {
            id: bars
            objectName: "audioSpectrumBars"
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: captions.top
            anchors.bottomMargin: 5
            spacing: 3
            Repeater {
                model: 24
                Rectangle {
                    required property int index
                    objectName: "audioSpectrumBar" + index
                    readonly property real amplitude: root.spectrum[index] || 0
                    readonly property real strength: amplitude > 0 ? Math.max(0, Math.min(1, (20 * Math.log10(amplitude) + 60) / 60)) : 0
                    width: Math.max(1, (bars.width - 23 * bars.spacing) / 24)
                    height: bars.height * strength
                    anchors.bottom: parent.bottom
                    radius: 1.5
                    color: "#9dc7ef"
                    Behavior on height { NumberAnimation { duration: root.app.reduceMotion ? 0 : 90 } }
                }
            }
        }
        RowLayout {
            id: captions
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            Text { text: "BASS"; color: "#b7cee4"; font.pixelSize: 9; font.letterSpacing: 1 }
            Item { Layout.fillWidth: true }
            Text { text: "TREBLE"; color: "#b7cee4"; font.pixelSize: 9; font.letterSpacing: 1 }
        }
    }
    Row {
        anchors.verticalCenter: parent.verticalCenter
        spacing: 7
        visible: !root.showingSpectrum
        Rectangle { width: 5; height: 5; radius: 3; color: "#9dc7ef"; anchors.verticalCenter: parent.verticalCenter }
        Text {
            id: status
            objectName: "audioPlaybackIndicator"
            text: root.app.isMuted || root.app.volumeSlider.value === 0 ? "Muted" : !root.app.mediaPlayer.hasAudio ? "No audio" : root.app.mediaPlayer.activeAudioTrack < 0 ? "Audio off" : "Audio playing"
            color: "#b7cee4"
            font.pixelSize: 11
        }
    }
}
