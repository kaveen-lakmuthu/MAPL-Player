import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
    id: root
    required property var app

    anchors.fill: parent
    visible: app.currentView === "playlist"

    ColumnLayout {
        anchors.fill: parent
        spacing: 12

        // Custom Card Container for Auto-load folder files setting
        Rectangle {
            id: autoLoadSettingCard
            Layout.fillWidth: true
            height: 42
            color: autoLoadMouseArea.containsMouse ? "#1e293b" : "#0f172a" // Highlight on hover
            radius: 8
            border.color: autoLoadMouseArea.containsMouse ? "#3b82f6" : "#334155" // Accent border on hover
            border.width: 1

            Behavior on color {
                ColorAnimation {
                    duration: 150
                }
            }
            Behavior on border.color {
                ColorAnimation {
                    duration: 150
                }
            }

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 12
                anchors.rightMargin: 12
                spacing: 12

                Text {
                    text: "📁 Auto-load folder files"
                    color: "#e2e8f0" // High-contrast Slate-200 text
                    font.pixelSize: 13
                    font.bold: true
                    verticalAlignment: Text.AlignVCenter
                    Layout.fillWidth: true
                }

                Item {
                    id: switchControl
                    width: 36
                    height: 20
                    Layout.alignment: Qt.AlignRight | Qt.AlignVCenter

                    property bool checked: app.playFolderToggle

                    Rectangle {
                        anchors.fill: parent
                        radius: 10
                        color: switchControl.checked ? "#3b82f6" : "#334155"
                        border.color: switchControl.checked ? "#60a5fa" : "#475569"
                        border.width: 1.5

                        Behavior on color {
                            ColorAnimation {
                                duration: 150
                            }
                        }
                    }

                    Rectangle {
                        id: switchHandle
                        width: 14
                        height: 14
                        radius: 7
                        color: "white"
                        anchors.verticalCenter: parent.verticalCenter
                        x: switchControl.checked ? 19 : 3

                        Behavior on x {
                            NumberAnimation {
                                duration: 150
                                easing.type: Easing.InOutQuad
                            }
                        }
                    }
                }
            }

            MouseArea {
                id: autoLoadMouseArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    app.playFolderToggle = !app.playFolderToggle;
                    app.playerController.savePlayFolderToggle(app.playFolderToggle);
                    app.showMessage("Folder playlist mode: " + (app.playFolderToggle ? "Enabled" : "Disabled"));
                }
            }
        }

        TextField {
            id: filterField
            Layout.fillWidth: true
            placeholderText: "🔍 Filter playlist..."
            color: "white"
            font.pixelSize: 13
            background: Rectangle {
                color: "#0f172a"
                radius: 8
                border.color: "#334155"
            }
        }

        ListView {
            id: playlistListView
            objectName: "playlistListView"
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            model: app.playlist.filter(track => track.title.toLowerCase().indexOf(filterField.text.toLowerCase()) !== -1)
            delegate: ItemDelegate {
                width: playlistListView.width
                height: 38
                property bool isCurrent: modelData.url === app.playlist[app.currentTrackIndex]?.url

                contentItem: Text {
                    text: (index + 1) + ". " + modelData.title
                    color: isCurrent ? "#3b82f6" : "#e2e8f0"
                    font.bold: isCurrent
                    font.pixelSize: 13
                    verticalAlignment: Text.AlignVCenter
                }
                background: Rectangle {
                    color: hovered ? "#334155" : "transparent"
                    radius: 6
                }
                onClicked: {
                    var origIndex = app.playlist.indexOf(modelData);
                    app.loadTrack(origIndex);
                    app.playCurrentTrack();
                }
            }
        }
    }
}
