import QtQuick
import QtQuick.Window
import QtQuick.Layouts
import QtQuick.Controls

RowLayout {
    id: root
    required property var app
    property alias volumeSlider: volume.slider
    spacing: 4
    TransportButtons { app: root.app }
    DesktopButton {
        glyph: "loop"
        hint: "Loop playlist"
        selected: app.loopPlaylist
        onClicked: { app.loopPlaylist = !app.loopPlaylist; app.playerController.saveLoop(app.loopPlaylist); }
    }
    Text {
        Layout.fillWidth: true
        Layout.minimumWidth: 0
        Layout.leftMargin: 8
        text: root.width >= 800 && app.currentTrackIndex >= 0 && app.playlist[app.currentTrackIndex] ? app.playlist[app.currentTrackIndex].title : ""
        color: "#b3c5d7"
        font.pixelSize: 11
        elide: Text.ElideRight
    }
    DesktopButton {
        glyph: "captions"
        hint: "Choose subtitle track"
        visible: app.availableSubtitles.length > 0
        onClicked: app.subtitlePickerVisible = !app.subtitlePickerVisible
    }
    DesktopButton { glyph: "chapters"; hint: "Chapters"; visible: app.mediaChapters.length > 0; onClicked: app.chaptersPopupVisible = !app.chaptersPopupVisible }
    VolumeControl { id: volume; app: root.app; isNarrow: root.width < 700 }
    DesktopButton {
        glyph: app.visibility === Window.FullScreen ? "restore" : "fullscreen"
        hint: app.visibility === Window.FullScreen ? "Leave fullscreen (F / Esc)" : "Fullscreen (F)"
        onClicked: app.toggleFullscreen()
    }
}
