import QtQuick
import QtQuick.Window
import QtQuick.Layouts
import QtQuick.Controls

Item {
    id: root
    objectName: "transportControls"
    required property var app
    property bool spacious: false
    property alias volumeSlider: volume.slider
    implicitHeight: Math.max(playback.implicitHeight, loop.implicitHeight, extras.implicitHeight)

    TransportButtons {
        id: playback
        app: root.app
        spacious: root.spacious
        anchors.verticalCenter: parent.verticalCenter
        x: root.spacious ? Math.max(loop.width + 12, Math.min((root.width - width) / 2, extras.x - width - 12)) : 0
    }
    DesktopButton {
        id: loop
        glyph: "loop"
        hint: "Loop playlist"
        selected: app.loopPlaylist
        x: root.spacious ? 0 : playback.width + 10
        anchors.verticalCenter: parent.verticalCenter
        onClicked: { app.loopPlaylist = !app.loopPlaylist; app.playerController.saveLoop(app.loopPlaylist); }
    }
    Text {
        anchors.left: loop.right
        anchors.right: extras.left
        anchors.leftMargin: 12
        anchors.rightMargin: 12
        anchors.verticalCenter: parent.verticalCenter
        visible: !root.spacious && root.width >= 800
        text: app.currentTrackIndex >= 0 && app.playlist[app.currentTrackIndex] ? app.playlist[app.currentTrackIndex].title : ""
        color: "#b3c5d7"
        font.pixelSize: 11
        elide: Text.ElideRight
    }
    RowLayout {
        id: extras
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        spacing: 8
        DesktopButton {
            glyph: "captions"
            hint: "Choose subtitle track"
            visible: app.availableSubtitles.length > 0
            onClicked: app.subtitlePickerVisible = !app.subtitlePickerVisible
        }
        DesktopButton { glyph: "chapters"; hint: "Chapters"; visible: app.mediaChapters.length > 0; onClicked: app.chaptersPopupVisible = !app.chaptersPopupVisible }
        VolumeControl { id: volume; app: root.app; isNarrow: root.width < 700 }
        DesktopButton {
            objectName: "fullscreenButton"
            glyph: app.visibility === Window.FullScreen ? "restore" : "fullscreen"
            hint: app.visibility === Window.FullScreen ? "Leave fullscreen (F / Esc)" : "Fullscreen (F)"
            onClicked: app.toggleFullscreen()
        }
    }
}
