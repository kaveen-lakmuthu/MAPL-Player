import QtQuick
import QtQuick.Layouts
import QtMultimedia

RowLayout {
    id: root
    required property var app
    property bool spacious: false
    spacing: spacious ? 10 : 4
    DesktopButton {
        glyph: "previous"
        hint: "Previous track (P)"
        enabled: app.previousTrackIndex >= 0
        implicitWidth: root.spacious ? 42 : 32
        implicitHeight: root.spacious ? 42 : 30
        cornerRadius: root.spacious ? 21 : 5
        iconSize: root.spacious ? 20 : 18
        onClicked: app.playPrev()
    }
    DesktopButton {
        glyph: "back"
        hint: "Back 5 seconds (Left)"
        enabled: app.mediaPlayer.seekable
        implicitWidth: root.spacious ? 38 : 32
        implicitHeight: root.spacious ? 38 : 30
        cornerRadius: root.spacious ? 19 : 5
        onClicked: app.seekRelative(-5)
    }
    DesktopButton {
        objectName: "playPauseButton"
        glyph: app.mediaPlayer.playbackState === MediaPlayer.PlayingState ? "pause" : "play"
        hint: app.mediaPlayer.playbackState === MediaPlayer.PlayingState ? "Pause (Space)" : "Play (Space)"
        prominent: true
        implicitWidth: root.spacious ? 60 : 38
        implicitHeight: root.spacious ? 60 : 30
        cornerRadius: root.spacious ? 30 : 5
        iconSize: root.spacious ? 26 : 18
        onClicked: app.togglePlayPause()
    }
    DesktopButton {
        glyph: "forward"
        hint: "Forward 5 seconds (Right)"
        enabled: app.mediaPlayer.seekable
        implicitWidth: root.spacious ? 38 : 32
        implicitHeight: root.spacious ? 38 : 30
        cornerRadius: root.spacious ? 19 : 5
        onClicked: app.seekRelative(5)
    }
    DesktopButton {
        glyph: "next"
        hint: "Next track (N)"
        enabled: app.nextTrackIndex >= 0
        implicitWidth: root.spacious ? 42 : 32
        implicitHeight: root.spacious ? 42 : 30
        cornerRadius: root.spacious ? 21 : 5
        iconSize: root.spacious ? 20 : 18
        onClicked: app.playNext()
    }
}
