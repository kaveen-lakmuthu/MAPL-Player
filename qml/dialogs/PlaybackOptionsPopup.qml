import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

PlayerPopup {
    id: root
    objectName: "playbackOptionsPopup"
    padding: 20
    background: Rectangle {
        color: "#0f172a"
        border.color: "#334155"
        radius: 12
    }
    contentItem: ColumnLayout {
        spacing: 16
        RowLayout {
            Layout.fillWidth: true
            Label {
                text: "Audio & playback"
                color: "white"
                font.pixelSize: 18
                font.bold: true
                Layout.fillWidth: true
            }
            ToolButton {
                text: "Close"
                onClicked: root.close()
            }
        }
        Label {
            text: "Audio track"
            color: "#cbd5e1"
        }
        ComboBox {
            id: audioTrack
            objectName: "audioTrackSelector"
            Layout.fillWidth: true
            model: app.playbackOptions.audioTracks
            textRole: "label"
            valueRole: "index"
            enabled: count > 0
            currentIndex: count > 0 ? app.playbackOptions.activeAudioTrack + 1 : -1
            displayText: count > 0 ? currentText : "No audio tracks"
            onActivated: app.playbackOptions.selectAudioTrack(currentValue)
        }
        Label {
            text: "Playback speed"
            color: "#cbd5e1"
        }
        ComboBox {
            id: speed
            objectName: "playbackSpeedSelector"
            Layout.fillWidth: true
            property var rates: [0.25, 0.5, 0.75, 1, 1.25, 1.5, 1.75, 2, 2.5, 3]
            model: rates.map(function (rate) {
                return rate + "×";
            })
            currentIndex: rates.indexOf(app.playbackOptions.rate)
            displayText: Number(app.playbackOptions.rate.toFixed(2)) + "×"
            onActivated: app.playbackOptions.rate = rates[currentIndex]
        }
        Label {
            text: "Audio delay"
            color: "#cbd5e1"
        }
        RowLayout {
            SpinBox {
                objectName: "audioDelayControl"
                from: -2000
                to: 2000
                stepSize: 50
                editable: true
                value: app.playbackOptions.audioDelayMs
                enabled: app.playbackOptions.canAdjustDelay || value !== 0
                onValueModified: app.playbackOptions.audioDelayMs = value
            }
            Label {
                text: "ms"
                color: "#cbd5e1"
            }
            Button {
                text: "Reset"
                onClicked: app.playbackOptions.audioDelayMs = 0
            }
        }
        Label {
            text: "Positive values play audio later; negative values play it earlier. Delay resets for each file."
            color: "#94a3b8"
            wrapMode: Text.Wrap
            Layout.fillWidth: true
        }
    }
}
