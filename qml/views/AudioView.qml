import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtMultimedia

Item {
    id: root
    required property var app

    anchors.fill: parent
    visible: app.currentView === "audio"

    // Blurred ambient art backdrop
    Image {
        anchors.fill: parent
        fillMode: Image.PreserveAspectCrop
        visible: app.currentThumbnailDataUrl !== ""
        source: app.currentThumbnailDataUrl
        opacity: 0.12
        layer.enabled: true
        layer.effect: null  // no shader needed; opacity alone creates a subtle glow
    }

    RowLayout {
        anchors.fill: parent
        anchors.margins: 32
        spacing: 40

        // ── Left: large cover art ───────────────────
        Rectangle {
            Layout.preferredWidth: Math.min(parent.height * 0.72, 340)
            Layout.preferredHeight: Layout.preferredWidth
            Layout.alignment: Qt.AlignVCenter
            color: "#090d16"
            radius: 20
            border.color: app.accentColor !== "" ? app.accentColor : "#334155"
            border.width: 2
            clip: true

            // Gradient placeholder
            Rectangle {
                anchors.fill: parent
                visible: app.currentThumbnailDataUrl === ""
                gradient: Gradient {
                    GradientStop {
                        position: 0.0
                        color: "#1e293b"
                    }
                    GradientStop {
                        position: 1.0
                        color: "#090d16"
                    }
                }
            }
            Image {
                anchors.fill: parent
                fillMode: Image.PreserveAspectCrop
                visible: app.currentThumbnailDataUrl !== ""
                source: app.currentThumbnailDataUrl
            }
            Text {
                anchors.centerIn: parent
                text: "🎵"
                font.pixelSize: 96
                visible: app.currentThumbnailDataUrl === ""
                opacity: 0.4
            }
        }

        // ── Right: metadata + equaliser bars ────────
        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 12

            Item {
                Layout.fillHeight: true
            }

            Text {
                text: "NOW PLAYING"
                color: app.accentColor !== "" ? app.accentColor : "#3b82f6"
                font.pixelSize: 10
                font.bold: true
                font.letterSpacing: 3.0
            }

            Text {
                id: currentTrackTitleText
                text: (app.currentTrackIndex >= 0 && app.playlist[app.currentTrackIndex]) ? app.playlist[app.currentTrackIndex].title : "No file loaded"
                color: "white"
                font.pixelSize: 22
                font.bold: true
                wrapMode: Text.WordWrap
                Layout.fillWidth: true
                maximumLineCount: 2
                elide: Text.ElideRight
            }

            Text {
                text: (app.currentTrackIndex >= 0 && app.playlist[app.currentTrackIndex]) ? (app.playlist[app.currentTrackIndex].artist || "Unknown Artist") : ""
                color: "#94a3b8"
                font.pixelSize: 14
                Layout.fillWidth: true
                elide: Text.ElideRight
                visible: text !== ""
            }

            // Mini equaliser visualiser (animated bars)
            Row {
                spacing: 5
                Layout.topMargin: 4
                visible: app.mediaPlayer.playbackState === MediaPlayer.PlayingState

                Repeater {
                    model: 9
                    delegate: Rectangle {
                        width: 5
                        radius: 3
                        color: app.accentColor !== "" ? app.accentColor : "#3b82f6"
                        opacity: 0.85

                        property real barPhase: index * 0.7
                        property real barHeight: 8 + 24 * Math.abs(Math.sin((Date.now() / 400.0) + barPhase))
                        height: barHeight
                        anchors.bottom: parent ? parent.bottom : undefined

                        NumberAnimation on barHeight {
                            from: 8
                            to: 32
                            duration: 350 + index * 60
                            easing.type: Easing.SineCurve
                            loops: Animation.Infinite
                            running: app.mediaPlayer.playbackState === MediaPlayer.PlayingState
                        }
                    }
                }

                // Fixed height wrapper so bars anchor to bottom
                Item {
                    width: 0
                    height: 32
                }
            }

            Item {
                height: 10
            }

            // Live Subtitles Card
            Rectangle {
                id: liveSubsCard
                Layout.fillWidth: true
                Layout.preferredHeight: 92
                color: Qt.rgba(15 / 255.0, 23 / 255.0, 42 / 255.0, 0.45)
                radius: 12
                border.color: app.accentColor !== "" ? Qt.rgba(Qt.color(app.accentColor).r, Qt.color(app.accentColor).g, Qt.color(app.accentColor).b, 0.25) : "#1e293b"
                border.width: 1

                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: app.currentView = "lyrics"
                    cursorShape: Qt.PointingHandCursor
                }

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 12
                    spacing: 4

                    Text {
                        text: "📝 LIVE SUBTITLES"
                        color: app.accentColor !== "" ? app.accentColor : "#3b82f6"
                        font.pixelSize: 9
                        font.bold: true
                        font.letterSpacing: 1.5
                    }

                    Text {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        text: app.activeSubtitleText !== "" ? app.activeSubtitleText : (app.currentLyrics !== "" ? "Plain lyrics loaded. Click to view." : "No subtitles loaded. Click to generate.")
                        color: app.activeSubtitleText !== "" ? "white" : "#64748b"
                        font.bold: app.activeSubtitleText !== ""
                        font.pixelSize: 13
                        wrapMode: Text.WordWrap
                        elide: Text.ElideRight
                        maximumLineCount: 2
                        verticalAlignment: Text.AlignVCenter
                    }
                }
            }

            // Up Next Card
            Rectangle {
                id: upNextCard
                Layout.fillWidth: true
                Layout.preferredHeight: 76
                color: Qt.rgba(15 / 255.0, 23 / 255.0, 42 / 255.0, 0.35)
                radius: 12
                border.color: "#1e293b"
                border.width: 1
                visible: app.playlist.length > 1

                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: app.playNext()
                    cursorShape: Qt.PointingHandCursor
                }

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 10
                    spacing: 4

                    Text {
                        text: "📋 UP NEXT"
                        color: "#64748b"
                        font.pixelSize: 9
                        font.bold: true
                        font.letterSpacing: 1.5
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8

                        Text {
                            text: "⏭️"
                            font.pixelSize: 14
                            Layout.alignment: Qt.AlignVCenter
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 2

                            Text {
                                Layout.fillWidth: true
                                text: {
                                    var nextIdx = (app.currentTrackIndex + 1) % app.playlist.length;
                                    return app.playlist[nextIdx] ? app.playlist[nextIdx].title : "End of Playlist";
                                }
                                color: "white"
                                font.bold: true
                                font.pixelSize: 12
                                elide: Text.ElideRight
                            }

                            Text {
                                Layout.fillWidth: true
                                text: {
                                    var nextIdx = (app.currentTrackIndex + 1) % app.playlist.length;
                                    return app.playlist[nextIdx] ? (app.playlist[nextIdx].artist || "Unknown Artist") : "";
                                }
                                color: "#64748b"
                                font.pixelSize: 11
                                elide: Text.ElideRight
                                visible: text !== ""
                            }
                        }
                    }
                }
            }

            Item {
                height: 10
            }

            // Playback stats row
            RowLayout {
                spacing: 20
                Layout.fillWidth: true

                Column {
                    spacing: 3
                    Text {
                        text: "FORMAT"
                        color: "#64748b"
                        font.pixelSize: 9
                        font.letterSpacing: 1.5
                    }
                    Text {
                        text: {
                            var url = (app.currentTrackIndex >= 0 && app.playlist[app.currentTrackIndex]) ? app.playlist[app.currentTrackIndex].url : "";
                            var ext = url.split('.').pop().toUpperCase();
                            return ext || "—";
                        }
                        color: "#cbd5e1"
                        font.pixelSize: 13
                        font.bold: true
                    }
                }
                Column {
                    spacing: 3
                    Text {
                        text: "DURATION"
                        color: "#64748b"
                        font.pixelSize: 9
                        font.letterSpacing: 1.5
                    }
                    Text {
                        text: app.mediaPlayer.duration > 0 ? app.formatTime(app.mediaPlayer.duration / 1000) : "—"
                        color: "#cbd5e1"
                        font.pixelSize: 13
                        font.bold: true
                    }
                }
                Column {
                    spacing: 3
                    Text {
                        text: "TRACK"
                        color: "#64748b"
                        font.pixelSize: 9
                        font.letterSpacing: 1.5
                    }
                    Text {
                        text: app.currentTrackIndex >= 0 ? (app.currentTrackIndex + 1) + " / " + app.playlist.length : "—"
                        color: "#cbd5e1"
                        font.pixelSize: 13
                        font.bold: true
                    }
                }
            }

            Item {
                Layout.fillHeight: true
            }
        }
    }
}
