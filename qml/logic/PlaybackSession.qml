import QtQml
import QtMultimedia
import "MediaUtils.js" as MediaUtils

QtObject {
    required property var app
    property int pendingPauseRevision: -1

    property Connections chapterConnections: Connections {
        target: app.playerController
        function onMediaChaptersReady(requestId, chapters) {
            if (requestId === app.mediaRevision)
                app.mediaChapters = chapters;
        }
    }

    function playCurrentTrack() {
        pendingPauseRevision = -1;
        app.playbackMemory.play();
    }

    function togglePlayPause() {
        if (app.currentTrackIndex === -1 && app.playlist.length > 0) {
            loadTrack(0);
            playCurrentTrack();
        } else if (app.mediaPlayer.playbackState === MediaPlayer.PlayingState) {
            app.mediaPlayer.pause();
        } else {
            playCurrentTrack();
        }
    }

    function seekRelative(offsetSeconds) {
        if (app.mediaPlayer.duration > 0) {
            var newPos = app.mediaPlayer.position + (offsetSeconds * 1000);
            app.seekTo(Math.max(0, Math.min(app.mediaPlayer.duration, newPos)));
            app.showMessage((offsetSeconds > 0 ? "Forward " : "Backward ") + Math.abs(offsetSeconds) + "s");
        }
    }

    function playNext() {
        if (app.playlist.length > 0) {
            var nextIndex = (app.currentTrackIndex + 1) % app.playlist.length;
            loadTrack(nextIndex);
            playCurrentTrack();
            app.showMessage("Next: " + app.playlist[nextIndex].title);
        }
    }

    function playPrev() {
        if (app.playlist.length > 0) {
            var prevIndex = (app.currentTrackIndex - 1 + app.playlist.length) % app.playlist.length;
            loadTrack(prevIndex);
            playCurrentTrack();
            app.showMessage("Previous: " + app.playlist[prevIndex].title);
        }
    }

    function loadTrack(index, offerResume) {
        if (index >= 0 && index < app.playlist.length) {
            var track = app.playlist[index];
            pendingPauseRevision = -1;
            app.playbackMemory.beginTrack(track.url, track.title, offerResume !== false);
            app.resetAudioDelay();
            // A reload of the same URL must also invalidate earlier subtitle jobs.
            ++app.mediaRevision;
            app.subtitleGenerationRequest = null;
            app.subtitleGenerator.cancel();
            app.invalidateSubtitleFiles();
            app.playerController.cancelMediaJobs();
            app.mediaPlayer.source = track.url;
            // title now derived reactively from currentTrackIndex

            // Reset subtitle state for new file
            app.subtitleChunks = [];
            app.activeSubtitleText = "";
            app.currentLyrics = "";
            app.currentTimelinePreviewSheet = "";
            app.availableSubtitles = [];
            app.subtitlePickerVisible = false;
            app.subtitleDetectionDone = false;  // allow detectSubtitles to run for this file
            app.activeSubtitleUrl = "";
            app.activeEmbeddedTrackIndex = -1;
            app.mediaPlayer.activeSubtitleTrack = -1;
            app.mediaChapters = [];
            app.chaptersPopupVisible = false;

            app.currentTrackIndex = index;
            app.playbackMemory.trackLoaded();
            app.playerController.scanMediaChapters(track.url, app.mediaRevision);

            app.currentView = MediaUtils.isVideo(track.url) ? "video" : "audio";

            var savedThumb = app.playerController.getThumbnail(track.url);
            if (savedThumb !== "") {
                app.currentThumbnailDataUrl = "data:image/png;base64," + savedThumb;
            } else {
                app.currentThumbnailDataUrl = "";
                app.resetTheme();
            }
            // Subtitle detection now happens in player.onTracksChanged → detectSubtitles()
        }
    }

    function loadMediaFile(fileUrl) {
        var urlStr = fileUrl.toString();
        var fileName = app.playerController.getCleanFileName(urlStr);

        if (app.playFolderToggle) {
            var folderTracks = app.playerController.getFilesInFolder(urlStr);
            if (folderTracks.length > 0) {
                var selectedIndex = -1;
                for (var i = 0; i < folderTracks.length; i++) {
                    if (folderTracks[i].url === urlStr) {
                        selectedIndex = i;
                        break;
                    }
                }
                // Preserve explicitly opened files omitted by the scan (e.g. symlinks).
                if (selectedIndex < 0) {
                    selectedIndex = folderTracks.length;
                    folderTracks.push({
                        url: urlStr,
                        title: fileName
                    });
                }
                app.playlist = folderTracks;
                app.currentTrackIndex = selectedIndex;
                loadTrack(selectedIndex);
                app.showMessage("Loaded folder playlist (" + folderTracks.length + " tracks)");
            } else {
                app.playlist = [
                    {
                        url: urlStr,
                        title: fileName
                    }
                ];
                app.currentTrackIndex = 0;
                loadTrack(0);
            }
        } else {
            app.playlist = [
                {
                    url: urlStr,
                    title: fileName
                }
            ];
            app.currentTrackIndex = 0;
            loadTrack(0);
        }
        playCurrentTrack();
        app.sidebarOpen = false;
    }

    function syncPlaylistForFolderToggle() {
        if (app.playlist.length === 0 || app.currentTrackIndex < 0)
            return;

        var currentTrack = app.playlist[app.currentTrackIndex];
        if (!currentTrack)
            return;

        var currentUrl = currentTrack.url.toString();
        var currentTitle = currentTrack.title;

        if (app.playFolderToggle) {
            var folderTracks = app.playerController.getFilesInFolder(currentUrl);
            if (folderTracks.length > 0) {
                var newIndex = -1;
                for (var i = 0; i < folderTracks.length; i++) {
                    if (folderTracks[i].url === currentUrl) {
                        newIndex = i;
                        break;
                    }
                }
                if (newIndex < 0) {
                    newIndex = folderTracks.length;
                    folderTracks.push(currentTrack);
                }
                app.playlist = folderTracks;
                app.currentTrackIndex = newIndex;
                app.showMessage("Folder playlist loaded (" + folderTracks.length + " tracks)");
            }
        } else {
            app.playlist = [
                {
                    url: currentUrl,
                    title: currentTitle
                }
            ];
            app.currentTrackIndex = 0;
            app.showMessage("Folder playlist cleared");
        }
    }

    function stopPlayback() {
        pendingPauseRevision = -1;
        app.playbackMemory.checkpoint();
        app.playbackMemory.pendingResume = null;
        app.playbackMemory.pendingSeek = -1;
        app.playbackMemory.playAfterSeek = false;
        app.playbackMemory.transitioning = true;
        app.mediaPlayer.stop();
        app.playbackMemory.transitioning = false;
    }

    function navigateFromDesktop(offset) {
        if (app.currentTrackIndex < 0 || app.playlist.length === 0)
            return;
        var index = app.currentTrackIndex + offset;
        if (index < 0 || index >= app.playlist.length) {
            if (!app.playerController.loadLoop())
                return;
            index = (index + app.playlist.length) % app.playlist.length;
        }
        var state = app.mediaPlayer.playbackState;
        loadTrack(index, false);
        if (state === MediaPlayer.PlayingState)
            playCurrentTrack();
        else if (state === MediaPlayer.PausedState) {
            pendingPauseRevision = app.mediaRevision;
            applyPendingPause(app.mediaPlayer.mediaStatus);
        }
    }

    function applyPendingPause(status) {
        if (pendingPauseRevision === app.mediaRevision && (status === MediaPlayer.LoadedMedia || status === MediaPlayer.BufferedMedia || status === MediaPlayer.BufferingMedia)) {
            pendingPauseRevision = -1;
            app.mediaPlayer.pause();
        }
    }

    function handleMediaStatusChanged(status) {
        app.playbackMemory.handleStatusChanged(status);
        applyPendingPause(status);
        // Source changes also stop playback; only advance when a track ends.
        if (status === MediaPlayer.EndOfMedia && app.currentTrackIndex >= 0 && app.playlist.length > 0) {
            if (app.playerController.loadLoop()) {
                loadTrack((app.currentTrackIndex + 1) % app.playlist.length, false);
                playCurrentTrack();
            } else if (app.currentTrackIndex < app.playlist.length - 1) {
                loadTrack(app.currentTrackIndex + 1, false);
                playCurrentTrack();
            } else {
                app.currentTrackIndex = -1;
                app.resetTheme();
            }
        }
    }
}
