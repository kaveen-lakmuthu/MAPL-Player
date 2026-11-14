import QtQuick
import QtQuick.Layouts
import QtMultimedia

RowLayout {
    id: root
    required property var app
    spacing: 4
    DesktopButton { glyph: "previous"; hint: "Previous track (P)"; enabled: app.playlist.length > 0; onClicked: app.playPrev() }
    DesktopButton { glyph: "back"; hint: "Back 5 seconds (Left)"; enabled: app.mediaPlayer.seekable; onClicked: app.seekRelative(-5) }
    DesktopButton {
        objectName: "playPauseButton"
        glyph: app.mediaPlayer.playbackState === MediaPlayer.PlayingState ? "pause" : "play"
        hint: app.mediaPlayer.playbackState === MediaPlayer.PlayingState ? "Pause (Space)" : "Play (Space)"
        prominent: true
        implicitWidth: 38
        onClicked: app.togglePlayPause()
    }
    DesktopButton { glyph: "forward"; hint: "Forward 5 seconds (Right)"; enabled: app.mediaPlayer.seekable; onClicked: app.seekRelative(5) }
    DesktopButton { glyph: "next"; hint: "Next track (N)"; enabled: app.playlist.length > 0; onClicked: app.playNext() }
}
