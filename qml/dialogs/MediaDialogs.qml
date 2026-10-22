import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Dialogs

Item {
    id: root
    required property var app
    readonly property bool dialogOpen: mediaFileDialog.visible || xspfFileDialog.visible || lyricsFileDialog.visible || exportFileDialog.visible
    function openMediaDialog() {
        mediaFileDialog.open();
    }
    function openPlaylistDialog() {
        xspfFileDialog.open();
    }
    function openLyricsDialog() {
        lyricsFileDialog.open();
    }
    function openExportDialog() {
        exportFileDialog.open();
    }

    FileDialog {
        id: mediaFileDialog
        objectName: "mediaFileDialog"
        parentWindow: app
        modality: Qt.WindowModal
        title: "Select Video/Audio File"
        nameFilters: ["All Media Files (*.mp4 *.mkv *.avi *.mov *.webm *.flv *.m4v *.ts *.ogv *.wmv *.3gp *.mpg *.mpeg *.mp3 *.flac *.wav *.ogg *.m4a *.aac *.opus *.wma *.aiff *.wv *.ape)", "Video Files (*.mp4 *.mkv *.avi *.mov *.webm *.flv *.m4v *.ts *.ogv *.wmv *.3gp *.mpg *.mpeg)", "Audio Files (*.mp3 *.flac *.wav *.ogg *.m4a *.aac *.opus *.wma *.aiff *.wv *.ape)"]
        onAccepted: {
            app.loadMediaFile(selectedFile);
        }
    }

    FileDialog {
        id: xspfFileDialog
        objectName: "playlistFileDialog"
        parentWindow: app
        modality: Qt.WindowModal
        title: "Select XSPF Playlist"
        nameFilters: ["XSPF Playlists (*.xspf)"]
        onAccepted: {
            var fileUrl = selectedFile.toString();
            var request = new XMLHttpRequest();
            request.open("GET", fileUrl, true);
            request.onreadystatechange = function () {
                if (request.readyState === XMLHttpRequest.DONE && request.status === 200) {
                    app.parseXspf(request.responseText);
                }
            };
            request.send();
            app.sidebarOpen = false;
        }
    }

    FileDialog {
        id: lyricsFileDialog
        objectName: "lyricsFileDialog"
        parentWindow: app
        modality: Qt.WindowModal
        title: "Select Lyrics or Subtitles File"
        nameFilters: ["Subtitles & Lyrics (*.srt *.vtt *.txt)"]
        onAccepted: {
            var fileUrl = selectedFile.toString();
            app.loadSubtitleFile(fileUrl);
            app.sidebarOpen = false;
        }
    }

    FileDialog {
        id: exportFileDialog
        objectName: "exportFileDialog"
        parentWindow: app
        modality: Qt.WindowModal
        title: "Export Subtitles As…"
        fileMode: FileDialog.SaveFile
        nameFilters: {
            if (app.pendingExportFormat === "srt")
                return ["SubRip Subtitles (*.srt)"];
            else if (app.pendingExportFormat === "vtt")
                return ["WebVTT Subtitles (*.vtt)"];
            else
                return ["Plain Text (*.txt)"];
        }
        onAccepted: {
            var destPath = selectedFile.toString();
            var content = "";
            if (app.pendingExportFormat === "srt")
                content = app.formatSRTContent();
            else if (app.pendingExportFormat === "vtt")
                content = app.formatVTTContent();
            else
                content = app.formatTXTContent();

            var ok = app.playerController.writeTextToFile(destPath, content);
            app.showMessage(ok ? "Exported " + app.pendingExportFormat.toUpperCase() + " successfully." : "Export failed.");
        }
    }
}
