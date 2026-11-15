import QtQuick
import QtQuick.Window
import QtQuick.Controls
import QtQuick.Controls.Basic as Basic
import QtQuick.Layouts

Rectangle {
    id: root
    required property var app
    readonly property bool menuOpen: fileMenu.visible || optionsMenu.visible
    implicitHeight: 40
    color: app.chromeColor

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 8
        anchors.rightMargin: 8
        spacing: 5
        DesktopButton {
            id: fileButton
            objectName: "fileMenuButton"
            text: "File"
            hint: "Open files and recent media"
            onClicked: fileMenu.open()
            Basic.Menu {
                id: fileMenu
                objectName: "fileMenu"
                y: fileButton.height + 4
                width: 250
                Basic.MenuItem { text: "Open media…"; onTriggered: app.openMediaDialog() }
                Basic.MenuItem { text: "Open XSPF playlist…"; onTriggered: app.openPlaylistDialog() }
                Basic.MenuItem { text: "Load lyrics or subtitles…"; onTriggered: app.openLyricsDialog() }
                Basic.MenuSeparator {}
                Basic.MenuItem { objectName: "recentFilesButton"; text: "Recent files…"; onTriggered: app.openRecentFiles() }
                Basic.MenuSeparator {}
                Basic.MenuItem { text: "Quit"; onTriggered: app.close() }
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
            text: "Thumbnail"
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
            Basic.Menu {
                id: optionsMenu
                objectName: "optionsMenu"
                x: optionsButton.width - width
                y: optionsButton.height + 4
                width: 270
                Basic.Menu {
                    title: "Playback and audio"
                    Basic.MenuItem { text: "Audio tracks, speed and delay…"; onTriggered: app.openPlaybackOptions() }
                    Basic.MenuItem {
                        text: "Loop playlist"; checkable: true; checked: app.loopPlaylist
                        onTriggered: { app.loopPlaylist = !app.loopPlaylist; app.playerController.saveLoop(app.loopPlaylist); }
                    }
                    Basic.MenuItem {
                        text: "Auto-load folder files"; checkable: true; checked: app.playFolderToggle
                        onTriggered: { app.playFolderToggle = !app.playFolderToggle; app.playerController.savePlayFolderToggle(app.playFolderToggle); }
                    }
                }
                Basic.Menu {
                    objectName: "subtitleOptionsMenu"
                    title: "Subtitles"
                    Basic.MenuItem { text: "Load lyrics or subtitles…"; onTriggered: app.openLyricsDialog() }
                    Basic.MenuItem { text: "Appearance, timing and export…"; onTriggered: app.openSubtitleSettings() }
                    Basic.MenuItem { text: "Choose subtitle track…"; enabled: app.availableSubtitles.length > 0; onTriggered: app.subtitlePickerVisible = true }
                    Basic.MenuItem { text: "Generate lyrics and subtitles…"; onTriggered: app.openSubtitleGenerator() }
                    Basic.MenuItem { objectName: "modelsButton"; text: "Whisper models…"; onTriggered: app.openModelManager() }
                    Basic.MenuItem { text: "Clear lyrics and subtitles"; enabled: app.subtitleChunks.length > 0 || app.currentLyrics !== ""; onTriggered: app.clearSubtitles() }
                }
                Basic.Menu {
                    objectName: "appearanceMenu"
                    title: "Appearance"
                    Basic.MenuItem {
                        objectName: "ambientToggle"
                        text: "Ambient color"; checkable: true; checked: app.ambientEnabled
                        onTriggered: app.ambientEnabled = !app.ambientEnabled
                    }
                    Basic.Menu {
                        title: "Ambient strength"
                        Basic.MenuItem { text: "5%"; checkable: true; checked: Math.abs(app.ambientStrength - 0.05) < 0.001; onTriggered: app.ambientStrength = 0.05 }
                        Basic.MenuItem { text: "12%"; checkable: true; checked: Math.abs(app.ambientStrength - 0.12) < 0.001; onTriggered: app.ambientStrength = 0.12 }
                        Basic.MenuItem { text: "20%"; checkable: true; checked: Math.abs(app.ambientStrength - 0.20) < 0.001; onTriggered: app.ambientStrength = 0.20 }
                        Basic.MenuItem { text: "25%"; checkable: true; checked: Math.abs(app.ambientStrength - 0.25) < 0.001; onTriggered: app.ambientStrength = 0.25 }
                    }
                    Basic.MenuItem { text: "Audio visualizer"; checkable: true; checked: app.visualizerEnabled; onTriggered: app.visualizerEnabled = !app.visualizerEnabled }
                    Basic.MenuItem { text: "Reduce motion"; checkable: true; checked: app.reduceMotion; onTriggered: app.reduceMotion = !app.reduceMotion }
                }
                Basic.MenuItem { text: "Fullscreen"; onTriggered: app.toggleFullscreen() }
                Basic.MenuSeparator {}
                Basic.MenuItem { text: "About MAPL…"; onTriggered: app.openAboutDialog() }
            }
        }
    }
}
