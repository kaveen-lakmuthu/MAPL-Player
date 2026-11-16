import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

RowLayout {
    id: root
    objectName: "volumeControl"
    required property var app
    property bool isNarrow: false
    property alias slider: volumeSlider
    spacing: 8
    VolumeWheelHandler { app: root.app }
    DesktopButton {
        glyph: app.isMuted || volumeSlider.value === 0 ? "muted" : "volume"
        hint: app.isMuted ? "Unmute (M)" : "Mute (M)"
        selected: app.isMuted
        onClicked: app.toggleMute()
    }
    Slider {
        id: volumeSlider
        Layout.preferredWidth: root.isNarrow ? 64 : 96
        Layout.preferredHeight: 30
        from: 0
        to: 100
        value: app.playerController.loadVolume()
        Accessible.name: "Volume"
        wheelEnabled: false
        onValueChanged: {
            saveTimer.restart();
            if (value > 0) app.isMuted = false;
        }
        Timer { id: saveTimer; interval: 500; onTriggered: app.playerController.saveVolume(Math.round(volumeSlider.value)) }
        background: Rectangle {
            x: volumeSlider.leftPadding
            y: volumeSlider.topPadding + volumeSlider.availableHeight / 2 - height / 2
            width: volumeSlider.availableWidth
            height: 4
            radius: 2
            color: "#526477"
            Rectangle { width: volumeSlider.visualPosition * parent.width; height: parent.height; radius: 2; color: "#8bbbed" }
        }
        handle: Rectangle {
            x: volumeSlider.leftPadding + volumeSlider.visualPosition * (volumeSlider.availableWidth - width)
            y: volumeSlider.topPadding + volumeSlider.availableHeight / 2 - height / 2
            width: 10
            height: 10
            radius: 5
            color: "#edf3fa"
            border.width: volumeSlider.visualFocus ? 2 : 0
            border.color: "#8bbbed"
        }
    }
    Text { text: Math.round(volumeSlider.value) + "%"; color: "#c2ceda"; font.pixelSize: 11; Layout.preferredWidth: 32 }
}
