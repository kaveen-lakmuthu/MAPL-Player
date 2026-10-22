import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

PlayerPopup {
    id: root
    objectName: "subtitlePicker"
    visible: app.subtitlePickerVisible
    padding: 0

    onClosed: app.subtitlePickerVisible = false

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
                text: "🔤  Choose Subtitle Track"
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

        // Subtitle option list (max 280px, scrollable)
        ListView {
            id: subtitleOptionsList
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.preferredHeight: Math.min(contentHeight, 280)
            clip: true
            model: app.availableSubtitles

            // "No Subtitles" header row (always first)
            header: Item {
                width: subtitleOptionsList.width
                height: 50

                Rectangle {
                    anchors.fill: parent
                    anchors.margins: 4
                    radius: 8
                    color: (app.subtitleChunks.length === 0 && app.activeEmbeddedTrackIndex === -1) ? "#1e3a5f" : "transparent"

                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        onEntered: parent.color = Qt.binding(function () {
                            return (app.subtitleChunks.length === 0 && app.activeEmbeddedTrackIndex === -1) ? "#1e3a5f" : "#1e293b";
                        })
                        onExited: parent.color = Qt.binding(function () {
                            return (app.subtitleChunks.length === 0 && app.activeEmbeddedTrackIndex === -1) ? "#1e3a5f" : "transparent";
                        })
                        onClicked: {
                            app.clearSubtitles();
                            root.close();
                            app.showMessage("Subtitles off");
                        }

                        RowLayout {
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.left: parent.left
                            anchors.leftMargin: 16
                            spacing: 12

                            Text {
                                text: "⊘"
                                color: "#64748b"
                                font.pixelSize: 16
                                Layout.alignment: Qt.AlignVCenter
                            }
                            Text {
                                text: "No Subtitles"
                                color: "#94a3b8"
                                font.pixelSize: 14
                                Layout.alignment: Qt.AlignVCenter
                            }
                        }
                    }
                }
            }

            delegate: Item {
                width: subtitleOptionsList.width
                height: 50

                property bool isActive: modelData.isEmbedded ? (app.activeEmbeddedTrackIndex === modelData.embeddedIndex) : (app.activeSubtitleUrl === modelData.url.toString() && app.activeEmbeddedTrackIndex === -1)

                Rectangle {
                    anchors.fill: parent
                    anchors.margins: 4
                    radius: 8
                    color: parent.isActive ? "#1e3a5f" : "transparent"

                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        onEntered: parent.color = parent.parent.isActive ? "#1e4a7f" : "#1e293b"
                        onExited: parent.color = parent.parent.isActive ? "#1e3a5f" : "transparent"

                        onClicked: {
                            var opt = app.availableSubtitles[index];
                            if (opt.isEmbedded)
                                app.selectEmbeddedSubtitle(opt.embeddedIndex);
                            else
                                app.loadSubtitleFile(opt.url);
                            root.close();
                        }

                        RowLayout {
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.left: parent.left
                            anchors.right: activeIndicator.left
                            anchors.leftMargin: 16
                            anchors.rightMargin: 8
                            spacing: 10

                            Text {
                                text: modelData.isEmbedded ? "🎬" : "📄"
                                font.pixelSize: 15
                                Layout.alignment: Qt.AlignVCenter
                            }
                            Text {
                                text: modelData.isEmbedded ? modelData.label.replace("🎬 ", "") : modelData.label
                                color: "white"
                                font.pixelSize: 14
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                            }
                            Text {
                                visible: modelData.isEmbedded
                                text: "embedded"
                                color: "#38bdf8"
                                font.pixelSize: 10
                                font.letterSpacing: 0.5
                                Layout.alignment: Qt.AlignVCenter
                                leftPadding: 2

                                Rectangle {
                                    anchors.fill: parent
                                    anchors.margins: -3
                                    color: Qt.rgba(0.22, 0.74, 0.98, 0.12)
                                    border.color: Qt.rgba(0.22, 0.74, 0.98, 0.3)
                                    border.width: 1
                                    radius: 4
                                    z: -1
                                }
                            }
                        }

                        // Active checkmark
                        Text {
                            id: activeIndicator
                            anchors.right: parent.right
                            anchors.rightMargin: 16
                            anchors.verticalCenter: parent.verticalCenter
                            visible: parent.parent.parent.isActive
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
                text: app.availableSubtitles.length + " track" + (app.availableSubtitles.length !== 1 ? "s" : "") + " available"
                color: "#475569"
                font.pixelSize: 11
            }
        }
    }
}
