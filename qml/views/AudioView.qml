import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtMultimedia
import "../components"

Item {
    id: root
    required property var app
    readonly property var track: app.currentTrackIndex >= 0 ? app.playlist[app.currentTrackIndex] : null
    anchors.fill: parent
    visible: app.mediaView === "audio"

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 20
        spacing: 12
        RowLayout {
            Layout.fillWidth: true
            spacing: 18
            Rectangle {
                Layout.preferredWidth: root.height < 420 ? 104 : 144
                Layout.preferredHeight: Layout.preferredWidth
                color: "#263746"
                radius: 5
                clip: true
                Image { anchors.fill: parent; source: app.currentThumbnailDataUrl; fillMode: Image.PreserveAspectCrop }
                PlayerIcon { anchors.centerIn: parent; width: 38; height: 38; name: "audio"; ink: "#9aafc3"; visible: app.currentThumbnailDataUrl === "" }
            }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 8
                Text { text: "MAPL / AUDIO"; color: "#9fb9d1"; font.pixelSize: 10; font.letterSpacing: 1.2 }
                Text {
                    Layout.fillWidth: true
                    text: root.track ? root.track.title : "Open something to play"
                    color: "#edf3fa"
                    font.pixelSize: 18
                    font.bold: true
                    wrapMode: Text.WordWrap
                    maximumLineCount: 2
                    elide: Text.ElideRight
                }
                Text { Layout.fillWidth: true; text: root.track ? root.track.artist || "Unknown artist" : "Drop media here, or use File to open it."; color: "#b4c5d6"; font.pixelSize: 12; elide: Text.ElideRight }
                Text {
                    visible: root.track !== null && root.track !== undefined
                    text: root.track ? root.track.url.toString().split(".").pop().toUpperCase() + "  ·  " + app.formatTime(app.mediaPlayer.duration / 1000) + "  ·  Track " + (app.currentTrackIndex + 1) + " of " + app.playlist.length : ""
                    color: "#a4b7ca"
                    font.pixelSize: 11
                }
                Row {
                    spacing: 3
                    height: 16
                    visible: app.visualizerEnabled && !app.reduceMotion && app.mediaPlayer.playbackState === MediaPlayer.PlayingState
                    Repeater {
                        model: 9
                        Rectangle {
                            width: 3; height: 5; radius: 1; color: "#86b7ec"
                            anchors.bottom: parent.bottom
                            SequentialAnimation on height {
                                loops: Animation.Infinite
                                running: root.visible && app.visualizerEnabled && !app.reduceMotion && app.mediaPlayer.playbackState === MediaPlayer.PlayingState
                                NumberAnimation { to: 16; duration: 240 + index * 40 }
                                NumberAnimation { to: 4; duration: 290 + index * 30 }
                            }
                        }
                    }
                }
                RowLayout {
                    visible: !root.track
                    DesktopButton { text: "Open media…"; onClicked: app.openMediaDialog() }
                    DesktopButton { text: "Recent files…"; onClicked: app.openRecentFiles() }
                }
            }
        }
        DesktopButton {
            Layout.fillWidth: true
            implicitHeight: 52
            text: app.activeSubtitleText !== "" ? app.activeSubtitleText : app.currentLyrics !== "" ? "Plain lyrics loaded · open Lyrics & Subs" : "Lyrics & Subs · load a file or generate timed lines"
            hint: "Open live lyrics and subtitles"
            onClicked: app.togglePanel("lyrics")
        }
        RowLayout {
            Layout.fillWidth: true
            Text { text: "QUEUE · " + app.playlist.length; color: "#a4b7ca"; font.pixelSize: 10; font.letterSpacing: 1; Layout.fillWidth: true }
            DesktopButton {
                visible: app.playlist.length > 1
                glyph: "next"
                text: "Up next"
                hint: app.playlist.length > 0 ? app.playlist[(app.currentTrackIndex + 1) % app.playlist.length].title : "Up next"
                onClicked: app.playNext()
            }
        }
        ListView {
            id: queue
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            model: app.playlist
            ScrollBar.vertical: ScrollBar {}
            delegate: ItemDelegate {
                id: queueTrack
                width: queue.width
                height: 34
                contentItem: Text { text: (index + 1) + ".  " + modelData.title; color: index === app.currentTrackIndex ? "#a4cfff" : "#c2ceda"; font.pixelSize: 12; elide: Text.ElideRight; verticalAlignment: Text.AlignVCenter }
                background: Rectangle { radius: 4; color: index === app.currentTrackIndex ? "#2c4155" : queueTrack.hovered ? "#263746" : "transparent" }
                onClicked: { app.loadTrack(index); app.playCurrentTrack(); }
            }
        }
    }
}
