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
    function test_playbackLabelsFollowMediaAndPlaybackStates() {
        compare(app.playbackSession.playbackStateLabel, "NOW PLAYING");
        verify(app.playbackSession.hasLoadedTrack);
        app.mediaPlayer.pause();
        compare(app.playbackSession.playbackStateLabel, "PAUSED");
        app.loadTrack(0);
        compare(app.playbackSession.playbackStateLabel, "LOADING");
        verify(!app.playbackSession.hasLoadedTrack);
        app.playCurrentTrack();
        compare(app.playbackSession.playbackStateLabel, "NOW PLAYING");
        app.mediaPlayer.mediaStatus = MediaPlayer.StalledMedia;
        compare(app.playbackSession.playbackStateLabel, "BUFFERING");
        verify(app.playbackSession.hasLoadedTrack);
        app.mediaPlayer.mediaStatus = MediaPlayer.BufferingMedia;
        compare(app.playbackSession.playbackStateLabel, "BUFFERING");
        app.mediaPlayer.pause();
        compare(app.playbackSession.playbackStateLabel, "PAUSED");
        app.mediaPlayer.mediaStatus = MediaPlayer.BufferedMedia;
        app.playbackSession.stopPlayback();
        compare(app.playbackSession.playbackStateLabel, "READY");
        app.mediaPlayer.mediaStatus = MediaPlayer.InvalidMedia;
        compare(app.playbackSession.playbackStateLabel, "UNAVAILABLE");
        verify(!app.playbackSession.hasLoadedTrack);
        app.mediaPlayer.source = "";
        app.mediaPlayer.mediaStatus = MediaPlayer.NoMedia;
        compare(app.playbackSession.playbackStateLabel, "OPEN MEDIA");
        app.playlist = [];
        app.currentTrackIndex = -1;
        app.loopPlaylist = true;
        compare(app.playbackSession.nextTrackIndex, -1);
        compare(app.playbackSession.previousTrackIndex, -1);
    }
    function test_queuePredictionMatchesManualAndAutomaticAdvance_data() {
        return [
            {tag: "first", index: 0, count: 3, loop: false, next: 1, previous: -1},
            {tag: "middle", index: 1, count: 3, loop: false, next: 2, previous: 0},
            {tag: "last-no-loop", index: 2, count: 3, loop: false, next: -1, previous: 1},
            {tag: "last-loop", index: 2, count: 3, loop: true, next: 0, previous: 1},
            {tag: "single-no-loop", index: 0, count: 1, loop: false, next: -1, previous: -1},
            {tag: "single-loop", index: 0, count: 1, loop: true, next: 0, previous: 0}
        ];
    }
    function test_queuePredictionMatchesManualAndAutomaticAdvance(data) {
        app.playlist = app.playlist.slice(0, data.count);
        app.loopPlaylist = data.loop;
        app.playbackSession.loadTrack(data.index, false);
        app.playCurrentTrack();
        compare(app.playbackSession.nextTrackIndex, data.next);
        compare(app.playbackSession.previousTrackIndex, data.previous);
        app.mediaPlayer.position = 12000;
        app.playbackSession.playNext();
        compare(app.currentTrackIndex, data.next >= 0 ? data.next : data.index);
        if (data.next === data.index)
            compare(app.mediaPlayer.position, 0, "A single looping track restarts when Next is pressed");
        if (data.next < 0)
            compare(app.mediaPlayer.position, 12000, "Next must not wrap when looping is off");
        app.playbackSession.loadTrack(data.index, false);
        app.playCurrentTrack();
        app.mediaPlayer.finish();
        compare(app.currentTrackIndex, data.next);
        if (data.next < 0) {
            compare(app.mediaPlayer.playbackState, MediaPlayer.StoppedState);
            compare(app.playbackSession.playbackStateLabel, "PLAYBACK FINISHED");
            verify(!app.playbackSession.hasLoadedTrack);
        } else {
            compare(app.mediaPlayer.playbackState, MediaPlayer.PlayingState);
            compare(app.playbackSession.playbackStateLabel, "NOW PLAYING");
        }
    }
    function test_loopToggleUpdatesPredictionWithoutReloadingMedia() {
        app.loadTrack(2);
        app.playCurrentTrack();
        var revision = app.mediaRevision;
        compare(app.playbackSession.nextTrackIndex, -1);
        app.loopPlaylist = true;
        compare(app.playbackSession.nextTrackIndex, 0);
        app.loopPlaylist = false;
        compare(app.playbackSession.nextTrackIndex, -1);
        compare(app.mediaRevision, revision);
        assertTrack(2, "C");
    }
    function test_queueReorderingChangesTheActualNextTrack() {
        app.playlist = [app.track("file:///C.mp4", "C"), app.track("file:///B.mp4", "B"), app.track("file:///A.mp4", "A")];
        compare(app.playbackSession.nextTrackIndex, 2);
        app.playbackSession.playNext();
        assertTrack(2, "A");
    }

}
