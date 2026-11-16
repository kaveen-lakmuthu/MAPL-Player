import QtQuick
import QtQuick.Window
import QtQuick.Controls
import QtQuick.Layouts

Rectangle {
    id: root
    required property var app
    readonly property bool menuOpen: fileMenu.visible || optionsMenu.visible
    implicitHeight: 40
    color: app.chromeColor

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 12
        anchors.rightMargin: 12
        spacing: 8
        DesktopButton {
            id: fileButton
            objectName: "fileMenuButton"
            text: "File"
            hint: "Open files and recent media"
            onClicked: fileMenu.open()
            DesktopMenu {
                id: fileMenu
                objectName: "fileMenu"
                y: fileButton.height + 6
                width: 260
                DesktopMenuItem { text: "Open media…"; onTriggered: app.openMediaDialog() }
                DesktopMenuItem { text: "Open XSPF playlist…"; onTriggered: app.openPlaylistDialog() }
                DesktopMenuItem { text: "Load lyrics or subtitles…"; onTriggered: app.openLyricsDialog() }
                DesktopMenuSeparator {}
                DesktopMenuItem { objectName: "recentFilesButton"; text: "Recent files…"; onTriggered: app.openRecentFiles() }
                DesktopMenuSeparator {}
                DesktopMenuItem { text: "Quit"; onTriggered: app.close() }
            }
        }
        DesktopButton { objectName: "videoViewButton"; text: "Video"; selected: app.mediaView === "video"; onClicked: app.showMediaView("video") }
        DesktopButton { objectName: "audioViewButton"; text: "Audio"; selected: app.mediaView === "audio"; onClicked: app.showMediaView("audio") }
        DesktopButton { objectName: "lyricsPanelButton"; text: "Lyrics & Subs"; selected: app.panelView === "lyrics"; onClicked: app.togglePanel("lyrics") }
        DesktopButton { objectName: "playlistPanelButton"; text: "Playlist"; selected: app.panelView === "playlist"; onClicked: app.togglePanel("playlist") }
        Item { Layout.fillWidth: true }
        DesktopButton {
            objectName: "thumbnailButton"
            glyph: "image"
            text: root.width >= 760 ? "Thumbnail" : ""
            hint: "Save the current video frame as this track’s thumbnail"
            enabled: app.currentTrackIndex >= 0 && app.mediaPlayer.hasVideo && app.playerController.hasVideoFrame
            onClicked: app.captureCurrentThumbnail()
        }
        DesktopButton {
            id: optionsButton
            objectName: "optionsMenuButton"
            glyph: "settings"
            text: root.width >= 700 ? "Options" : ""
            hint: "Playback, subtitles and appearance options"
            onClicked: optionsMenu.open()
            DesktopMenu {
                id: optionsMenu
                objectName: "optionsMenu"
                x: optionsButton.width - width
                y: optionsButton.height + 6
                width: 280
                DesktopMenu {
                    title: "Playback and audio"
                    DesktopMenuItem { text: "Audio tracks, speed and delay…"; onTriggered: app.openPlaybackOptions() }
                    DesktopMenuItem {
                        text: "Loop playlist"; checkable: true; checked: app.loopPlaylist
                        onTriggered: { app.loopPlaylist = !app.loopPlaylist; app.playerController.saveLoop(app.loopPlaylist); }
                    }
                    DesktopMenuItem {
                        text: "Auto-load folder files"; checkable: true; checked: app.playFolderToggle
                        onTriggered: { app.playFolderToggle = !app.playFolderToggle; app.playerController.savePlayFolderToggle(app.playFolderToggle); }
                    }
                }
                DesktopMenu {
                    objectName: "subtitleOptionsMenu"
                    title: "Subtitles"
                    DesktopMenuItem { text: "Load lyrics or subtitles…"; onTriggered: app.openLyricsDialog() }
                    DesktopMenuItem { text: "Appearance, timing and export…"; onTriggered: app.openSubtitleSettings() }
                    DesktopMenuItem { text: "Choose subtitle track…"; enabled: app.availableSubtitles.length > 0; onTriggered: app.subtitlePickerVisible = true }
                    DesktopMenuItem { text: "Generate lyrics and subtitles…"; onTriggered: app.openSubtitleGenerator() }
                    DesktopMenuItem { objectName: "modelsButton"; text: "Whisper models…"; onTriggered: app.openModelManager() }
                    DesktopMenuItem { text: "Clear lyrics and subtitles"; enabled: app.subtitleChunks.length > 0 || app.currentLyrics !== ""; onTriggered: app.clearSubtitles() }
                }
                DesktopMenu {
                    objectName: "appearanceMenu"
                    title: "Appearance"
                    DesktopMenuItem {
                        objectName: "ambientToggle"
                        text: "Ambient color"; checkable: true; checked: app.ambientEnabled
                        onTriggered: app.ambientEnabled = !app.ambientEnabled
                    }
                    DesktopMenu {
                        title: "Ambient strength"
                        DesktopMenuItem { text: "5%"; checkable: true; checked: Math.abs(app.ambientStrength - 0.05) < 0.001; onTriggered: app.ambientStrength = 0.05 }
                        DesktopMenuItem { text: "12%"; checkable: true; checked: Math.abs(app.ambientStrength - 0.12) < 0.001; onTriggered: app.ambientStrength = 0.12 }
                        DesktopMenuItem { text: "20%"; checkable: true; checked: Math.abs(app.ambientStrength - 0.20) < 0.001; onTriggered: app.ambientStrength = 0.20 }
                        DesktopMenuItem { text: "25%"; checkable: true; checked: Math.abs(app.ambientStrength - 0.25) < 0.001; onTriggered: app.ambientStrength = 0.25 }
                    }
                    DesktopMenuItem { text: "Audio visualizer"; checkable: true; checked: app.visualizerEnabled; onTriggered: app.visualizerEnabled = !app.visualizerEnabled }
                    DesktopMenuItem { text: "Reduce motion"; checkable: true; checked: app.reduceMotion; onTriggered: app.reduceMotion = !app.reduceMotion }
                }
                DesktopMenuItem { text: "Fullscreen"; onTriggered: app.toggleFullscreen() }
                DesktopMenuSeparator {}
                DesktopMenuItem { text: "About MAPL…"; onTriggered: app.openAboutDialog() }
            }
        }
    }
}
