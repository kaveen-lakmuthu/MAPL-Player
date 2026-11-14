import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Shapes
import QtMultimedia
import "../components"

Item {
    id: root
    objectName: "audioPresentation"
    required property var app
    readonly property var track: app.currentTrackIndex >= 0 ? app.playlist[app.currentTrackIndex] : null
    readonly property var nextTrack: app.playlist.length > 1 ? app.playlist[(app.currentTrackIndex + 1) % app.playlist.length] : null
    readonly property bool compact: width < 600 || height < 400
    readonly property bool stacked: width < 480 && height >= 520
    readonly property real artworkSize: Math.max(80, Math.min(stacked ? 180 : compact ? 144 : 320,
                                                            presentation.width * (stacked ? 0.6 : compact ? 0.32 : 0.38),
                                                            height * (stacked ? 0.3 : compact ? 0.5 : 0.62)))
    property color ambientTint: app.ambientSourceColor
    anchors.fill: parent
    visible: app.mediaView === "audio"
    Behavior on ambientTint { ColorAnimation { duration: root.visible && !app.reduceMotion ? 1000 : 0 } }

    // Audio has its own listening space. Low-alpha radial light keeps the text
    // readable even when the source frame is white or the tint is at its cap.
    Shape {
        id: ambientLight
        objectName: "audioAmbientLight"
        anchors.fill: parent
        visible: root.visible && app.ambientEnabled && !app.reduceMotion
        opacity: Math.min(1, app.ambientStrength * 4)
        ShapePath {
            strokeWidth: -1
            fillGradient: RadialGradient {
                centerX: root.width * 0.25
                centerY: root.height * 0.4
                focalX: centerX
                focalY: centerY
                centerRadius: Math.max(root.width, root.height) * 0.65
                GradientStop { position: 0; color: Qt.rgba(root.ambientTint.r, root.ambientTint.g, root.ambientTint.b, 0.30) }
                GradientStop { position: 0.5; color: Qt.rgba(root.ambientTint.r, root.ambientTint.g, root.ambientTint.b, 0.10) }
                GradientStop { position: 1; color: "transparent" }
            }
            startX: 0; startY: 0
            PathLine { x: root.width; y: 0 }
            PathLine { x: root.width; y: root.height }
            PathLine { x: 0; y: root.height }
            PathLine { x: 0; y: 0 }
        }
        ShapePath {
            strokeWidth: -1
            fillGradient: RadialGradient {
                centerX: root.width * 0.85
                centerY: root.height * 0.9
                focalX: centerX
                focalY: centerY
                centerRadius: Math.max(root.width, root.height) * 0.55
                GradientStop { position: 0; color: "#26678cce" }
                GradientStop { position: 1; color: "transparent" }
            }
            startX: 0; startY: 0
            PathLine { x: root.width; y: 0 }
            PathLine { x: root.width; y: root.height }
            PathLine { x: 0; y: root.height }
            PathLine { x: 0; y: 0 }
        }
    }

    ColumnLayout {
        id: presentation
        anchors.centerIn: parent
        width: Math.min(900, Math.max(0, parent.width - (root.compact ? 32 : 64)))
        spacing: root.compact ? 14 : 28

        GridLayout {
            columns: root.stacked ? 1 : 2
            columnSpacing: root.compact ? 18 : 36
            rowSpacing: 16
            Layout.fillWidth: true

            Rectangle {
                id: artwork
                objectName: "audioArtwork"
                Layout.preferredWidth: root.artworkSize
                Layout.preferredHeight: root.artworkSize
                Layout.alignment: Qt.AlignCenter
                color: "#1e3045"
                radius: 10
                clip: true
                Image {
                    anchors.fill: parent
                    source: app.currentThumbnailDataUrl
                    fillMode: Image.PreserveAspectCrop
                }
                Column {
                    anchors.centerIn: parent
                    spacing: 14
                    visible: app.currentThumbnailDataUrl === ""
                    PlayerIcon {
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: root.compact ? 36 : 56
                        height: width
                        name: "audio"
                        ink: "#b8d5f0"
                    }
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        visible: !root.compact
                        text: "MAPL"
                        color: "#a0bbd5"
                        font.pixelSize: 11
                        font.letterSpacing: 3
                    }
                }
            }

            ColumnLayout {
                id: details
                Layout.fillWidth: true
                Layout.minimumWidth: 0
                spacing: root.compact ? 6 : 12
                Text {
                    text: "NOW PLAYING"
                    color: "#b7cee4"
                    font.pixelSize: 10
                    font.letterSpacing: 2
                }
                Text {
                    objectName: "audioTrackTitle"
                    Layout.fillWidth: true
                    text: root.track ? root.track.title : "Make room for the music"
                    color: "#f4f8fc"
                    font.pixelSize: root.compact ? 20 : 32
                    font.bold: true
                    wrapMode: Text.WordWrap
                    maximumLineCount: root.compact ? 1 : 2
                    elide: Text.ElideRight
                }
                Text {
                    Layout.fillWidth: true
                    text: root.track ? root.track.artist || "Unknown artist" : "Open a track, or drop media here."
                    color: "#c0d0e1"
                    font.pixelSize: root.compact ? 12 : 15
                    elide: Text.ElideRight
                }
                Text {
                    Layout.fillWidth: true
                    visible: !!root.track
                    text: root.track ? root.track.url.toString().split(".").pop().toUpperCase() + "  ·  " + app.formatTime(app.mediaPlayer.duration / 1000) + "  ·  Track " + (app.currentTrackIndex + 1) + " of " + app.playlist.length : ""
                    color: "#c0cfdf"
                    font.pixelSize: 11
                    elide: Text.ElideRight
                }
                Row {
                    spacing: 4
                    Layout.preferredHeight: 22
                    visible: root.height >= 350 && app.visualizerEnabled && !app.reduceMotion && app.mediaPlayer.playbackState === MediaPlayer.PlayingState
                    Repeater {
                        model: 9
                        Rectangle {
                            width: 4
                            height: 5
                            radius: 2
                            color: "#9dc7ef"
                            anchors.bottom: parent.bottom
                            SequentialAnimation on height {
                                loops: Animation.Infinite
                                running: root.visible && root.height >= 350 && app.visualizerEnabled && !app.reduceMotion && app.mediaPlayer.playbackState === MediaPlayer.PlayingState
                                NumberAnimation { to: 22; duration: 240 + index * 40 }
                                NumberAnimation { to: 4; duration: 290 + index * 30 }
                            }
                        }
                    }
                }
                DesktopButton {
                    objectName: "audioLiveLyrics"
                    Layout.fillWidth: true
                    Layout.minimumWidth: 0
                    implicitHeight: root.compact ? 58 : 86
                    hint: "Open live lyrics and subtitles"
                    onClicked: app.togglePanel("lyrics")
                    contentItem: ColumnLayout {
                        spacing: 4
                        Text { text: "LYRICS & SUBS"; color: "#b7cee4"; font.pixelSize: 9; font.letterSpacing: 1 }
                        Text {
                            Layout.fillWidth: true
                            text: app.activeSubtitleText !== "" ? app.activeSubtitleText : app.currentLyrics !== "" ? "Plain lyrics loaded · open to read" : "Load lyrics or generate timed lines"
                            color: app.activeSubtitleText !== "" ? "#f4f8fc" : "#b8cadc"
                            font.pixelSize: root.compact ? 12 : 15
                            wrapMode: Text.WordWrap
                            maximumLineCount: 2
                            elide: Text.ElideRight
                        }
                    }
                }
                RowLayout {
                    visible: !root.track
                    DesktopButton { text: "Open media…"; onClicked: app.openMediaDialog() }
                    DesktopButton { text: "Recent files…"; visible: root.width >= 480; onClicked: app.openRecentFiles() }
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 10
            DesktopButton {
                objectName: "audioUpNext"
                Layout.fillWidth: true
                Layout.minimumWidth: 0
                implicitHeight: root.compact ? 48 : 62
                glyph: "next"
                hint: root.nextTrack ? "Play next: " + root.nextTrack.title : "Open the playlist"
                onClicked: {
                    if (root.nextTrack) app.playNext();
                    else app.togglePanel("playlist");
                }
                contentItem: RowLayout {
                    spacing: 12
                    PlayerIcon { name: root.nextTrack ? "next" : "playlist"; ink: "#b8d5f0" }
                    ColumnLayout {
                        spacing: 3
                        Layout.fillWidth: true
                        Text { text: root.nextTrack ? "UP NEXT" : "YOUR PLAYLIST"; color: "#b7cee4"; font.pixelSize: 9; font.letterSpacing: 1 }
                        Text {
                            Layout.fillWidth: true
                            text: root.nextTrack ? root.nextTrack.title + (root.nextTrack.artist ? " · " + root.nextTrack.artist : "") : app.playlist.length > 0 ? "Choose another track or load a playlist" : "Open media or an XSPF playlist to begin"
                            color: "#e1ebf5"
                            font.pixelSize: 12
                            elide: Text.ElideRight
                        }
                    }
                }
            }
            DesktopButton {
                objectName: "audioPlaylistButton"
                glyph: "playlist"
                text: root.width >= 480 ? "Playlist" : ""
                hint: "Show playlist · " + app.playlist.length + " tracks"
                selected: app.panelView === "playlist"
                onClicked: app.togglePanel("playlist")
            }
        }
    }
}
