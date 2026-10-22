import QtQuick
import QtTest
import QtMultimedia

TestCase {
    id: testCase
    name: "PlaybackSession"
    property var app
    Component {
        id: appComponent
        MockApp {}
    }
    function init() {
        app = createTemporaryObject(appComponent, testCase);
        verify(app !== null);
        app.loadExamplePlaylist(1);
    }
    function assertTrack(index, title) {
        compare(app.currentTrackIndex, index);
        compare(app.playlist[index].title, title);
        compare(app.mediaPlayer.source.toString(), app.playlist[index].url);
    }
    function test_desktopNavigationPreservesPauseOnceLoaded() {
        app.mediaPlayer.pause();
        app.playbackSession.navigateFromDesktop(1);
        assertTrack(2, "C");
        compare(app.playbackMemory.pendingResume, null);
        app.mediaPlayer.mediaStatus = MediaPlayer.LoadedMedia;
        compare(app.mediaPlayer.playbackState, MediaPlayer.PausedState);
    }
    function test_desktopPlayDuringLoadingCancelsDeferredPause() {
        app.mediaPlayer.pause();
        app.playbackSession.navigateFromDesktop(1);
        app.playCurrentTrack();
        compare(app.mediaPlayer.playbackState, MediaPlayer.PlayingState);
    }
    function test_desktopNavigationHonoursPlaylistBoundariesAndStop() {
        app.loadTrack(2);
        app.playbackSession.navigateFromDesktop(1);
        assertTrack(2, "C");
        app.playbackSession.stopPlayback();
        compare(app.mediaPlayer.playbackState, MediaPlayer.StoppedState);
        app.playbackSession.navigateFromDesktop(-1);
        assertTrack(1, "B");
        compare(app.mediaPlayer.playbackState, MediaPlayer.StoppedState);
    }
    function test_previousDoesNotAdvanceOnSourceChange() {
        app.playbackSession.playPrev();
        assertTrack(0, "A");
        compare(app.mediaPlayer.playbackState, MediaPlayer.PlayingState);
    }
    function test_next() {
        app.playbackSession.playNext();
        assertTrack(2, "C");
    }
    function test_explicitSelectionWhilePlaying() {
        app.loadTrack(0);
        assertTrack(0, "A");
    }
    function test_stopDoesNotAdvance() {
        app.mediaPlayer.stop();
        assertTrack(1, "B");
        compare(app.mediaPlayer.playbackState, MediaPlayer.StoppedState);
    }
    function test_endOfMediaAdvancesOnce() {
        app.mediaPlayer.finish();
        assertTrack(2, "C");
        compare(app.mediaPlayer.playbackState, MediaPlayer.PlayingState);
    }
    function test_lastTrackWithoutLoopStops() {
        app.loadTrack(2);
        app.mediaPlayer.finish();
        compare(app.currentTrackIndex, -1);
        compare(app.mediaPlayer.source.toString(), "file:///C.mp4");
        compare(app.mediaPlayer.playbackState, MediaPlayer.StoppedState);
    }
    function test_playlistLoops() {
        app.playerController.looping = true;
        app.loadTrack(2);
        app.mediaPlayer.finish();
        assertTrack(0, "A");
    }
    function test_singleTrackLoops() {
        app.playerController.looping = true;
        app.playlist = [app.track("file:///A.mp4", "A")];
        app.loadTrack(0);
        app.mediaPlayer.finish();
        assertTrack(0, "A");
        compare(app.mediaPlayer.position, 0);
    }
    function test_relativeSeekClampsToDuration() {
        app.mediaPlayer.position = 2000;
        app.playbackSession.seekRelative(-5);
        compare(app.mediaPlayer.position, 0);
        app.mediaPlayer.position = 98000;
        app.playbackSession.seekRelative(5);
        compare(app.mediaPlayer.position, 100000);
    }
    function test_emptyPlaylistIsHarmless() {
        app.playlist = [];
        app.currentTrackIndex = -1;
        app.playbackSession.playNext();
        app.playbackSession.playPrev();
        app.playbackSession.handleMediaStatusChanged(MediaPlayer.EndOfMedia);
        compare(app.currentTrackIndex, -1);
    }
    function test_missingRequestedFileIsPreserved() {
        app.playFolderToggle = true;
        app.playerController.folderTracks = [app.track("file:///neighbor.mp4", "Neighbor")];
        app.playbackSession.loadMediaFile("file:///selected.opus");
        assertTrack(1, "selected.opus");
        compare(app.playlist.length, 2);
    }
    function test_enablingFolderModePreservesCurrentFile() {
        app.playerController.folderTracks = [app.track("file:///neighbor.mp4", "Neighbor")];
        app.playFolderToggle = true;
        app.playbackSession.syncPlaylistForFolderToggle();
        assertTrack(1, "B");
        compare(app.playlist.length, 2);
        app.playFolderToggle = false;
        app.playbackSession.syncPlaylistForFolderToggle();
        assertTrack(0, "B");
        compare(app.playlist.length, 1);
    }
    function test_emptyFolderUsesRequestedFile() {
        app.playFolderToggle = true;
        app.playbackSession.loadMediaFile("file:///selected.opus");
        assertTrack(0, "selected.opus");
        compare(app.playlist.length, 1);
    }
    function test_switchInvalidatesSubtitleRequest() {
        app.subtitleGenerationRequest = {
            mediaRevision: app.mediaRevision
        };
        var revision = app.mediaRevision;
        app.loadTrack(0);
        compare(app.subtitleGenerationRequest, null);
        compare(app.mediaRevision, revision + 1);
    }
}
