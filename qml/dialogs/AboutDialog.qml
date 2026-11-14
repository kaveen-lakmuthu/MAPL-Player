import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

PlayerDialog {
    id: root
    objectName: "aboutDialog"
    preferredWidth: 320
    padding: 20

    background: Rectangle {
        color: "#1e293b"
        radius: 12
        border.color: "#334155"
        border.width: 1
    }

    contentItem: ColumnLayout {
        spacing: 14
        Text {
            text: "MAPL Player (Native)"
            font.pixelSize: 18
            font.bold: true
            color: "white"
            horizontalAlignment: Text.AlignHCenter
            Layout.fillWidth: true
        }
        Text {
            objectName: "aboutVersion"
            text: "Version " + Qt.application.version + " (C++ / Qt6)"
            horizontalAlignment: Text.AlignHCenter
            color: "#94a3b8"
            font.pixelSize: 12
            Layout.fillWidth: true
        }
        Text {
            text: "Featuring offline Speech-to-Text translation via whisper.cpp."
            wrapMode: Text.WordWrap
            horizontalAlignment: Text.AlignHCenter
            color: "#cbd5e0"
            font.pixelSize: 13
            Layout.fillWidth: true
        }
        Item {
            Layout.preferredHeight: 8
        }
        Button {
            id: closeAboutBtn
            Layout.alignment: Qt.AlignHCenter
            Layout.preferredWidth: 100
            Layout.preferredHeight: 32
            padding: 0
            background: Rectangle {
                color: closeAboutBtn.pressed ? "#1d4ed8" : (closeAboutBtn.hovered ? "#3b82f6" : "#2563eb")
                radius: 6
            }
            contentItem: Text {
                text: "OK"
                color: "white"
                font.bold: true
                font.pixelSize: 12
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
            }
            onClicked: root.close()
        }
    }
}
