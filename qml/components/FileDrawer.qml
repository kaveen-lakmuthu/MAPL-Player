import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Rectangle {
    id: root
    required property var app

    z: 1000
    x: app.sidebarOpen ? 155 : -width
    y: 0
    width: 300
    height: parent.height
    color: "#0f172a" // Deep Slate-900

    Rectangle {
        anchors.right: parent.right
        width: 1
        height: parent.height
        color: "#1e293b"
    }

    Behavior on x {
        NumberAnimation {
            duration: 250
            easing.type: Easing.InOutQuad
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 24
        spacing: 24

        Text {
            text: "Load Files"
            color: "white"
            font.pixelSize: 18
            font.bold: true
        }

        ColumnLayout {
            spacing: 14
            Layout.fillWidth: true

            Button {
                id: selectVideoBtn
                Layout.fillWidth: true
                Layout.preferredHeight: 38
                flat: true
                padding: 0
                scale: selectVideoBtn.hovered ? 1.02 : 1.0
                Behavior on scale {
                    NumberAnimation {
                        duration: 100
                    }
                }
                background: Rectangle {
                    color: selectVideoBtn.pressed ? "#1d4ed8" : (selectVideoBtn.hovered ? "#4a5568" : "transparent")
                    radius: 12
                }
                contentItem: Text {
                    text: "🎥 Select Video (MP4/WebM)"
                    color: selectVideoBtn.hovered || selectVideoBtn.pressed ? "white" : "#cbd5e0"
                    font.pixelSize: 13
                    font.bold: selectVideoBtn.hovered || selectVideoBtn.pressed
                    leftPadding: 12
                    verticalAlignment: Text.AlignVCenter
                }
                onClicked: app.openMediaDialog()
            }

            Button {
                id: selectPlaylistBtn
                Layout.fillWidth: true
                Layout.preferredHeight: 38
                flat: true
                padding: 0
                scale: selectPlaylistBtn.hovered ? 1.02 : 1.0
                Behavior on scale {
                    NumberAnimation {
                        duration: 100
                    }
                }
                background: Rectangle {
                    color: selectPlaylistBtn.pressed ? "#1d4ed8" : (selectPlaylistBtn.hovered ? "#4a5568" : "transparent")
                    radius: 12
                }
                contentItem: Text {
                    text: "📋 Select Playlist (.xspf)"
                    color: selectPlaylistBtn.hovered || selectPlaylistBtn.pressed ? "white" : "#cbd5e0"
                    font.pixelSize: 13
                    font.bold: selectPlaylistBtn.hovered || selectPlaylistBtn.pressed
                    leftPadding: 12
                    verticalAlignment: Text.AlignVCenter
                }
                onClicked: app.openPlaylistDialog()
            }

            Button {
                id: selectLyricsBtn
                Layout.fillWidth: true
                Layout.preferredHeight: 38
                flat: true
                padding: 0
                scale: selectLyricsBtn.hovered ? 1.02 : 1.0
                Behavior on scale {
                    NumberAnimation {
                        duration: 100
                    }
                }
                background: Rectangle {
                    color: selectLyricsBtn.pressed ? "#1d4ed8" : (selectLyricsBtn.hovered ? "#4a5568" : "transparent")
                    radius: 12
                }
                contentItem: Text {
                    text: "📄 Select Lyrics/Subs (.txt/.srt)"
                    color: selectLyricsBtn.hovered || selectLyricsBtn.pressed ? "white" : "#cbd5e0"
                    font.pixelSize: 13
                    font.bold: selectLyricsBtn.hovered || selectLyricsBtn.pressed
                    leftPadding: 12
                    verticalAlignment: Text.AlignVCenter
                }
                onClicked: app.openLyricsDialog()
            }
        }

        Item {
            Layout.fillHeight: true
        } // Spacer

        Button {
            id: closeDrawerBtn
            Layout.fillWidth: true
            Layout.preferredHeight: 38
            flat: true
            padding: 0
            scale: closeDrawerBtn.hovered ? 1.02 : 1.0
            Behavior on scale {
                NumberAnimation {
                    duration: 100
                }
            }
            background: Rectangle {
                color: closeDrawerBtn.pressed ? "#7f1d1d" : (closeDrawerBtn.hovered ? "#991b1b" : "transparent")
                radius: 12
                border.color: closeDrawerBtn.hovered ? "#ef4444" : "#7f1d1d"
                border.width: 1
            }
            contentItem: Text {
                text: "Close Menu"
                color: closeDrawerBtn.hovered || closeDrawerBtn.pressed ? "white" : "#f87171"
                font.bold: true
                font.pixelSize: 13
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
            }
            onClicked: app.sidebarOpen = false
        }
    }
}
