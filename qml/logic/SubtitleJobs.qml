import QtQml

QtObject {
    required property var app
    property var cancellationRequest: null

    function isSubtitleGenerationRequestCurrent(request) {
        return request !== null && request.mediaRevision === app.mediaRevision && app.currentTrackIndex >= 0 && app.currentTrackIndex < app.playlist.length && request.mediaUrl === app.playlist[app.currentTrackIndex].url.toString();
    }

    function generateSubtitlesForCurrentTrack() {
        if (app.currentTrackIndex < 0 || app.currentTrackIndex >= app.playlist.length || app.modelDownloader.isBusy || app.subtitleGenerator.isProcessing)
            return;
        var request = {
            mediaUrl: app.playlist[app.currentTrackIndex].url.toString(),
            mediaRevision: app.mediaRevision,
            language: app.subtitleLanguage,
            translate: app.translateSubtitles,
            model: app.subtitleModel
        };
        app.subtitleGenerationRequest = request;
        app.transcriptionProgressValue = 0;

        app.modelDownloader.prepareModel(request.model);
    }

    function cancelGeneration() {
        cancellationRequest = app.subtitleGenerationRequest;
        app.subtitleGenerationRequest = null;
        app.subtitleGenerator.cancel();
    }

    property Connections subGeneratorConnections: Connections {
        target: app.subtitleGenerator
        function onCancelled() {
            app.subtitleGenerationRequest = null;
            if (isSubtitleGenerationRequestCurrent(cancellationRequest)) {
                app.transcriptionProgressValue = 0;
                app.showMessage("Subtitle generation cancelled.");
            }
            cancellationRequest = null;
        }

        function onProgressChanged(progress) {
            if (isSubtitleGenerationRequestCurrent(app.subtitleGenerationRequest)) {
                app.transcriptionProgressValue = progress;
            }
        }

        function onSubtitlesReady(chunks) {
            var request = app.subtitleGenerationRequest;
            app.subtitleGenerationRequest = null;
            if (!isSubtitleGenerationRequestCurrent(request))
                return;
            app.subtitleChunks = chunks;
            app.transcriptionProgressValue = 100;
            app.currentView = "lyrics";
            app.showMessage("Subtitles generated successfully!");
        }

        function onErrorOccurred(errorMsg) {
            var request = app.subtitleGenerationRequest;
            app.subtitleGenerationRequest = null;
            if (isSubtitleGenerationRequestCurrent(request)) {
                app.showMessage("Error: " + errorMsg);
            }
        }
    }

    property Connections modelDownloaderConnections: Connections {
        target: app.modelDownloader
        function onProgressChanged(progress) {
            app.downloadProgressValue = progress;
        }

        function onModelReady(modelName, filePath) {
            var request = app.subtitleGenerationRequest;
            if (!isSubtitleGenerationRequestCurrent(request)) {
                app.subtitleGenerationRequest = null;
                return;
            }
            if (request.model !== modelName)
                return;
            app.subtitleGenerator.generateSubtitles(request.mediaUrl, filePath, request.language, request.translate);
        }

        function onOperationCancelled(modelName) {
            var request = app.subtitleGenerationRequest;
            if (request !== null && request.model === modelName) {
                app.subtitleGenerationRequest = null;
                if (isSubtitleGenerationRequestCurrent(request))
                    app.showMessage("Model preparation cancelled.");
            }
        }

        function onModelError(modelName, errorMsg) {
            var request = app.subtitleGenerationRequest;
            if (request === null || request.model !== modelName || app.subtitleGenerator.isProcessing)
                return;
            app.subtitleGenerationRequest = null;
            if (isSubtitleGenerationRequestCurrent(request)) {
                app.showMessage("Download Error: " + errorMsg);
            }
        }
    }
}
