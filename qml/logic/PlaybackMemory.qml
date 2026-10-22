import QtQml
import QtMultimedia

QtObject {
    id: root
    required property var app
    property string activeUrl: ""
    property var pendingResume: null
    property bool transitioning: false
    property bool completed: false
    property real lastPosition: 0
    property real lastDuration: 0
    property real pendingSeek: -1
    property bool playAfterSeek: false

    function isCurrentSource() {
        return activeUrl !== "" && app.mediaPlayer.source.toString() === activeUrl;
    }

    function sample() {
        if (transitioning || pendingResume !== null || pendingSeek >= 0 || completed || !isCurrentSource())
            return;
        if (app.mediaPlayer.playbackState !== MediaPlayer.StoppedState && app.mediaPlayer.duration > 0) {
            lastPosition = app.mediaPlayer.position;
            lastDuration = app.mediaPlayer.duration;
        }
    }

    function checkpoint() {
        sample();
        if (!transitioning && pendingResume === null && pendingSeek < 0 && !completed && activeUrl !== "" && lastDuration > 0)
            app.playbackHistory.savePosition(activeUrl, lastPosition, lastDuration);
    }

    function beginTrack(url, title, offerResume) {
        // activeUrl is independent of the playlist, which may already be replaced.
        checkpoint();
        transitioning = true;
        activeUrl = url.toString();
        lastPosition = 0;
        lastDuration = 0;
        completed = false;
        pendingSeek = -1;
        playAfterSeek = false;
        var position = offerResume ? app.playbackHistory.resumePosition(activeUrl) : 0;
        pendingResume = position > 0 ? {
            url: activeUrl,
            title: title,
            position: position
        } : null;
    }

    function trackLoaded() {
        transitioning = false;
        app.playbackHistory.recordFile(activeUrl);
        // Source changes already stop playback. Pausing while loading can queue
        // a pause that takes effect after the user's Resume choice.
        if (pendingResume !== null && app.mediaPlayer.playbackState === MediaPlayer.PlayingState)
            app.mediaPlayer.pause();
    }

    function play() {
        if (pendingResume !== null)
            return;
        if (pendingSeek >= 0) {
            playAfterSeek = true;
            trySeek();
        } else {
            completed = false;
            app.mediaPlayer.play();
        }
    }

    function resume() {
        if (pendingResume === null || pendingResume.url !== activeUrl)
            return;
        pendingSeek = pendingResume.position;
        pendingResume = null;
        playAfterSeek = true;
        trySeek();
    }

    function startOver() {
        if (pendingResume === null)
            return;
        app.playbackHistory.clearPosition(activeUrl);
        pendingSeek = 0;
        pendingResume = null;
        playAfterSeek = true;
        trySeek();
    }

    function trySeek() {
        if (transitioning || pendingSeek < 0 || !isCurrentSource() || app.mediaPlayer.duration <= 0 || !app.mediaPlayer.seekable)
            return;
        var status = app.mediaPlayer.mediaStatus;
        if (status !== MediaPlayer.LoadedMedia && status !== MediaPlayer.BufferedMedia && status !== MediaPlayer.BufferingMedia)
            return;
        var target = pendingSeek > 0 ? app.playbackHistory.resumePosition(activeUrl, app.mediaPlayer.duration) : 0;
        // Keep checkpointing suspended until the seek has been submitted.
        app.seekTo(target);
        lastPosition = target;
        lastDuration = app.mediaPlayer.duration;
        pendingSeek = -1;
        if (playAfterSeek) {
            playAfterSeek = false;
            app.mediaPlayer.play();
        }
    }

    function handleStatusChanged(status) {
        if (transitioning || !isCurrentSource())
            return;
        if (status === MediaPlayer.EndOfMedia) {
            completed = true;
            pendingResume = null;
            pendingSeek = -1;
            app.playbackHistory.clearPosition(activeUrl);
        } else if (status === MediaPlayer.InvalidMedia) {
            pendingResume = null;
            pendingSeek = -1;
            completed = true;
        } else {
            trySeek();
        }
    }

    function openRecent(url) {
        if (!app.playbackHistory.isAvailable(url)) {
            app.playbackHistory.refreshRecentFiles();
            app.showMessage("This recent file is no longer available.");
            return;
        }
        app.loadMediaFile(url);
    }

    property Timer saveTimer: Timer {
        interval: 5000
        repeat: true
        running: root.isCurrentSource() && app.mediaPlayer.playbackState === MediaPlayer.PlayingState && root.pendingResume === null
        onTriggered: root.checkpoint()
    }

    property Connections playerConnections: Connections {
        target: app.mediaPlayer
        function onPositionChanged() {
            root.sample();
        }
        function onDurationChanged() {
            root.trySeek();
        }
        function onSeekableChanged() {
            root.trySeek();
        }
        function onPlaybackStateChanged() {
            if (root.transitioning)
                return;
            if (root.pendingResume !== null && app.mediaPlayer.playbackState === MediaPlayer.PlayingState) {
                app.mediaPlayer.pause();
            } else if (app.mediaPlayer.playbackState !== MediaPlayer.PlayingState) {
                root.checkpoint();
            }
        }
    }
}
