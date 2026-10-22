import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

PlayerPopup {
    id: root
    objectName: "chaptersPopup"
    padding: 0
    visible: app.chaptersPopupVisible

    onClosed: app.chaptersPopupVisible = false

    // Dark dim behind popup
    Overlay.modal: Rectangle {
        color: Qt.rgba(0, 0, 0, 0.55)
    }

    background: Rectangle {
        color: "#0f172a"
        radius: 16
        border.color: "#334155"
        border.width: 1

        // Subtle top glow
        Rectangle {
            anchors.top: parent.top
            anchors.horizontalCenter: parent.horizontalCenter
            width: parent.width * 0.5
            height: 1
            color: "#38bdf8"
            opacity: 0.4
            radius: 1
        }
    }

    contentItem: ColumnLayout {
        spacing: 0

        // Header
        Item {
            Layout.fillWidth: true
            Layout.preferredHeight: 56
            Layout.minimumHeight: 56

            Text {
                anchors.left: parent.left
                anchors.leftMargin: 20
                anchors.verticalCenter: parent.verticalCenter
                text: "📖  Chapters List"
                color: "white"
                font.pixelSize: 15
                font.bold: true
                font.letterSpacing: 0.3
            }

            // Close button
            Button {
                anchors.right: parent.right
                anchors.rightMargin: 12
                anchors.verticalCenter: parent.verticalCenter
                implicitWidth: 32
                implicitHeight: 32
                flat: true
                padding: 0
                contentItem: Text {
                    text: "✕"
                    color: "#64748b"
                    font.pixelSize: 13
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
                background: Rectangle {
                    color: parent.hovered ? "#1e293b" : "transparent"
                    radius: 6
                }
                onClicked: root.close()
            }

            // Divider
            Rectangle {
                anchors.bottom: parent.bottom
                width: parent.width
                height: 1
                color: "#1e293b"
            }
        }

        // Chapters list
        ListView {
            id: chaptersList
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.preferredHeight: Math.min(contentHeight, 280)
            clip: true
            model: app.mediaChapters

            delegate: Item {
                id: chapterDelegate
                width: chaptersList.width
                height: 50

                property bool isActive: {
                    var posSec = app.mediaPlayer.position / 1000.0;
                    if (posSec < modelData.time)
                        return false;
                    var nextIndex = index + 1;
                    if (nextIndex < app.mediaChapters.length) {
                        return posSec < app.mediaChapters[nextIndex].time;
                    }
                    return true;
                }

                Rectangle {
                    anchors.fill: parent
                    anchors.margins: 4
                    radius: 8
                    color: chapterDelegate.isActive ? "#1e3a5f" : "transparent"

                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        onEntered: parent.color = chapterDelegate.isActive ? "#1e4a7f" : "#1e293b"
                        onExited: parent.color = chapterDelegate.isActive ? "#1e3a5f" : "transparent"

                        onClicked: {
                            app.seekTo(modelData.time * 1000.0);
                            root.close();
                            app.showMessage("Skipped to: " + modelData.title);
                        }

                        RowLayout {
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.left: parent.left
                            anchors.right: activeChapterIndicator.left
                            anchors.leftMargin: 16
                            anchors.rightMargin: 8
                            spacing: 12

                            Text {
                                text: "📌"
                                font.pixelSize: 14
                                Layout.alignment: Qt.AlignVCenter
                            }
                            Text {
                                text: modelData.title
                                color: "white"
                                font.pixelSize: 14
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                            }
                            Text {
                                text: app.formatTime(modelData.time)
                                color: "#64748b"
                                font.pixelSize: 12
                                Layout.alignment: Qt.AlignVCenter
                            }
                        }

                        // Active checkmark
                        Text {
                            id: activeChapterIndicator
                            anchors.right: parent.right
                            anchors.rightMargin: 16
                            anchors.verticalCenter: parent.verticalCenter
                            visible: chapterDelegate.isActive
                            text: "✓"
                            color: "#38bdf8"
                            font.pixelSize: 14
                            font.bold: true
                        }
                    }
                }
            }

            ScrollBar.vertical: ScrollBar {
                policy: ScrollBar.AsNeeded
            }
        }

        // Footer hint
        Item {
            Layout.fillWidth: true
            Layout.preferredHeight: 40
            Layout.minimumHeight: 40

            Rectangle {
                anchors.top: parent.top
                width: parent.width
                height: 1
                color: "#1e293b"
            }

            Text {
                anchors.centerIn: parent
                text: app.mediaChapters.length + " chapter" + (app.mediaChapters.length !== 1 ? "s" : "") + " detected"
                color: "#475569"
                font.pixelSize: 11
            }
        }
    }
}
