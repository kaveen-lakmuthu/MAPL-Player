import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../components"
import "../logic/MediaUtils.js" as MediaUtils

PlayerDialog {
    id: root
    objectName: "resumeDialog"
    closePolicy: Popup.NoAutoClose
    visible: app.resumePending
    title: "Resume playback?"
    background: Rectangle {
        color: "#0f172a"
        radius: 12
        border.color: "#334155"
    }
    header: Label {
        text: root.title
        color: "white"
        font.pixelSize: 18
        font.bold: true
        padding: 20
    }
    contentItem: ColumnLayout {
        spacing: 12
        Label {
            text: app.resumeTitle
            textFormat: Text.PlainText
            color: "#e2e8f0"
            wrapMode: Text.Wrap
            Layout.fillWidth: true
        }
        Label {
            text: "Continue from " + MediaUtils.formatTime(app.resumePositionMs / 1000) + "?"
            color: "#94a3b8"
            Layout.fillWidth: true
        }
    }
    footer: DialogButtonBox {
        padding: 20
        spacing: 8
        DesktopButton {
            objectName: "startOverButton"
            text: "Start from beginning"
            DialogButtonBox.buttonRole: DialogButtonBox.ActionRole
            onClicked: app.startPlaybackOver()
        }
        DesktopButton {
            objectName: "resumeButton"
            text: "Resume"
            prominent: true
            DialogButtonBox.buttonRole: DialogButtonBox.ActionRole
            onClicked: app.resumePlayback()
        }
    }
}
