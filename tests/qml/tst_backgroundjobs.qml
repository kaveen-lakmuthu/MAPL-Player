import QtQuick
import QtTest

TestCase {
    id: testCase
    name: "BackgroundMediaJobs"
    property var app
    Component {
        id: appComponent
        MockApp {}
    }
    function init() {
        app = createTemporaryObject(appComponent, testCase);
        verify(app !== null);
        app.loadExamplePlaylist(0);
    }
    function latestExtraction() {
        var calls = app.playerController.extractionCalls;
        return calls[calls.length - 1];
    }
    function test_chaptersIgnoreSupersededTrackAndReload() {
        var originalId = app.mediaRevision;
        app.mediaChapters = [
            {
                time: 0,
                title: "A"
            }
        ];
        app.loadTrack(1);
        compare(app.mediaChapters.length, 0);
        app.playerController.mediaChaptersReady(originalId, [
            {
                time: 0,
                title: "Old A"
            }
        ]);
        compare(app.mediaChapters.length, 0);
        var secondId = app.mediaRevision;
        app.loadTrack(1);
        app.playerController.mediaChaptersReady(secondId, [
            {
                time: 0,
                title: "Old B"
            }
        ]);
        compare(app.mediaChapters.length, 0);
        app.playerController.mediaChaptersReady(app.mediaRevision, [
            {
                time: 3,
                title: "Current B"
            }
        ]);
        compare(app.mediaChapters[0].title, "Current B");
    }
    function test_embeddedExtractionCompletesAsynchronously() {
        app.selectEmbeddedSubtitle(2);
        var call = latestExtraction();
        compare(call.url, "file:///A.mp4");
        compare(call.index, 2);
        compare(app.subtitleChunks.length, 0);
        app.playerController.embeddedSubtitleReady(call.id, Qt.resolvedUrl("fixtures/one.srt"));
        tryCompare(app, "activeEmbeddedTrackIndex", 2);
        compare(app.subtitleChunks[0].text, "Embedded A.");
    }
    function test_oldExtractionCannotAttachAfterSwitchOrReload_data() {
        return [
            {
                tag: "switch",
                index: 1
            },
            {
                tag: "reload",
                index: 0
            }
        ];
    }
    function test_oldExtractionCannotAttachAfterSwitchOrReload(data) {
        app.selectEmbeddedSubtitle(0);
        var call = latestExtraction();
        app.loadTrack(data.index);
        app.messageText = "Keep message";
        app.playerController.embeddedSubtitleReady(call.id, Qt.resolvedUrl("fixtures/one.srt"));
        app.playerController.embeddedSubtitleError(call.id, "Old error");
        wait(30);
        compare(app.subtitleChunks.length, 0);
        compare(app.activeEmbeddedTrackIndex, -1);
        compare(app.messageText, "Keep message");
    }
    function test_subtitlesOffInvalidatesExtraction() {
        app.selectEmbeddedSubtitle(0);
        var call = latestExtraction();
        app.clearSubtitles();
        app.playerController.embeddedSubtitleReady(call.id, Qt.resolvedUrl("fixtures/one.srt"));
        wait(30);
        compare(app.subtitleChunks.length, 0);
    }
    function test_latestEmbeddedSelectionWins() {
        app.selectEmbeddedSubtitle(0);
        var first = latestExtraction();
        app.selectEmbeddedSubtitle(1);
        var second = latestExtraction();
        app.playerController.embeddedSubtitleReady(first.id, Qt.resolvedUrl("fixtures/one.srt"));
        compare(app.subtitleFiles.pendingEmbedded.id, second.id);
        app.playerController.embeddedSubtitleReady(second.id, Qt.resolvedUrl("fixtures/one.srt"));
        tryCompare(app, "activeEmbeddedTrackIndex", 1);
    }
    function test_externalSelectionInvalidatesExtraction() {
        app.selectEmbeddedSubtitle(0);
        var call = latestExtraction();
        app.loadSubtitleFile(Qt.resolvedUrl("fixtures/one.srt"));
        app.playerController.embeddedSubtitleReady(call.id, "file:///missing.srt");
        tryVerify(function () {
            return app.subtitleChunks.length === 1;
        });
        compare(app.activeEmbeddedTrackIndex, -1);
        compare(app.subtitleChunks[0].text, "Embedded A.");
    }
    function test_fileReadCannotUndoSubtitlesOffOrTrackSwitch_data() {
        return [
            {
                tag: "off",
                switchTrack: false
            },
            {
                tag: "switch",
                switchTrack: true
            }
        ];
    }
    function test_fileReadCannotUndoSubtitlesOffOrTrackSwitch(data) {
        app.loadSubtitleFile(Qt.resolvedUrl("fixtures/one.srt"));
        if (data.switchTrack)
            app.loadTrack(1);
        else
            app.clearSubtitles();
        wait(30);
        compare(app.subtitleChunks.length, 0);
        compare(app.activeEmbeddedTrackIndex, -1);
    }
    function test_lyricsSelectionInvalidatesEmbeddedExtraction() {
        app.selectEmbeddedSubtitle(0);
        var call = latestExtraction();
        app.loadSubtitleFile(Qt.resolvedUrl("fixtures/lyrics.txt"));
        app.playerController.embeddedSubtitleReady(call.id, "file:///missing.srt");
        tryVerify(function () {
            return app.currentLyrics.length > 0;
        });
        compare(app.currentLyrics.trim(), "Plain lyrics.");
        compare(app.subtitleChunks.length, 0);
        compare(app.activeEmbeddedTrackIndex, -1);
        compare(app.currentView, "lyrics");
    }
    function test_lyricsReadCannotAttachAfterSwitch() {
        app.loadSubtitleFile(Qt.resolvedUrl("fixtures/lyrics.txt"));
        app.loadTrack(1);
        wait(30);
        compare(app.currentLyrics, "");
    }
    function test_extractionFailureCanRetry() {
        app.selectEmbeddedSubtitle(0);
        app.playerController.embeddedSubtitleError(latestExtraction().id, "Failed extraction");
        compare(app.messageText, "Failed extraction");
        compare(app.subtitleFiles.pendingEmbedded, null);
        app.selectEmbeddedSubtitle(0);
        app.playerController.embeddedSubtitleReady(latestExtraction().id, Qt.resolvedUrl("fixtures/one.srt"));
        tryCompare(app, "activeEmbeddedTrackIndex", 0);
    }
}
