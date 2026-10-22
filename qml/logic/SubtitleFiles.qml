import QtQml
import "SubtitleUtils.js" as SubtitleUtils

QtObject {
    required property var app
    property int selectionRevision: 0
    property var pendingEmbedded: null
    property var fileRequest: null

    function invalidate() {
        ++selectionRevision;
        pendingEmbedded = null;
        app.playerController.cancelSubtitleExtraction();
        if (fileRequest !== null) {
            var previous = fileRequest;
            fileRequest = null;
            previous.abort();
        }
    }

    function clear() {
        invalidate();
        app.subtitleChunks = [];
        app.currentLyrics = "";
        app.activeSubtitleText = "";
        app.activeSubtitleUrl = "";
        app.activeEmbeddedTrackIndex = -1;
        app.mediaPlayer.activeSubtitleTrack = -1;
    }

    function selectEmbedded(trackIndex) {
        invalidate();
        if (app.currentTrackIndex < 0 || app.currentTrackIndex >= app.playlist.length)
            return;
        pendingEmbedded = {
            id: selectionRevision,
            mediaRevision: app.mediaRevision,
            trackIndex: trackIndex
        };
        app.mediaPlayer.activeSubtitleTrack = -1;
        app.playerController.extractEmbeddedSubtitle(app.playlist[app.currentTrackIndex].url.toString(), trackIndex, selectionRevision);
        app.showMessage("Extracting embedded subtitles…");
    }

    function load(fileUrl, embeddedIndex, showTranscript) {
        invalidate();
        var revision = selectionRevision;
        var mediaRevision = app.mediaRevision;
        var url = fileUrl.toString();
        var request = new XMLHttpRequest();
        fileRequest = request;
        request.open("GET", url, true);
        request.onreadystatechange = function () {
            if (revision !== selectionRevision || mediaRevision !== app.mediaRevision || request.readyState !== XMLHttpRequest.DONE)
                return;
            fileRequest = null;
            if (request.status === 200 || (request.status === 0 && request.responseText !== "")) {
                if (url.toLowerCase().endsWith(".txt")) {
                    app.subtitleChunks = [];
                    app.currentLyrics = request.responseText;
                    app.activeSubtitleText = "";
                    app.activeSubtitleUrl = url;
                    app.activeEmbeddedTrackIndex = -1;
                    app.mediaPlayer.activeSubtitleTrack = -1;
                    app.currentView = "lyrics";
                    app.showMessage("Lyrics loaded.");
                    return;
                }
                var chunks = url.toLowerCase().endsWith(".vtt") ? SubtitleUtils.parseVTT(request.responseText) : SubtitleUtils.parseSRT(request.responseText);
                if (chunks.length > 0) {
                    app.subtitleChunks = chunks;
                    app.currentLyrics = "";
                    app.mediaPlayer.activeSubtitleTrack = -1;
                    app.activeSubtitleUrl = url;
                    app.activeEmbeddedTrackIndex = embeddedIndex === undefined ? -1 : embeddedIndex;
                    if (showTranscript)
                        app.currentView = "lyrics";
                    app.showMessage("Subtitles loaded.");
                } else {
                    app.showMessage("Failed to parse subtitle file.");
                }
            } else {
                app.showMessage("Failed to read subtitle file.");
            }
        };
        request.send();
    }

    property Connections extractionConnections: Connections {
        target: app.playerController
        function onEmbeddedSubtitleReady(requestId, fileUrl) {
            var pending = pendingEmbedded;
            if (pending !== null && pending.id === requestId && pending.mediaRevision === app.mediaRevision)
                load(fileUrl, pending.trackIndex);
        }
        function onEmbeddedSubtitleError(requestId, message) {
            var pending = pendingEmbedded;
            if (pending !== null && pending.id === requestId && pending.mediaRevision === app.mediaRevision) {
                pendingEmbedded = null;
                app.showMessage(message);
            }
        }
    }
}
