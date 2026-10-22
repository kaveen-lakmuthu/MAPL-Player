import QtQuick
import QtTest

TestCase {
    id: testCase
    name: "SubtitleJobs"
    property var app
    property var chunks: [
        {
            start: 0,
            end: 1,
            text: "Generated A."
        }
    ]
    Component {
        id: appComponent
        MockApp {}
    }
    function init() {
        app = createTemporaryObject(appComponent, testCase);
        verify(app !== null);
        app.loadExamplePlaylist(0);
    }
    function start() {
        app.generateSubtitlesForCurrentTrack();
    }
    function test_cancelWaitsForCleanupAndCanRetry() {
        start();
        app.subtitleGenerator.progressChanged(25);
        app.cancelSubtitleGeneration();
        verify(app.subtitleGenerator.isProcessing);
        verify(app.subtitleGenerator.isCancelling);
        compare(app.subtitleGenerationRequest, null);
        app.subtitleGenerator.progressChanged(80);
        compare(app.transcriptionProgressValue, 25);
        start();
        compare(app.subtitleGenerator.calls.length, 1);
        app.subtitleGenerator.finishCancellation();
        compare(app.subtitleChunks.length, 0);
        compare(app.transcriptionProgressValue, 0);
        compare(app.messageText, "Subtitle generation cancelled.");
        start();
        compare(app.subtitleGenerator.calls.length, 2);
        app.subtitleGenerator.complete(chunks);
        compare(app.subtitleChunks[0].text, "Generated A.");
    }
    function test_switchCancelsWithoutChangingNewTrackNotification() {
        start();
        app.loadTrack(1);
        compare(app.subtitleGenerator.cancelCalls, 1);
        app.messageText = "B selected";
        app.subtitleGenerator.finishCancellation();
        compare(app.messageText, "B selected");
        compare(app.subtitleChunks.length, 0);
    }
    function test_cancelThenSwitchKeepsNewTrackNotification() {
        start();
        app.cancelSubtitleGeneration();
        app.loadTrack(1);
        app.messageText = "B selected";
        app.subtitleGenerator.finishCancellation();
        compare(app.messageText, "B selected");
    }
    function test_currentRequestCompletes() {
        start();
        compare(app.subtitleGenerator.calls.length, 1);
        compare(app.subtitleGenerator.calls[0].mediaPath, "file:///A.mp4");
        app.subtitleGenerator.progressChanged(35);
        compare(app.transcriptionProgressValue, 35);
        app.subtitleGenerator.complete(chunks);
        compare(app.subtitleChunks[0].text, "Generated A.");
        compare(app.transcriptionProgressValue, 100);
        compare(app.currentView, "lyrics");
    }
    function test_staleResults_data() {
        return [
            {
                tag: "switch",
                action: "switch"
            },
            {
                tag: "reload",
                action: "reload"
            },
            {
                tag: "return-to-A",
                action: "return"
            },
            {
                tag: "no-selection",
                action: "none"
            }
        ];
    }
    function test_staleResults(data) {
        start();
        if (data.action === "switch")
            app.loadTrack(1);
        else if (data.action === "reload")
            app.loadTrack(0);
        else if (data.action === "return") {
            app.loadTrack(1);
            app.loadTrack(0);
        } else
            app.currentTrackIndex = -1;
        app.subtitleChunks = [
            {
                start: 0,
                end: 1,
                text: "Keep current subtitles."
            }
        ];
        app.currentView = "playlist";
        app.messageText = "Keep notification.";
        app.transcriptionProgressValue = 17;
        app.subtitleGenerator.progressChanged(80);
        app.subtitleGenerator.complete(chunks);
        compare(app.subtitleChunks[0].text, "Keep current subtitles.");
        compare(app.currentView, "playlist");
        compare(app.messageText, "Keep notification.");
        compare(app.transcriptionProgressValue, 17);
    }
    function test_busyRequestCannotBeRetargeted() {
        start();
        app.loadTrack(1);
        start();
        compare(app.subtitleGenerator.calls.length, 1);
        app.subtitleGenerator.complete(chunks);
        compare(app.subtitleChunks.length, 0);
        start();
        compare(app.subtitleGenerator.calls[1].mediaPath, "file:///B.mp4");
        app.subtitleGenerator.complete([
            {
                start: 0,
                end: 1,
                text: "Generated B."
            }
        ]);
        compare(app.subtitleChunks[0].text, "Generated B.");
    }
    function test_downloadKeepsOriginalOptions() {
        app.modelDownloader.cached = false;
        app.translateSubtitles = true;
        start();
        app.subtitleModel = "base";
        app.subtitleLanguage = "Spanish";
        app.translateSubtitles = false;
        app.modelDownloader.complete();
        var call = app.subtitleGenerator.calls[0];
        compare(call.mediaPath, "file:///A.mp4");
        compare(call.modelPath, "/models/ggml-tiny.bin");
        compare(call.language, "English");
        verify(call.translate);
        app.subtitleGenerator.complete(chunks);
        compare(app.subtitleChunks[0].text, "Generated A.");
    }
    function test_downloadAfterSwitchDoesNotStartTranscription() {
        app.modelDownloader.cached = false;
        start();
        app.loadTrack(1);
        start(); // Ignored while the model is downloading.
        app.modelDownloader.complete();
        compare(app.subtitleGenerator.calls.length, 0);
        compare(app.modelDownloader.calls.length, 1);
        start();
        compare(app.subtitleGenerator.calls[0].mediaPath, "file:///B.mp4");
    }
    function test_downloadAfterDeselectionIsHarmless() {
        app.modelDownloader.cached = false;
        start();
        app.currentTrackIndex = -1;
        app.modelDownloader.complete();
        compare(app.subtitleGenerator.calls.length, 0);
    }
    function test_staleErrorDoesNotReplaceNotification() {
        start();
        app.loadTrack(1);
        app.messageText = "Keep B notification.";
        app.subtitleGenerator.fail("A failed");
        compare(app.messageText, "Keep B notification.");
    }
    function test_downloadErrorCanRetry() {
        app.modelDownloader.cached = false;
        start();
        app.modelDownloader.fail("Download failed");
        compare(app.messageText, "Download Error: Download failed");
        app.modelDownloader.cached = true;
        start();
        app.subtitleGenerator.complete(chunks);
        compare(app.subtitleChunks[0].text, "Generated A.");
    }
    function test_reindexingDoesNotInvalidateTheSameMedia() {
        start();
        app.playlist = [app.track("file:///B.mp4", "B"), app.track("file:///A.mp4", "A")];
        app.currentTrackIndex = 1;
        app.subtitleGenerator.complete(chunks);
        compare(app.subtitleChunks[0].text, "Generated A.");
    }
    function test_managementDownloadFailureDoesNotDiscardRunningTranscription() {
        start();
        app.modelDownloader.startDownload("base");
        app.modelDownloader.fail("Base download failed");
        verify(app.subtitleGenerationRequest !== null);
        app.subtitleGenerator.complete(chunks);
        compare(app.subtitleChunks[0].text, "Generated A.");
    }
    function test_unrelatedReadySignalCannotStartGeneration() {
        app.modelDownloader.cached = false;
        start();
        app.modelDownloader.modelReady("base", "/models/ggml-base.bin");
        compare(app.subtitleGenerator.calls.length, 0);
        verify(app.subtitleGenerationRequest !== null);
        app.modelDownloader.complete();
        compare(app.subtitleGenerator.calls[0].modelPath, "/models/ggml-tiny.bin");
    }
    function test_cancelledModelPreparationCannotStartGeneration() {
        app.modelDownloader.cached = false;
        start();
        app.modelDownloader.isDownloading = false;
        app.modelDownloader.operationCancelled("tiny");
        compare(app.subtitleGenerationRequest, null);
        compare(app.messageText, "Model preparation cancelled.");
        app.modelDownloader.modelReady("tiny", "/models/ggml-tiny.bin");
        compare(app.subtitleGenerator.calls.length, 0);
    }
    function test_verificationBlocksNewRequests() {
        app.modelDownloader.isVerifying = true;
        start();
        compare(app.subtitleGenerationRequest, null);
        compare(app.subtitleGenerator.calls.length, 0);
    }
    function test_managementDownloadDoesNotStartGeneration() {
        app.modelDownloader.startDownload("base");
        app.modelDownloader.complete();
        compare(app.subtitleGenerator.calls.length, 0);
    }
    function test_noSelectionCannotStart() {
        app.currentTrackIndex = -1;
        start();
        compare(app.subtitleGenerator.calls.length, 0);
        compare(app.modelDownloader.calls.length, 0);
    }
}
