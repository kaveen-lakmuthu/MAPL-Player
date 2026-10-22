import QtQuick
import QtTest
import QtMultimedia

TestCase {
    id: testCase
    name: "PlaybackMemory"
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
    function rememberB() {
        app.playbackHistory.positions = {
            "file:///B.mp4": 35000
        };
    }
    function ready() {
        app.mediaPlayer.seekable = true;
        app.mediaPlayer.mediaStatus = MediaPlayer.LoadedMedia;
    }
    function test_switchSavesOutgoingFileBeforeSourceResets() {
        app.mediaPlayer.position = 27000;
        rememberB();
        app.loadTrack(1);
        compare(app.playbackHistory.resumePosition("file:///A.mp4"), 27000);
        compare(app.playbackHistory.resumePosition("file:///B.mp4"), 35000);
        compare(app.playbackMemory.pendingResume.position, 35000);
        app.playbackMemory.checkpoint();
        compare(app.playbackHistory.resumePosition("file:///B.mp4"), 35000);
    }
    function test_playlistReplacementSavesTheActualOutgoingFile() {
        app.mediaPlayer.position = 23000;
        app.loadMediaFile("file:///Other.mp3");
        compare(app.playbackHistory.resumePosition("file:///A.mp4"), 23000);
        compare(app.playbackHistory.resumePosition("file:///Other.mp3"), 0);
    }
    function test_pauseAndStopCheckpoint() {
        app.mediaPlayer.position = 18000;
        app.mediaPlayer.pause();
        compare(app.playbackHistory.resumePosition("file:///A.mp4"), 18000);
        app.mediaPlayer.play();
        app.mediaPlayer.position = 29000;
        app.playbackSession.stopPlayback();
        compare(app.mediaPlayer.position, 0);
        compare(app.playbackHistory.resumePosition("file:///A.mp4"), 29000);
    }
    function test_periodicCheckpoint() {
        app.playbackMemory.saveTimer.interval = 20;
        app.mediaPlayer.position = 31000;
        tryVerify(function () {
            return app.playbackHistory.resumePosition("file:///A.mp4") === 31000;
        });
    }
    function test_reopeningWaitsForChoice() {
        rememberB();
        app.loadMediaFile("file:///B.mp4");
        verify(app.playbackMemory.pendingResume !== null);
        verify(app.mediaPlayer.playbackState !== MediaPlayer.PlayingState);
        app.playCurrentTrack();
        verify(app.mediaPlayer.playbackState !== MediaPlayer.PlayingState);
        ready();
        compare(app.mediaPlayer.position, 0);
        app.playbackMemory.resume();
        compare(app.mediaPlayer.position, 35000);
        compare(app.mediaPlayer.playbackState, MediaPlayer.PlayingState);
        compare(app.playbackMemory.pendingResume, null);
    }
    function test_resumePromptDoesNotQueuePauseDuringLoading() {
        rememberB();
        app.loadMediaFile("file:///B.mp4");
        compare(app.mediaPlayer.mediaStatus, MediaPlayer.LoadingMedia);
        compare(app.mediaPlayer.pauseCalls, 0);
        app.playbackMemory.resume();
        ready();
        compare(app.mediaPlayer.playbackState, MediaPlayer.PlayingState);
        compare(app.mediaPlayer.position, 35000);
    }
    function test_resumeBeforeMetadataWaitsForSeekability() {
        rememberB();
        app.loadMediaFile("file:///B.mp4");
        app.mediaPlayer.seekable = false;
        app.playbackMemory.resume();
        compare(app.playbackMemory.pendingSeek, 35000);
        verify(app.mediaPlayer.playbackState !== MediaPlayer.PlayingState);
        app.mediaPlayer.mediaStatus = MediaPlayer.LoadedMedia;
        compare(app.mediaPlayer.position, 0);
        app.mediaPlayer.seekable = true;
        compare(app.mediaPlayer.position, 35000);
        compare(app.mediaPlayer.playbackState, MediaPlayer.PlayingState);
    }
    function test_startOverClearsSavedPosition() {
        rememberB();
        app.loadMediaFile("file:///B.mp4");
        app.playbackMemory.startOver();
        compare(app.playbackHistory.resumePosition("file:///B.mp4"), 0);
        ready();
        compare(app.mediaPlayer.position, 0);
        compare(app.mediaPlayer.playbackState, MediaPlayer.PlayingState);
    }
    function test_switchWhileWaitingDoesNotSeekTheNewFile() {
        rememberB();
        app.loadMediaFile("file:///B.mp4");
        app.playbackMemory.resume();
        app.loadMediaFile("file:///C.mp4");
        ready();
        compare(app.mediaPlayer.position, 0);
        compare(app.playbackHistory.resumePosition("file:///B.mp4"), 35000);
    }
    function test_closingWhilePromptedPreservesSavedPosition() {
        rememberB();
        app.loadTrack(1);
        app.playbackMemory.checkpoint();
        compare(app.playbackHistory.resumePosition("file:///B.mp4"), 35000);
    }
    function test_completedFileIsClearedAndAutoAdvanceHasNoPrompt() {
        app.mediaPlayer.position = 27000;
        app.playbackMemory.checkpoint();
        var positions = app.playbackHistory.positions;
        positions["file:///B.mp4"] = 35000;
        app.playbackHistory.positions = positions;
        app.mediaPlayer.finish();
        compare(app.currentTrackIndex, 1);
        compare(app.playbackHistory.resumePosition("file:///A.mp4"), 0);
        compare(app.playbackMemory.pendingResume, null);
        compare(app.mediaPlayer.playbackState, MediaPlayer.PlayingState);
        compare(app.mediaPlayer.position, 0);
    }
    function test_changedDurationFallsBackToBeginning() {
        rememberB();
        app.loadMediaFile("file:///B.mp4");
        app.mediaPlayer.duration = 30000;
        ready();
        app.playbackMemory.resume();
        compare(app.mediaPlayer.position, 0);
        compare(app.mediaPlayer.playbackState, MediaPlayer.PlayingState);
    }
    function test_missingRecentFileDoesNotReplacePlaylist() {
        app.playbackHistory.available = false;
        app.playbackMemory.openRecent("file:///missing.mp4");
        compare(app.currentTrackIndex, 0);
        compare(app.mediaPlayer.source.toString(), "file:///A.mp4");
        compare(app.playbackHistory.refreshCount, 1);
        compare(app.messageText, "This recent file is no longer available.");
    }
    function test_recentFileReopensWithResumeOffer() {
        rememberB();
        app.playbackMemory.openRecent("file:///B.mp4");
        compare(app.mediaPlayer.source.toString(), "file:///B.mp4");
        compare(app.playbackMemory.pendingResume.position, 35000);
        compare(app.playbackHistory.recentFiles[0].url, "file:///B.mp4");
    }
}
