import QtQuick
import QtTest
import QtMultimedia
import QtQuick.Controls
import QtQuick.Window
import QtQuick.Dialogs as NativeDialogs

TestCase {
    id: testCase
    name: "ApplicationComponents"
    when: windowShown
    property var appWindow
    Component {
        id: playbackStateSpy
        SignalSpy { signalName: "playbackStateChanged" }
    }
    function init() {
        failOnWarning(/(ReferenceError|TypeError|is not defined|Cannot assign|Binding loop)/);
        var component = Qt.createComponent(TestPaths.mainQml);
        compare(component.status, Component.Ready, component.errorString());
        appWindow = createTemporaryObject(component, testCase, {
            layoutPersistenceEnabled: false,
            desktopControlsEnabled: false
        });
        verify(appWindow !== null);
        appWindow.playbackOptions.rate = 1;
        appWindow.subtitleFontSize = 18;
        appWindow.subtitleTextColor = "#ffffff";
        appWindow.subtitleBgOpacity = 0.55;
        appWindow.subtitleBottomMarginPercent = 12;
        appWindow.playbackHistory.clearRecentFiles();
        appWindow.playbackHistory.clearPosition(TestPaths.audioUrl);
        wait(20);
    }
    function cleanup() {
        if (appWindow)
            appWindow.close();
    }
    function test_selectFolderPlaylistEntry_data() {
        return [
            {tag: "video-side-panel", view: "video", expanded: false, filtered: false},
            {tag: "audio-side-panel", view: "audio", expanded: false, filtered: false},
            {tag: "expanded-panel", view: "video", expanded: true, filtered: false},
            {tag: "filtered-side-panel", view: "video", expanded: false, filtered: true},
            {tag: "filtered-expanded-panel", view: "audio", expanded: true, filtered: true}
        ];
    }
    function test_selectFolderPlaylistEntry(data) {
        appWindow.playFolderToggle = true;
        appWindow.loadMediaFile(TestPaths.folderMediaUrl);
        compare(appWindow.playlist.length, 3);
        compare(appWindow.currentTrackIndex, 0);
        tryCompare(appWindow.mediaPlayer, "playbackState", MediaPlayer.PlayingState);
        appWindow.mediaPlayer.pause();
        appWindow.showMediaView(data.view);
        appWindow.togglePanel("playlist");
        appWindow.setPanelExpanded(data.expanded);
        var list = findChild(appWindow, "playlistListView");
        var target = appWindow.playlist[2].url.toString();
        if (data.filtered)
            findChild(appWindow, "playlistFilter").text = "Last";
        tryCompare(list, "count", data.filtered ? 1 : 3);
        waitForRendering(list);
        var row = list.itemAtIndex(data.filtered ? 0 : 2);
        verify(row !== null);
        compare(row.text, "3.  03 Last.wav", "Filtering must preserve the original queue number");
        mouseClick(row);
        compare(appWindow.currentTrackIndex, 2, "A playlist click must select that queue entry");
        compare(appWindow.mediaPlayer.source.toString(), target);
        tryCompare(appWindow.mediaPlayer, "playbackState", MediaPlayer.PlayingState);
        compare(appWindow.playlist.length, 3, "Selecting a row must keep the folder queue");
        compare(appWindow.panelView, "playlist");
    }
    function test_pendingPlaylistCannotReplaceNewSelection_data() {
        return [
            {tag: "drop-then-media", dialog: false, replacement: "media"},
            {tag: "menu-then-media", dialog: true, replacement: "media"},
            {tag: "drop-then-track", dialog: false, replacement: "track"},
            {tag: "menu-then-playlist", dialog: true, replacement: "playlist"},
            {tag: "drop-then-close", dialog: false, replacement: "close"}
        ];
    }
    function test_pendingPlaylistCannotReplaceNewSelection(data) {
        appWindow.playFolderToggle = false;
        appWindow.loadMediaFile(TestPaths.audioUrl);
        tryCompare(appWindow.mediaPlayer, "playbackState", MediaPlayer.PlayingState);
        appWindow.mediaPlayer.pause();
        var base = TestPaths.audioUrl.substring(0, TestPaths.audioUrl.lastIndexOf("/") + 1);
        var oldUrl = base + "Earlier.xspf";
        var xml = '<playlist><trackList><track><location>'
            + TestPaths.escapedMediaUrl.replace(/&/g, "&amp;")
            + '</location><title>Earlier playlist</title></track></trackList></playlist>';
        verify(appWindow.playerController.writeTextToFile(oldUrl, xml));
        if (data.dialog) {
            var dialog = findChild(appWindow, "playlistFileDialog");
            dialog.selectedFile = oldUrl;
            dialog.accepted();
        } else appWindow.handleDroppedFile(oldUrl);
        verify(appWindow.playlistRequest !== null);
        if (data.replacement === "playlist") {
            var newUrl = base + "Latest.xspf";
            verify(appWindow.playerController.writeTextToFile(newUrl, xml.replace("Earlier playlist", "Latest playlist")));
            appWindow.handleDroppedFile(newUrl);
            tryCompare(appWindow, "playlistRequest", null);
            compare(appWindow.playlist[0].title, "Latest playlist");
        } else {
            if (data.replacement === "media") appWindow.loadMediaFile(TestPaths.audioUrl);
            else if (data.replacement === "track") appWindow.loadTrack(0);
            else appWindow.close();
            compare(appWindow.playlistRequest, null);
        }
        var revision = appWindow.mediaRevision;
        var source = appWindow.mediaPlayer.source.toString();
        var title = appWindow.playlist[0].title;
        var message = appWindow.messageText;
        wait(100);
        compare(appWindow.mediaRevision, revision);
        compare(appWindow.mediaPlayer.source.toString(), source);
        compare(appWindow.playlist[0].title, title);
        compare(appWindow.messageText, message, "Cancelled reads must not show stale success or error messages");
        verify(title !== "Earlier playlist");
    }
    function test_xspfEscapedPathAndTitlePlay() {
        appWindow.playbackHistory.clearPosition(TestPaths.escapedMediaUrl);
        var location = TestPaths.escapedMediaUrl.replace(/&/g, "&amp;");
        appWindow.parseXspf('<playlist version="1" xmlns="http://xspf.org/ns/0/"><trackList><track>'
            + '<location>' + location + '</location><title>Rock &amp; Roll &#x1F3B5;</title>'
            + '</track></trackList></playlist>');
        compare(appWindow.playlist.length, 1);
        compare(appWindow.playlist[0].url.toString(), TestPaths.escapedMediaUrl);
        compare(appWindow.playlist[0].title, "Rock & Roll 🎵");
        appWindow.playCurrentTrack();
        tryCompare(appWindow.mediaPlayer, "playbackState", MediaPlayer.PlayingState);
        tryVerify(function () { return appWindow.mediaPlayer.duration > 0; });
        compare(appWindow.mediaPlayer.source.toString(), TestPaths.escapedMediaUrl);
    }
    function test_xspfInvalidXmlKeepsCurrentQueue_data() {
        return [{tag: "direct", drop: false}, {tag: "drop", drop: true}];
    }
    function test_xspfInvalidXmlKeepsCurrentQueue(data) {
        appWindow.loadMediaFile(TestPaths.audioUrl);
        tryCompare(appWindow.mediaPlayer, "playbackState", MediaPlayer.PlayingState);
        var revision = appWindow.mediaRevision;
        var xml = '<playlist><trackList><track><location>' + TestPaths.audioUrl
            + '</location></track></trackList>'; // Missing closing playlist tag.
        if (data.drop) {
            var url = TestPaths.audioUrl.substring(0, TestPaths.audioUrl.lastIndexOf("/") + 1) + "Malformed.xspf";
            verify(appWindow.playerController.writeTextToFile(url, xml));
            appWindow.handleDroppedFile(url);
            tryVerify(function () { return appWindow.messageText.indexOf("Error:") >= 0; });
        } else appWindow.parseXspf(xml);
        compare(appWindow.mediaRevision, revision, "Malformed XML must not replace or reload the queue");
        compare(appWindow.mediaPlayer.source.toString(), TestPaths.audioUrl);
        compare(appWindow.mediaPlayer.playbackState, MediaPlayer.PlayingState);
        verify(appWindow.messageText.indexOf("Error:") >= 0);
    }
    function test_xspfFileLoading_data() {
        return [
            {tag: "drop-absolute", drop: true, relative: false},
            {tag: "drop-relative", drop: true, relative: true},
            {tag: "dialog-absolute", drop: false, relative: false},
            {tag: "dialog-relative", drop: false, relative: true}
        ];
    }
    function test_xspfFileLoading(data) {
        appWindow.playbackHistory.clearPosition(TestPaths.escapedMediaUrl);
        var folder = TestPaths.escapedMediaUrl.substring(0, TestPaths.escapedMediaUrl.lastIndexOf("/") + 1);
        var url = folder + "Import & Mix.xspf";
        var location = data.relative ? TestPaths.escapedMediaUrl.substring(folder.length) : TestPaths.escapedMediaUrl;
        var xml = '<playlist version="1" xmlns="http://xspf.org/ns/0/"><trackList><track><location>'
            + location.replace(/&/g, "&amp;") + '</location><title>Imported &amp; decoded</title></track></trackList></playlist>';
        verify(appWindow.playerController.writeTextToFile(url, xml));
        if (data.drop) appWindow.handleDroppedFile(url);
        else {
            var dialog = findChild(appWindow, "playlistFileDialog");
            dialog.selectedFile = url;
            dialog.accepted();
        }
        tryCompare(appWindow, "currentTrackIndex", 0);
        compare(appWindow.playlist[0].url.toString(), TestPaths.escapedMediaUrl);
        compare(appWindow.playlist[0].title, "Imported & decoded");
        appWindow.playCurrentTrack();
        tryCompare(appWindow.mediaPlayer, "playbackState", MediaPlayer.PlayingState);
        compare(appWindow.mediaPlayer.source.toString(), TestPaths.escapedMediaUrl);
    }
    function test_duplicatePlaylistUrlsSelectTheClickedOccurrence() {
        appWindow.playlist = [
            {url: TestPaths.audioUrl, title: "First occurrence"},
            {url: TestPaths.audioUrl, title: "Repeat occurrence"}
        ];
        appWindow.loadTrack(0);
        appWindow.playCurrentTrack();
        tryCompare(appWindow.mediaPlayer, "playbackState", MediaPlayer.PlayingState);
        appWindow.togglePanel("playlist");
        var list = findChild(appWindow, "playlistListView");
        waitForRendering(list);
        verify(list.itemAtIndex(0).isCurrent);
        verify(!list.itemAtIndex(1).isCurrent, "Only the current occurrence should be highlighted");
        findChild(appWindow, "playlistFilter").text = "Repeat";
        tryCompare(list, "count", 1);
        waitForRendering(list);
        mouseClick(list.itemAtIndex(0));
        compare(appWindow.currentTrackIndex, 1);
        verify(list.itemAtIndex(0).isCurrent);
        compare(appWindow.mediaPlayer.source.toString(), TestPaths.audioUrl);
        compare(appWindow.playlist.length, 2);
    }
    function test_layoutRestoredBetweenSessions_data() {
        return [
            {tag: "closed-audio", media: "audio", panel: "", expanded: false},
            {tag: "playlist-video", media: "video", panel: "playlist", expanded: false},
            {tag: "lyrics-audio", media: "audio", panel: "lyrics", expanded: false},
            {tag: "expanded-playlist", media: "video", panel: "playlist", expanded: true},
            {tag: "expanded-lyrics-startup-file", media: "video", panel: "lyrics", expanded: true, file: true}
        ];
    }
    function test_layoutRestoredBetweenSessions(data) {
        appWindow.layoutPersistenceEnabled = true;
        appWindow.desktopLayout.restore();
        appWindow.showNormal();
        appWindow.width = 720;
        appWindow.height = 480;
        appWindow.showMediaView(data.media);
        appWindow.panelView = data.panel;
        appWindow.setPanelExpanded(data.expanded);
        appWindow.close();
        var component = Qt.createComponent(TestPaths.mainQml);
        appWindow = createTemporaryObject(component, testCase, {
            desktopControlsEnabled: false,
            initialFileUrl: data.file ? TestPaths.audioUrl : ""
        });
        verify(appWindow !== null);
        compare(appWindow.width, 720);
        compare(appWindow.height, 480);
        compare(appWindow.mediaView, data.file ? "audio" : data.media);
        compare(appWindow.panelView, data.panel);
        compare(appWindow.panelExpanded, data.expanded);
        compare(findChild(appWindow, "sidePanel").visible, data.panel !== "");
        compare(findChild(appWindow, "playerSurface").visible, !data.expanded);
        appWindow.layoutPersistenceEnabled = false;
    }
    function test_layoutKeepsNormalGeometry_data() {
        return [
            {tag: "maximized", maximize: true, fullscreen: false},
            {tag: "fullscreen-from-window", maximize: false, fullscreen: true},
            {tag: "fullscreen-from-maximized", maximize: true, fullscreen: true}
        ];
    }
    function test_layoutKeepsNormalGeometry(data) {
        appWindow.layoutPersistenceEnabled = true;
        appWindow.desktopLayout.restore();
        appWindow.showNormal();
        appWindow.width = 720;
        appWindow.height = 480;
        wait(150);
        if (data.maximize) {
            appWindow.showMaximized();
            tryCompare(appWindow, "visibility", Window.Maximized);
        }
        if (data.fullscreen) {
            appWindow.showFullScreen();
            tryCompare(appWindow, "visibility", Window.FullScreen);
        }
        appWindow.close();
        var component = Qt.createComponent(TestPaths.mainQml);
        appWindow = createTemporaryObject(component, testCase, {desktopControlsEnabled: false});
        verify(appWindow !== null);
        tryCompare(appWindow, "visibility", data.maximize ? Window.Maximized : Window.Windowed);
        compare(appWindow.desktopLayout.normalWidth, 720);
        compare(appWindow.desktopLayout.normalHeight, 480);
        appWindow.layoutPersistenceEnabled = false;
    }
    function test_fullscreenRestoresPreviousWindowState_data() {
        var cases = [];
        for (var maximized of [false, true]) {
            for (var route of ["toggle", "escape", "keyboard", "double-click", "external"]) {
                cases.push({tag: (maximized ? "maximized-" : "windowed-") + route,
                    maximized: maximized, route: route});
            }
        }
        return cases;
    }
    function test_fullscreenRestoresPreviousWindowState(data) {
        appWindow.showMediaView("video");
        appWindow.showNormal();
        appWindow.width = 720;
        appWindow.height = 480;
        if (data.maximized) appWindow.showMaximized();
        var expected = data.maximized ? Window.Maximized : Window.Windowed;
        tryCompare(appWindow, "visibility", expected);
        appWindow.requestActivate();
        tryCompare(appWindow, "active", true);
        appWindow.contentItem.forceActiveFocus();
        var video = findChild(appWindow, "videoPointerArea");
        for (var cycle = 0; cycle < 2; ++cycle) {
            if (data.route === "keyboard") keyClick(Qt.Key_F);
            else if (data.route === "double-click") {
                waitForRendering(video);
                mouseDoubleClickSequence(video, video.width / 2, video.height / 2);
            } else if (data.route === "external") appWindow.showFullScreen();
            else appWindow.toggleFullscreen();
            tryCompare(appWindow, "visibility", Window.FullScreen);
            if (data.route === "escape" || data.route === "external") keyClick(Qt.Key_Escape);
            else if (data.route === "keyboard") keyClick(Qt.Key_F);
            else if (data.route === "double-click") {
                waitForRendering(video);
                mouseDoubleClickSequence(video, video.width / 2, video.height / 2);
            } else appWindow.toggleFullscreen();
            tryCompare(appWindow, "visibility", expected);
        }
        appWindow.showNormal();
        tryCompare(appWindow, "width", 720);
        tryCompare(appWindow, "height", 480);
    }
    function test_fullscreenRestorationSurvivesReopening_data() {
        return [{tag: "toggle", escape: false}, {tag: "escape", escape: true}];
    }
    function test_fullscreenRestorationSurvivesReopening(data) {
        appWindow.layoutPersistenceEnabled = true;
        appWindow.desktopLayout.restore();
        appWindow.showNormal();
        appWindow.width = 720;
        appWindow.height = 480;
        wait(150);
        appWindow.showMaximized();
        tryCompare(appWindow, "visibility", Window.Maximized);
        appWindow.requestActivate();
        tryCompare(appWindow, "active", true);
        appWindow.toggleFullscreen();
        tryCompare(appWindow, "visibility", Window.FullScreen);
        if (data.escape) keyClick(Qt.Key_Escape);
        else appWindow.toggleFullscreen();
        tryCompare(appWindow, "visibility", Window.Maximized);
        appWindow.close();
        var component = Qt.createComponent(TestPaths.mainQml);
        appWindow = createTemporaryObject(component, testCase, {desktopControlsEnabled: false});
        verify(appWindow !== null);
        tryCompare(appWindow, "visibility", Window.Maximized);
        compare(appWindow.desktopLayout.normalWidth, 720);
        compare(appWindow.desktopLayout.normalHeight, 480);
        appWindow.layoutPersistenceEnabled = false;
    }
    function test_taskPopupAvailableInFullscreen() {
        appWindow.subtitleGenerator.generateSubtitles("", "", "", false);
        appWindow.showMediaView("video");
        appWindow.showFullScreen();
        var indicator = findChild(appWindow, "backgroundTaskIndicator");
        appWindow.controlsVisible = true;
        mouseClick(indicator);
        var popup = findChild(appWindow, "backgroundTasksPopup");
        tryCompare(popup, "opened", true);
        verify(appWindow.modalDialogOpen);
        verify(appWindow.controlsVisible);
        wait(1400);
        verify(appWindow.controlsVisible, "A task popup must prevent fullscreen controls from timing out");
        mouseClick(findChild(appWindow, "cancelSubtitleGeneration"));
        verify(!appWindow.subtitleGenerator.isProcessing);
        popup.close();
    }
    function test_audioVisualizerUsesPlaybackAndPresentationState() {
        appWindow.visualizerEnabled = true;
        appWindow.reduceMotion = false;
        appWindow.loadMediaFile(TestPaths.audioUrl);
        tryCompare(appWindow.mediaPlayer, "playbackState", MediaPlayer.PlayingState);
        var indicator = findChild(appWindow, "audioVisualizer");
        verify(indicator.visible);
        verify(appWindow.audioLevels.enabled);
        tryCompare(appWindow.audioLevels, "available", true);
        compare(appWindow.audioLevels.rms, 0, "The fixture is silent; playback alone must not move the meter");
        compare(appWindow.audioLevels.peak, 0);
        waitForRendering(indicator);
        for (var i = 0; i < 24; ++i) {
            var bar = findChild(indicator, "audioSpectrumBar" + i);
            verify(bar !== null, "Frequency bar " + i + " must exist");
            tryCompare(bar, "height", 0);
        }
        appWindow.mediaPlayer.pause();
        verify(!indicator.visible);
        verify(!appWindow.audioLevels.available);
        appWindow.mediaPlayer.play();
        tryCompare(appWindow.mediaPlayer, "playbackState", MediaPlayer.PlayingState);
        appWindow.reduceMotion = true;
        verify(!appWindow.audioLevels.enabled);
        verify(findChild(appWindow, "audioPlaybackIndicator").visible);
        appWindow.isMuted = true;
        compare(findChild(appWindow, "audioPlaybackIndicator").text, "Muted");
        appWindow.reduceMotion = false;
        appWindow.showMediaView("video");
        verify(!appWindow.audioLevels.enabled);
        appWindow.showMediaView("audio");
        verify(appWindow.audioLevels.enabled);
        appWindow.togglePanel("playlist");
        appWindow.setPanelExpanded(true);
        verify(!appWindow.audioLevels.enabled);
        appWindow.setPanelExpanded(false);
        verify(appWindow.audioLevels.enabled);
        appWindow.height = 420;
        tryCompare(indicator, "visible", false);
        verify(!appWindow.audioLevels.enabled);
        appWindow.height = 720;
        tryCompare(indicator, "visible", true);
        verify(appWindow.audioLevels.enabled);
        appWindow.visualizerEnabled = false;
        verify(!indicator.visible);
        verify(!appWindow.audioLevels.enabled);
        appWindow.visualizerEnabled = true;
        appWindow.reduceMotion = false;
    }
    function test_transcriptionCancelIsAvailableAcrossViews() {
        appWindow.subtitleGenerator.generateSubtitles("", "", "", false);
        var button = findChild(appWindow, "cancelSubtitleGeneration");
        var indicator = findChild(appWindow, "backgroundTaskIndicator");
        var popup = findChild(appWindow, "backgroundTasksPopup");
        verify(button !== null);
        for (var i = 0; i < 4; ++i) {
            appWindow.currentView = ["audio", "video", "lyrics", "playlist"][i];
            wait(20);
            verify(indicator.visible);
            mouseClick(indicator);
            tryCompare(popup, "opened", true);
            verify(button.visible);
            verify(button.enabled);
            if (i < 3) {
                popup.close();
                tryCompare(popup, "opened", false);
            }
        }
        mouseClick(button);
        verify(!appWindow.subtitleGenerator.isProcessing);
        verify(!button.visible);
        popup.close();
        tryCompare(indicator, "visible", false);
    }
    function test_resumeDialogSeeksAndStartOverRestarts() {
        appWindow.playbackHistory.savePosition(TestPaths.audioUrl, 15000, 60000);
        appWindow.loadMediaFile(TestPaths.audioUrl);
        verify(appWindow.resumePending);
        var dialog = findChild(appWindow, "resumeDialog");
        tryCompare(dialog, "opened", true);
        verify(appWindow.mediaPlayer.playbackState !== MediaPlayer.PlayingState);
        var resumeButton = findChild(appWindow, "resumeButton");
        waitForRendering(resumeButton);
        mouseClick(resumeButton);
        verify(!appWindow.resumePending, "Resume button must resolve the prompt");
        tryCompare(appWindow.mediaPlayer, "playbackState", MediaPlayer.PlayingState);
        tryVerify(function () {
            return appWindow.mediaPlayer.position >= 15000 && appWindow.mediaPlayer.position < 18000;
        });
        appWindow.mediaPlayer.pause();
        appWindow.loadMediaFile(TestPaths.audioUrl);
        verify(appWindow.resumePending);
        tryCompare(dialog, "opened", true);
        waitForRendering(findChild(appWindow, "startOverButton"));
        mouseClick(findChild(appWindow, "startOverButton"));
        tryCompare(appWindow.mediaPlayer, "playbackState", MediaPlayer.PlayingState);
        tryVerify(function () {
            return appWindow.mediaPlayer.position < 1500;
        });
        appWindow.mediaPlayer.pause();
        compare(appWindow.playbackHistory.resumePosition(TestPaths.audioUrl), 0);
    }
    function test_recentFilesMenuOpensFileAndCanClearList() {
        appWindow.playbackHistory.recordFile(TestPaths.audioUrl);
        mouseClick(findChild(appWindow, "fileMenuButton"));
        tryCompare(findChild(appWindow, "fileMenu"), "opened", true);
        mouseClick(findChild(appWindow, "recentFilesButton"));
        var menu = findChild(appWindow, "recentFilesMenu");
        tryCompare(menu, "opened", true);
        var list = findChild(appWindow, "recentFilesList");
        compare(list.count, 1);
        tryVerify(function () {
            return list.itemAtIndex(0) !== null;
        });
        waitForRendering(list.itemAtIndex(0));
        mouseClick(list.itemAtIndex(0));
        tryCompare(menu, "opened", false);
        compare(appWindow.mediaPlayer.source.toString(), TestPaths.audioUrl);
        appWindow.mediaPlayer.pause();
        appWindow.openRecentFiles();
        tryCompare(menu, "opened", true);
        waitForRendering(findChild(appWindow, "clearRecentFilesButton"));
        mouseClick(findChild(appWindow, "clearRecentFilesButton"));
        compare(appWindow.playbackHistory.recentFiles.length, 0);
        menu.close();
    }
    function test_closeAndReopenOffersSavedPosition() {
        appWindow.loadMediaFile(TestPaths.audioUrl);
        tryVerify(function () {
            return appWindow.mediaPlayer.seekable && appWindow.mediaPlayer.duration > 0;
        });
        appWindow.mediaPlayer.position = 22000;
        tryVerify(function () {
            return appWindow.mediaPlayer.position >= 22000;
        });
        appWindow.mediaPlayer.pause();
        appWindow.close();
        var component = Qt.createComponent(TestPaths.mainQml);
        compare(component.status, Component.Ready, component.errorString());
        appWindow = createTemporaryObject(component, testCase, {
            layoutPersistenceEnabled: false,
            desktopControlsEnabled: false,
            initialFileUrl: TestPaths.audioUrl
        });
        verify(appWindow !== null);
        verify(appWindow.resumePending);
        verify(appWindow.resumePositionMs >= 22000);
        verify(appWindow.mediaPlayer.playbackState !== MediaPlayer.PlayingState);
    }
    function test_modelManagerListsSupportedModels() {
        mouseClick(findChild(appWindow, "optionsMenuButton"));
        tryCompare(findChild(appWindow, "optionsMenu"), "opened", true);
        var options = findChild(appWindow, "optionsMenu");
        mouseClick(options.itemAt(1));
        tryCompare(findChild(appWindow, "subtitleOptionsMenu"), "opened", true);
        mouseClick(findChild(appWindow, "modelsButton"));
        var manager = findChild(appWindow, "modelManager");
        tryCompare(manager, "opened", true);
        var list = findChild(appWindow, "modelList");
        compare(list.count, 2);
        compare(appWindow.modelDownloader.models[0].name, "tiny");
        compare(appWindow.modelDownloader.models[1].name, "base");
        manager.close();
    }
    function test_audioAndPlaybackPopupUsesRealPlayer() {
        appWindow.loadMediaFile(TestPaths.audioUrl);
        tryVerify(function () {
            return appWindow.mediaPlayer.seekable && appWindow.mediaPlayer.audioTracks.length > 0;
        });
        appWindow.mediaPlayer.pause();
        mouseClick(findChild(appWindow, "playbackOptionsButton"));
        var popup = findChild(appWindow, "playbackOptionsPopup");
        tryCompare(popup, "opened", true);
        var tracks = findChild(appWindow, "audioTrackSelector");
        compare(tracks.count, 2);
        var speed = findChild(appWindow, "playbackSpeedSelector");
        speed.currentIndex = 5;
        speed.activated(5);
        compare(appWindow.mediaPlayer.playbackRate, 1.5);
        var delay = findChild(appWindow, "audioDelayControl");
        verify(delay.enabled);
        delay.value = 250;
        delay.valueModified();
        compare(appWindow.playbackOptions.audioDelayMs, 250);
        compare(appWindow.audioLevels.player, appWindow.playbackOptions.audiblePlayer);
        verify(appWindow.audioLevels.player !== appWindow.mediaPlayer);
        appWindow.resetAudioDelay();
        compare(appWindow.audioLevels.player, appWindow.mediaPlayer);
        popup.close();
    }
    function test_desktopCommandsUseApplicationState() {
        appWindow.loadMediaFile(TestPaths.audioUrl);
        tryVerify(function () {
            return appWindow.mediaPlayer.seekable;
        });
        appWindow.desktopControls.pauseRequested();
        appWindow.desktopControls.rateRequested(1.25);
        compare(appWindow.playbackOptions.rate, 1.25);
        appWindow.desktopControls.volumeRequested(0.4);
        compare(appWindow.volumeSlider.value, 40);
        appWindow.desktopControls.playRequested();
        tryCompare(appWindow.mediaPlayer, "playbackState", MediaPlayer.PlayingState);
        appWindow.desktopControls.stopRequested();
        tryCompare(appWindow.mediaPlayer, "playbackState", MediaPlayer.StoppedState);
    }
    function test_allViewsRender() {
        for (var i = 0; i < 4; ++i) {
            appWindow.currentView = ["audio", "video", "lyrics", "playlist"][i];
            wait(20);
            compare(appWindow.currentView, ["audio", "video", "lyrics", "playlist"][i]);
        }
        verify(appWindow.videoOutput !== null);
        verify(appWindow.seekSlider !== null);
        verify(appWindow.volumeSlider !== null);
        verify(appWindow.transcriptListView !== null);
    }
    function test_transcriptAndPopupsRender() {
        appWindow.currentView = "lyrics";
        appWindow.subtitleChunks = [
            {
                start: 1,
                end: 2,
                text: "Hello. World."
            }
        ];
        wait(20);
        compare(appWindow.transcriptListView.count, 1);
        appWindow.availableSubtitles = [
            {
                label: "English",
                url: "file:///movie.srt",
                isEmbedded: false,
                embeddedIndex: -1
            }
        ];
        appWindow.subtitlePickerVisible = true;
        wait(20);
        appWindow.subtitlePickerVisible = false;
        appWindow.mediaChapters = [
            {
                time: 0,
                title: "Opening"
            },
            {
                time: 60,
                title: "Next"
            }
        ];
        appWindow.chaptersPopupVisible = true;
        wait(20);
        appWindow.chaptersPopupVisible = false;
        appWindow.openAboutDialog();
        wait(20);
    }
    function test_popupsStayWithPlayer_data() {
        return [
            {tag: "about", name: "aboutDialog"},
            {tag: "audio-options", name: "playbackOptionsPopup"},
            {tag: "models", name: "modelManager"},
            {tag: "recent-files", name: "recentFilesMenu"},
            {tag: "chapters", name: "chaptersPopup"},
            {tag: "subtitles", name: "subtitlePicker"},
            {tag: "resume", name: "resumeDialog"},
            {tag: "subtitle-settings", name: "subtitleSettingsPopup"},
            {tag: "subtitle-generation", name: "subtitleGenerationPopup"}
        ];
    }
    function test_popupsStayWithPlayer(data) {
        appWindow.width = 640;
        appWindow.height = 420;
        appWindow.requestActivate();
        tryCompare(appWindow, "active", true);
        if (data.name === "subtitleSettingsPopup") appWindow.openSubtitleSettings();
        if (data.name === "subtitleGenerationPopup") appWindow.openSubtitleGenerator();
        if (data.name === "aboutDialog") appWindow.openAboutDialog();
        if (data.name === "playbackOptionsPopup") appWindow.openPlaybackOptions();
        if (data.name === "modelManager") appWindow.openModelManager();
        if (data.name === "recentFilesMenu") appWindow.openRecentFiles();
        if (data.name === "chaptersPopup") {
            appWindow.mediaChapters = Array.from({length: 40}, function (_, i) {
                return {time: i * 60, title: "Chapter " + i + " with a very long title that must stay within the player"};
            });
            appWindow.chaptersPopupVisible = true;
        }
        if (data.name === "subtitlePicker") {
            appWindow.availableSubtitles = Array.from({length: 40}, function (_, i) {
                return {label: "Subtitle language " + i + " with a very long description that must fit", url: "file:///track" + i + ".srt", isEmbedded: false, embeddedIndex: -1};
            });
            appWindow.subtitlePickerVisible = true;
        }
        if (data.name === "resumeDialog") {
            appWindow.playbackHistory.savePosition(TestPaths.audioUrl, 15000, 60000);
            appWindow.loadMediaFile(TestPaths.audioUrl);
        }
        var popup = findChild(appWindow, data.name);
        verify(popup !== null);
        tryCompare(popup, "opened", true);
        tryCompare(popup, "activeFocus", true);
        verify(appWindow.modalDialogOpen);
        compare(popup.parent, appWindow.Overlay.overlay);
        compare(popup.contentItem.Window.window, appWindow);
        verify(popup.contentItem.height > 40, "Popup content must have a real layout height");
        function checkBounds() {
            verify(popup.width > 0 && popup.height > 0);
            verify(Math.abs(popup.x + popup.width / 2 - popup.parent.width / 2) < 1);
            verify(Math.abs(popup.y + popup.height / 2 - popup.parent.height / 2) < 1);
            verify(popup.x >= 19 && popup.y >= 19);
            verify(popup.x + popup.width <= popup.parent.width - 19);
            verify(popup.y + popup.height <= popup.parent.height - 19);
        }
        checkBounds();
        appWindow.width = 1100;
        appWindow.height = 800;
        wait(30);
        checkBounds();
        if (data.name === "resumeDialog") appWindow.startPlaybackOver();
        else keyClick(Qt.Key_Escape);
        tryCompare(popup, "opened", false);
        tryCompare(appWindow, "modalDialogOpen", false);
    }
    function test_modalKeyboardDoesNotControlPlayback() {
        appWindow.loadMediaFile(TestPaths.audioUrl);
        tryCompare(appWindow.mediaPlayer, "playbackState", MediaPlayer.PlayingState);
        appWindow.requestActivate();
        appWindow.openPlaybackOptions();
        var popup = findChild(appWindow, "playbackOptionsPopup");
        tryCompare(popup, "activeFocus", true);
        keyClick(Qt.Key_M);
        keyClick(Qt.Key_Space);
        keyClick(Qt.Key_F);
        verify(!appWindow.isMuted);
        compare(appWindow.mediaPlayer.playbackState, MediaPlayer.PlayingState);
        verify(appWindow.visibility !== Window.FullScreen);
        keyClick(Qt.Key_Escape);
        tryCompare(popup, "opened", false);
        tryCompare(appWindow, "modalDialogOpen", false);
        compare(appWindow.active, true);
        keyClick(Qt.Key_M);
        tryCompare(appWindow, "isMuted", true);
    }
    function test_spaceTogglesPlaybackWithoutReloading_data() {
        return [
            {tag: "video-surface", view: "video", control: "surface"},
            {tag: "audio-surface", view: "audio", control: "surface"},
            {tag: "playlist-row", view: "video", control: "playlist"},
            {tag: "audio-playlist-row", view: "audio", control: "playlist"},
            {tag: "keyboard-playlist-row", view: "video", control: "focused-playlist"},
            {tag: "fullscreen", view: "video", control: "fullscreen"},
            {tag: "toolbar-button", view: "video", control: "fileMenuButton"},
            {tag: "play-button", view: "video", control: "playPauseButton"},
            {tag: "timeline", view: "video", control: "timeline"},
            {tag: "volume", view: "video", control: "volume"}
        ];
    }
    function test_spaceTogglesPlaybackWithoutReloading(data) {
        appWindow.loadMediaFile(TestPaths.audioUrl);
        tryCompare(appWindow.mediaPlayer, "playbackState", MediaPlayer.PlayingState);
        tryVerify(function () { return appWindow.mediaPlayer.seekable; });
        appWindow.showMediaView(data.view);
        appWindow.requestActivate();
        tryCompare(appWindow, "active", true);
        if (data.control === "playlist" || data.control === "focused-playlist") {
            appWindow.togglePanel("playlist");
            var list = findChild(appWindow, "playlistListView");
            waitForRendering(list);
            mouseClick(list.itemAtIndex(0));
            tryCompare(appWindow.mediaPlayer, "playbackState", MediaPlayer.PlayingState);
            if (data.control === "focused-playlist") list.itemAtIndex(0).forceActiveFocus();
        } else {
            var target = appWindow.contentItem;
            if (data.control === "fullscreen") appWindow.toggleFullscreen();
            if (data.control === "timeline") target = appWindow.seekSlider;
            else if (data.control === "volume") target = appWindow.volumeSlider;
            else if (data.control !== "surface" && data.control !== "fullscreen") target = findChild(appWindow, data.control);
            target.forceActiveFocus();
        }
        appWindow.seekTo(15000);
        tryVerify(function () { return appWindow.mediaPlayer.position >= 14000; });
        var revision = appWindow.mediaRevision;
        var spy = createTemporaryObject(playbackStateSpy, testCase, {target: appWindow.mediaPlayer});
        keyClick(Qt.Key_Space);
        tryCompare(appWindow.mediaPlayer, "playbackState", MediaPlayer.PausedState);
        compare(appWindow.mediaRevision, revision, "Space must not reload the focused track");
        verify(appWindow.mediaPlayer.position >= 14000, "Pause must preserve the playback position");
        compare(spy.count, 1, "One press must toggle playback once");
        keyClick(Qt.Key_Space);
        tryCompare(appWindow.mediaPlayer, "playbackState", MediaPlayer.PlayingState);
        compare(appWindow.mediaRevision, revision);
        verify(appWindow.mediaPlayer.position >= 14000, "Resume must not restart the track");
        compare(spy.count, 2);
        verify(!appWindow.modalDialogOpen, "Space must not activate the focused toolbar button");
    }
    function test_heldSpaceTogglesOnlyOnce_data() {
        return [{tag: "pause", paused: false}, {tag: "resume", paused: true}];
    }
    function test_heldSpaceTogglesOnlyOnce(data) {
        appWindow.loadMediaFile(TestPaths.audioUrl);
        tryCompare(appWindow.mediaPlayer, "playbackState", MediaPlayer.PlayingState);
        if (data.paused) appWindow.mediaPlayer.pause();
        appWindow.requestActivate();
        tryCompare(appWindow, "active", true);
        appWindow.contentItem.forceActiveFocus();
        var spy = createTemporaryObject(playbackStateSpy, testCase, {target: appWindow.mediaPlayer});
        var expected = data.paused ? MediaPlayer.PlayingState : MediaPlayer.PausedState;
        keyPress(Qt.Key_Space);
        tryCompare(appWindow.mediaPlayer, "playbackState", expected);
        for (var i = 0; i < 5; ++i)
            TestInput.repeatSpace();
        keyRelease(Qt.Key_Space);
        compare(appWindow.mediaPlayer.playbackState, expected);
        compare(spy.count, 1, "Holding Space must not toggle playback repeatedly");
        keyClick(Qt.Key_Space);
        tryCompare(appWindow.mediaPlayer, "playbackState", data.paused ? MediaPlayer.PausedState : MediaPlayer.PlayingState);
        compare(spy.count, 2, "A new press after release must toggle again");
    }
    function test_finalVolumeSavedOnImmediateClose_data() {
        return [
            {tag: "video", view: "video", fullscreen: false, volume: 23},
            {tag: "audio", view: "audio", fullscreen: false, volume: 43},
            {tag: "fullscreen", view: "video", fullscreen: true, volume: 84},
            {tag: "zero", view: "video", fullscreen: false, volume: 0},
            {tag: "maximum", view: "audio", fullscreen: false, volume: 100},
            {tag: "fractional-wheel", view: "video", fullscreen: false, volume: 50.625}
        ];
    }
    function test_finalVolumeSavedOnImmediateClose(data) {
        appWindow.playerController.saveVolume(61);
        appWindow.volumeSlider.value = 61;
        appWindow.showMediaView(data.view);
        if (data.fullscreen) appWindow.showFullScreen();
        // Several changes should coalesce, but closing must save the last one
        // even before the 500 ms timer gets an event-loop turn.
        appWindow.volumeSlider.value = 15;
        appWindow.volumeSlider.value = data.volume;
        compare(appWindow.playerController.loadVolume(), 61, "Playback saves should remain debounced");
        appWindow.close();
        compare(appWindow.playerController.loadVolume(), Math.round(data.volume));
        appWindow.destroy();
        appWindow = null;
        wait(0);
        var component = Qt.createComponent(TestPaths.mainQml);
        appWindow = createTemporaryObject(component, testCase, {
            layoutPersistenceEnabled: false,
            desktopControlsEnabled: false
        });
        verify(appWindow !== null);
        compare(appWindow.volumeSlider.value, Math.round(data.volume));
    }
    function test_volumeArrowsAfterFocusingControls_data() {
        return [
            {tag: "startup", control: "startup"},
            {tag: "player", control: "player"},
            {tag: "timeline", control: "timeline"},
            {tag: "volume", control: "volume"},
            {tag: "toolbar-button", control: "fileMenuButton"}
        ];
    }
    function test_volumeArrowsAfterFocusingControls(data) {
        appWindow.requestActivate();
        tryCompare(appWindow, "active", true);
        appWindow.volumeSlider.value = 50;
        var target = appWindow.contentItem;
        if (data.control === "timeline") target = appWindow.seekSlider;
        if (data.control === "volume") target = appWindow.volumeSlider;
        if (data.control === "fileMenuButton") target = findChild(appWindow, "fileMenuButton");
        if (data.control !== "startup") target.forceActiveFocus();
        verify(!appWindow.modalDialogOpen);
        keyClick(Qt.Key_Up);
        compare(appWindow.volumeSlider.value, 55);
        keyClick(Qt.Key_Down);
        compare(appWindow.volumeSlider.value, 50);
    }
    function test_fileDialogsBelongToPlayer() {
        var names = ["mediaFileDialog", "playlistFileDialog", "lyricsFileDialog", "exportFileDialog"];
        for (var i = 0; i < names.length; ++i) {
            var dialog = findChild(appWindow, names[i]);
            verify(dialog !== null);
            compare(dialog.parentWindow, appWindow);
            compare(dialog.modality, Qt.WindowModal);
            // Use Qt's own dialog in tests instead of invoking desktop portals.
            dialog.options = NativeDialogs.FileDialog.DontUseNativeDialog;
            dialog.open();
            tryCompare(dialog, "visible", true);
            verify(appWindow.modalDialogOpen);
            dialog.reject();
            tryCompare(dialog, "visible", false);
            tryCompare(appWindow, "modalDialogOpen", false);
        }
    }
    function test_wheelChangesVolume_data() {
        return [
            {tag: "audio", view: "audio", volumeControl: false},
            {tag: "video", view: "video", volumeControl: false},
            {tag: "lyrics-volume", view: "lyrics", volumeControl: true},
            {tag: "playlist-volume", view: "playlist", volumeControl: true}
        ];
    }
    function test_wheelChangesVolume(data) {
        appWindow.currentView = data.view;
        appWindow.volumeSlider.value = 50;
        var surface = findChild(appWindow, data.volumeControl ? "volumeControl" : "playerSurface");
        waitForRendering(surface);
        mouseWheel(surface, surface.width / 2, surface.height / 2, 0, 120);
        compare(appWindow.volumeSlider.value, 55);
        mouseWheel(surface, surface.width / 2, surface.height / 2, 0, -120);
        compare(appWindow.volumeSlider.value, 50);
        mouseWheel(surface, surface.width / 2, surface.height / 2, 0, 15);
        compare(appWindow.volumeSlider.value, 50.625);
        mouseWheel(surface, surface.width / 2, surface.height / 2, 120, 0);
        compare(appWindow.volumeSlider.value, 50.625);
        mouseWheel(surface, surface.width / 2, surface.height / 2, 0, 120, Qt.NoButton, Qt.ControlModifier);
        compare(appWindow.volumeSlider.value, 50.625);
        appWindow.volumeSlider.value = 100;
        appWindow.isMuted = true;
        mouseWheel(surface, surface.width / 2, surface.height / 2, 0, 120);
        compare(appWindow.volumeSlider.value, 100);
        verify(!appWindow.isMuted);
        appWindow.volumeSlider.value = 0;
        mouseWheel(surface, surface.width / 2, surface.height / 2, 0, -120);
        compare(appWindow.volumeSlider.value, 0);
    }
    function test_wheelLeavesListsScrollable_data() {
        return [{tag: "transcript", view: "lyrics"}, {tag: "playlist", view: "playlist"}];
    }
    function test_wheelOverVolumeSlider_data() {
        return [{tag: "audio", view: "audio"}, {tag: "lyrics", view: "lyrics"}];
    }
    function test_wheelOverVolumeSlider(data) {
        appWindow.currentView = data.view;
        var volume = findChild(appWindow, "volumeControl");
        mouseMove(volume, 10, volume.height / 2);
        tryVerify(function () { return appWindow.volumeSlider.width > 20; });
        var slider = appWindow.volumeSlider;
        waitForRendering(slider);
        slider.value = 50;
        mouseWheel(slider, slider.width / 2, slider.height / 2, 0, 120);
        compare(slider.value, 55, "The handler and slider must not both change volume");
    }
    function prepareVideoClickTest(paused) {
        appWindow.loadMediaFile(TestPaths.audioUrl);
        tryVerify(function () { return appWindow.mediaPlayer.seekable; });
        tryCompare(appWindow.mediaPlayer, "playbackState", MediaPlayer.PlayingState);
        if (paused)
            appWindow.mediaPlayer.pause();
        appWindow.showMediaView("video");
        var video = findChild(appWindow, "videoPointerArea");
        waitForRendering(video);
        return video;
    }
    function test_videoDoubleClickPreservesPlayback_data() {
        return [{tag: "playing", paused: false}, {tag: "paused", paused: true}];
    }
    function test_videoDoubleClickPreservesPlayback(data) {
        var video = prepareVideoClickTest(data.paused);
        var state = appWindow.mediaPlayer.playbackState;
        var source = appWindow.mediaPlayer.source.toString();
        var spy = createTemporaryObject(playbackStateSpy, testCase, {target: appWindow.mediaPlayer});
        verify(spy.valid);
        for (var visibility of [Window.FullScreen, Window.Windowed]) {
            // Include the initial press/release: sending only a DoubleClick
            // event would miss the single-click pause that caused this bug.
            mouseDoubleClickSequence(video);
            tryCompare(appWindow, "visibility", visibility);
            compare(appWindow.mediaPlayer.playbackState, state);
            wait(Qt.styleHints.mouseDoubleClickInterval + 100);
            compare(appWindow.mediaPlayer.playbackState, state);
            compare(spy.count, 0, "Fullscreen must not cause even a temporary playback-state change");
            compare(appWindow.mediaPlayer.source.toString(), source);
        }
    }
    function test_videoSingleClickTogglesPlayback_data() {
        return [
            {tag: "windowed-pause", paused: false, fullscreen: false},
            {tag: "windowed-resume", paused: true, fullscreen: false},
            {tag: "fullscreen-pause", paused: false, fullscreen: true},
            {tag: "fullscreen-resume", paused: true, fullscreen: true}
        ];
    }
    function test_videoSingleClickTogglesPlayback(data) {
        var video = prepareVideoClickTest(data.paused);
        if (data.fullscreen) {
            appWindow.showFullScreen();
            waitForRendering(video);
        }
        var state = appWindow.mediaPlayer.playbackState;
        var spy = createTemporaryObject(playbackStateSpy, testCase, {target: appWindow.mediaPlayer});
        verify(spy.valid);
        mouseClick(video);
        compare(appWindow.mediaPlayer.playbackState, state, "The first click must allow time for a double click");
        tryCompare(appWindow.mediaPlayer, "playbackState", data.paused ? MediaPlayer.PlayingState : MediaPlayer.PausedState,
                   Qt.styleHints.mouseDoubleClickInterval + 500);
        wait(Qt.styleHints.mouseDoubleClickInterval + 100);
        compare(spy.count, 1, "One single click must toggle playback exactly once");
        compare(appWindow.visibility, data.fullscreen ? Window.FullScreen : Window.Windowed);
    }
    function test_pendingVideoClickCancelledWhenViewIsHidden() {
        var video = prepareVideoClickTest(false);
        var spy = createTemporaryObject(playbackStateSpy, testCase, {target: appWindow.mediaPlayer});
        mouseClick(video);
        appWindow.showMediaView("audio");
        appWindow.showMediaView("video");
        wait(Qt.styleHints.mouseDoubleClickInterval + 100);
        compare(appWindow.mediaPlayer.playbackState, MediaPlayer.PlayingState);
        compare(spy.count, 0, "A pending click must be cancelled when leaving the Video view");
    }
    function test_pendingVideoClickDoesNotToggleAnotherTrack() {
        var video = prepareVideoClickTest(false);
        mouseClick(video);
        appWindow.loadMediaFile(TestPaths.folderMediaUrl);
        tryCompare(appWindow.mediaPlayer, "playbackState", MediaPlayer.PlayingState);
        wait(Qt.styleHints.mouseDoubleClickInterval + 100);
        compare(appWindow.mediaPlayer.playbackState, MediaPlayer.PlayingState);
        compare(appWindow.mediaPlayer.source.toString(), TestPaths.folderMediaUrl);
    }
    function test_playbackRowsHaveSeparateHitAreas_data() {
        return [
            {tag: "small-video", view: "video", width: 640, fullscreen: false},
            {tag: "wide-video", view: "video", width: 1120, fullscreen: false},
            {tag: "audio", view: "audio", width: 1120, fullscreen: false},
            {tag: "fullscreen", view: "video", width: 1120, fullscreen: true}
        ];
    }
    function test_playbackRowsHaveSeparateHitAreas(data) {
        appWindow.reduceMotion = true;
        appWindow.width = data.width;
        appWindow.showMediaView(data.view);
        if (data.fullscreen) appWindow.showFullScreen();
        appWindow.controlsVisible = true;
        var controls = findChild(appWindow, "playbackControls");
        var speed = findChild(appWindow, "playbackOptionsButton");
        var fullscreen = findChild(appWindow, "fullscreenButton");
        var play = findChild(appWindow, "playPauseButton");
        var volume = findChild(appWindow, "volumeControl");
        waitForRendering(controls);
        var speedBottom = speed.mapToItem(controls, 0, speed.height).y;
        for (var control of [fullscreen, play, volume]) {
            var point = control.mapToItem(controls, 0, 0);
            verify(point.y - speedBottom >= 7.5, "Playback rows need a visible gap between their hit areas");
            verify(point.y + control.height <= controls.height - 5.5, "Controls must fit inside the bar's bottom padding");
        }
        mouseClick(speed);
        tryVerify(function () { return findChild(appWindow, "playbackOptionsPopup").opened; });
        findChild(appWindow, "playbackOptionsPopup").close();
        tryVerify(function () { return !findChild(appWindow, "playbackOptionsPopup").visible; });
        mouseClick(fullscreen);
        tryCompare(appWindow, "visibility", data.fullscreen ? Window.Windowed : Window.FullScreen);
    }
    function test_fullscreenControlsRevealFromBottomAndDismissOverPicture() {
        appWindow.reduceMotion = false;
        appWindow.showMediaView("video");
        appWindow.showFullScreen();
        var video = findChild(appWindow, "videoPointerArea");
        var controls = findChild(appWindow, "playbackControls");
        waitForRendering(video);
        mouseMove(video, video.width / 2, video.height / 2);
        tryCompare(controls, "visible", false, 600);
        mouseMove(video, video.width / 2 + 20, video.height / 2);
        verify(!controls.visible, "Moving over the picture must not summon the playback strip");
        verify(appWindow.fullscreenCursorVisible);
        tryCompare(appWindow, "fullscreenCursorVisible", false, 1800);
        compare(video.cursorShape, Qt.BlankCursor);
        mouseMove(video, video.width / 2 + 30, video.height / 2);
        verify(appWindow.fullscreenCursorVisible, "Movement must wake the cursor independently of the controls");
        verify(!controls.visible);
        mouseMove(video, video.width / 2, video.height - 2);
        tryCompare(controls, "visible", true, 300);
        mouseMove(controls, 6, controls.height / 2);
        tryCompare(controls, "controlsHovered", true);
        wait(1400);
        verify(controls.visible, "Controls must stay available while hovered");
        verify(appWindow.fullscreenCursorVisible);
        mouseMove(video, video.width / 2, video.height / 2);
        tryCompare(controls, "visible", false, 600);
    }
    function test_fullscreenControlsIdleTimeout() {
        appWindow.reduceMotion = true;
        appWindow.showMediaView("video");
        appWindow.showFullScreen();
        var video = findChild(appWindow, "videoPointerArea");
        var controls = findChild(appWindow, "playbackControls");
        waitForRendering(video);
        // The gap below the floating strip is in the reveal zone, but does not
        // hover a control. Leaving the pointer here must still time out.
        mouseMove(video, video.width / 2, video.height - 2);
        verify(controls.visible);
        verify(!controls.controlsHovered);
        tryCompare(controls, "visible", false, 1800);
        appWindow.showMediaView("audio");
        wait(1400);
        verify(controls.visible, "Audio controls must remain visible in fullscreen");
    }
    function test_fullscreenSliderDragKeepsControlsVisible_data() {
        return [{tag: "seek", seek: true}, {tag: "volume", seek: false}];
    }
    function test_fullscreenSliderDragKeepsControlsVisible(data) {
        appWindow.reduceMotion = true;
        appWindow.loadMediaFile(TestPaths.audioUrl);
        tryVerify(function () { return appWindow.mediaPlayer.seekable; });
        appWindow.mediaPlayer.pause();
        appWindow.showMediaView("video");
        appWindow.showFullScreen();
        var video = findChild(appWindow, "videoPointerArea");
        var controls = findChild(appWindow, "playbackControls");
        waitForRendering(video);
        mouseMove(video, video.width / 2, video.height - 2);
        var slider = data.seek ? appWindow.seekSlider : appWindow.volumeSlider;
        waitForRendering(slider);
        mousePress(slider, slider.width / 2, slider.height / 2);
        tryCompare(slider, "pressed", true);
        mouseMove(video, video.width / 2, video.height / 2);
        wait(1400);
        verify(controls.visible, "A slider must not disappear while dragging outside the strip");
        verify(controls.controlsInteracting);
        mouseRelease(video, video.width / 2, video.height / 2);
        tryCompare(slider, "pressed", false);
        tryCompare(controls, "visible", false, 600);
    }
    function preparePausedCaptionTest() {
        appWindow.loadMediaFile(TestPaths.audioUrl);
        tryCompare(appWindow.mediaPlayer, "playbackState", MediaPlayer.PlayingState);
        tryVerify(function () { return appWindow.mediaPlayer.seekable; });
        appWindow.mediaPlayer.pause();
        tryCompare(appWindow.mediaPlayer, "playbackState", MediaPlayer.PausedState);
        appWindow.showMediaView("video");
        appWindow.togglePanel("lyrics");
        appWindow.subtitleChunks = [
            {start: 10, end: 20, text: "First caption"},
            {start: 25, end: 35, text: "Second caption"}
        ];
        appWindow.seekTo(15000);
        tryCompare(appWindow, "activeSubtitleText", "First caption");
        compare(appWindow.currentActiveSubtitleIndex, 0);
        tryCompare(appWindow.transcriptListView, "currentIndex", 0);
        return createTemporaryObject(playbackStateSpy, testCase, {target: appWindow.mediaPlayer});
    }
    function test_subtitleTimingRefreshesWhilePaused_data() {
        return [
            {tag: "later-windowed", delta: 20, text: "", index: -1, fullscreen: false},
            {tag: "earlier-windowed", delta: -15, text: "Second caption", index: 1, fullscreen: false},
            {tag: "later-fullscreen", delta: 20, text: "", index: -1, fullscreen: true},
            {tag: "earlier-fullscreen", delta: -15, text: "Second caption", index: 1, fullscreen: true}
        ];
    }
    function test_subtitleTimingRefreshesWhilePaused(data) {
        var spy = preparePausedCaptionTest();
        if (data.fullscreen) appWindow.toggleFullscreen();
        var position = appWindow.mediaPlayer.position;
        appWindow.shiftSubtitles(data.delta);
        tryCompare(appWindow, "activeSubtitleText", data.text);
        compare(findChild(appWindow, "videoSubtitleText").text, data.text);
        compare(appWindow.currentActiveSubtitleIndex, data.index);
        tryCompare(appWindow.transcriptListView, "currentIndex", data.index);
        appWindow.shiftSubtitles(-data.delta);
        tryCompare(appWindow, "activeSubtitleText", "First caption");
        compare(appWindow.currentActiveSubtitleIndex, 0);
        tryCompare(appWindow.transcriptListView, "currentIndex", 0);
        compare(appWindow.mediaPlayer.position, position, "Timing changes must not seek playback");
        compare(appWindow.mediaPlayer.playbackState, MediaPlayer.PausedState);
        compare(spy.count, 0, "Timing changes must not briefly resume playback");
    }
    function test_replacingAndClearingSubtitlesRefreshesWhilePaused() {
        var spy = preparePausedCaptionTest();
        var position = appWindow.mediaPlayer.position;
        appWindow.subtitleChunks = [{start: 10, end: 20, text: "Replacement caption"}];
        tryCompare(appWindow, "activeSubtitleText", "Replacement caption");
        compare(appWindow.currentActiveSubtitleIndex, 0);
        appWindow.subtitleChunks = [
            {start: 0, end: 60, text: "Long title cue"},
            {start: 10, end: 20, text: "Replacement caption"},
            {start: 10, end: 20, text: "Replacement caption"}
        ];
        tryCompare(appWindow, "activeSubtitleText", "Long title cue\nReplacement caption");
        compare(appWindow.currentActiveSubtitleIndex, 1, "Keep the short dialogue cue highlighted and suppress duplicate text");
        appWindow.subtitleChunks = [];
        tryCompare(appWindow, "activeSubtitleText", "");
        compare(appWindow.currentActiveSubtitleIndex, -1);
        tryCompare(appWindow.transcriptListView, "currentIndex", -1);
        verify(!findChild(appWindow, "videoSubtitleOverlay").visible);
        compare(appWindow.mediaPlayer.position, position);
        compare(spy.count, 0);
    }
    function test_loadingSubtitleFileRefreshesWhilePaused() {
        var spy = preparePausedCaptionTest();
        var position = appWindow.mediaPlayer.position;
        var url = TestPaths.audioUrl.substring(0, TestPaths.audioUrl.lastIndexOf("/") + 1) + "paused-captions.srt";
        verify(appWindow.playerController.writeTextToFile(url, "1\n00:00:10,000 --> 00:00:20,000\nLoaded caption\n"));
        appWindow.loadSubtitleFile(url);
        tryCompare(appWindow, "activeSubtitleText", "Loaded caption");
        compare(findChild(appWindow, "videoSubtitleText").text, "Loaded caption");
        compare(appWindow.currentActiveSubtitleIndex, 0);
        compare(appWindow.mediaPlayer.position, position);
        compare(spy.count, 0);
    }
    function test_subtitleAppearanceSurvivesFullscreenAndReopening() {
        appWindow.showMediaView("video");
        appWindow.activeSubtitleText = "Subtitle size preference";
        appWindow.openSubtitleSettings();
        var popup = findChild(appWindow, "subtitleSettingsPopup");
        tryCompare(popup, "opened", true);
        var slider = findChild(popup, "subtitleFontSizeSlider");
        waitForRendering(slider);
        mouseClick(slider, slider.width * 0.85, slider.height / 2);
        var selected = appWindow.subtitleFontSize;
        verify(selected > 18, "The size slider must increase the actual subtitle preference");
        appWindow.subtitleTextColor = "#facc15";
        appWindow.subtitleBgOpacity = 0.8;
        popup.close();
        tryCompare(popup, "visible", false);
        var text = findChild(appWindow, "videoSubtitleText");
        compare(text.font.pixelSize, selected);
        for (var visibility of [Window.FullScreen, Window.Windowed, Window.FullScreen, Window.Windowed]) {
            appWindow.toggleFullscreen();
            tryCompare(appWindow, "visibility", visibility);
            waitForRendering(text);
            compare(appWindow.subtitleFontSize, selected);
            compare(text.font.pixelSize, selected, "Fullscreen changes must preserve the rendered font size");
        }
        // Choose a different size and immediately close, so a delayed settings
        // write cannot make this test pass before the close handler saves it.
        selected = selected === 36 ? 30 : selected + 1;
        appWindow.subtitleFontSize = selected;
        appWindow.close();
        var component = Qt.createComponent(TestPaths.mainQml);
        appWindow = createTemporaryObject(component, testCase, {
            layoutPersistenceEnabled: false,
            desktopControlsEnabled: false
        });
        verify(appWindow !== null);
        compare(appWindow.subtitleFontSize, selected, "The chosen font size must be saved before the window closes");
        compare(appWindow.subtitleTextColor, "#facc15");
        compare(appWindow.subtitleBgOpacity, 0.8);
        appWindow.showMediaView("video");
        appWindow.activeSubtitleText = "Restored subtitle size";
        text = findChild(appWindow, "videoSubtitleText");
        compare(text.font.pixelSize, selected);
        appWindow.openSubtitleSettings();
        popup = findChild(appWindow, "subtitleSettingsPopup");
        tryCompare(popup, "opened", true);
        compare(findChild(popup, "subtitleFontSizeSlider").value, selected);
        popup.close();
    }
    function test_subtitlePositionCanBeAdjustedAndRestored() {
        appWindow.showMediaView("video");
        appWindow.activeSubtitleText = "A readable subtitle";
        var caption = findChild(appWindow, "videoSubtitleOverlay");
        waitForRendering(caption);
        var originalY = caption.y;
        appWindow.openSubtitleSettings();
        var popup = findChild(appWindow, "subtitleSettingsPopup");
        tryCompare(popup, "opened", true);
        var slider = findChild(popup, "subtitleBottomGapSlider");
        waitForRendering(slider);
        mouseClick(slider, slider.width * 0.8, slider.height / 2);
        verify(appWindow.subtitleBottomMarginPercent > 12);
        verify(caption.y < originalY, "Increasing the bottom gap must raise subtitles");
        var selected = appWindow.subtitleBottomMarginPercent;
        popup.close();
        appWindow.close();
        appWindow.destroy();
        appWindow = null;
        wait(0);
        var component = Qt.createComponent(TestPaths.mainQml);
        appWindow = createTemporaryObject(component, testCase, {
            layoutPersistenceEnabled: false,
            desktopControlsEnabled: false
        });
        verify(appWindow !== null);
        compare(appWindow.subtitleBottomMarginPercent, selected, "Subtitle position must survive a new application window");
        appWindow.showMediaView("video");
        appWindow.width = 640;
        appWindow.height = 420;
        appWindow.subtitleFontSize = 36;
        appWindow.subtitleBottomMarginPercent = 25;
        appWindow.activeSubtitleText = "First line\nSecond line\nThird line\nFourth line\nFifth line";
        caption = findChild(appWindow, "videoSubtitleOverlay");
        waitForRendering(caption);
        verify(caption.y >= 12, "Tall captions must remain inside the top of the picture when they can fit");
    }
    function test_fullscreenStripDoesNotResizePictureOrShiftCaptions() {
        appWindow.reduceMotion = true;
        appWindow.showMediaView("video");
        appWindow.showFullScreen();
        appWindow.activeSubtitleText = "External caption";
        var surface = findChild(appWindow, "playerSurface");
        var controls = findChild(appWindow, "playbackControls");
        var caption = findChild(appWindow, "videoSubtitleOverlay");
        waitForRendering(surface);
        compare(surface.width, appWindow.width);
        compare(surface.height, appWindow.height);
        verify(controls.height <= 80, "Video controls must stay compact while leaving space between rows");
        verify(controls.width <= 1000 && controls.width <= appWindow.width - 24);
        compare(controls.x, (appWindow.width - controls.width) / 2);
        compare(controls.y + controls.height, surface.height - 12);
        verify(controls.color.a < 1);
        verify(caption.visible);
        verify(caption.y + caption.height <= controls.y - 12);
        verify(surface.height - caption.y - caption.height >= surface.height * 0.1,
               "Fullscreen subtitles should leave a comfortable gap below the text");
        var captionY = caption.y;
        appWindow.controlsVisible = false;
        compare(controls.visible, false);
        compare(surface.height, appWindow.height);
        compare(caption.y, captionY);
        appWindow.controlsVisible = true;
        compare(surface.height, appWindow.height);
        compare(caption.y, captionY);
    }
    function test_wheelRevealsFullscreenControls() {
        appWindow.currentView = "video";
        appWindow.showFullScreen();
        appWindow.controlsVisible = false;
        appWindow.volumeSlider.value = 50;
        var surface = findChild(appWindow, "playerSurface");
        mouseWheel(surface, surface.width / 2, surface.height / 2, 0, 120);
        compare(appWindow.volumeSlider.value, 55);
        verify(appWindow.controlsVisible);
        compare(appWindow.visibility, Window.FullScreen);
    }
    function test_wheelLeavesListsScrollable(data) {
        appWindow.currentView = data.view;
        if (data.view === "lyrics") {
            appWindow.subtitleChunks = Array.from({length: 60}, function (_, i) {
                return {start: i * 5, end: i * 5 + 4, text: "Transcript line " + i};
            });
        } else {
            appWindow.playlist = Array.from({length: 60}, function (_, i) {
                return {title: "Track " + i, url: "file:///track" + i + ".mp3"};
            });
        }
        var list = data.view === "lyrics" ? appWindow.transcriptListView : findChild(appWindow, "playlistListView");
        waitForRendering(list);
        appWindow.volumeSlider.value = 50;
        var before = list.contentY;
        mouseWheel(list, list.width / 2, list.height / 2, 0, -360);
        tryVerify(function () { return list.contentY > before; });
        compare(appWindow.volumeSlider.value, 50);
    }
    function test_wheelDoesNotChangeVolumeBehindPopup() {
        appWindow.volumeSlider.value = 50;
        appWindow.openPlaybackOptions();
        var popup = findChild(appWindow, "playbackOptionsPopup");
        tryCompare(popup, "opened", true);
        var surface = findChild(appWindow, "playerSurface");
        mouseWheel(surface, surface.width - 10, 10, 0, 120);
        compare(appWindow.volumeSlider.value, 50);
        popup.close();
    }
    function test_escapeClosesPopupBeforeLeavingFullscreen() {
        appWindow.requestActivate();
        appWindow.showFullScreen();
        tryCompare(appWindow, "visibility", Window.FullScreen);
        appWindow.openModelManager();
        var popup = findChild(appWindow, "modelManager");
        tryCompare(popup, "activeFocus", true);
        keyClick(Qt.Key_Escape);
        tryCompare(popup, "opened", false);
        compare(appWindow.visibility, Window.FullScreen);
        tryCompare(appWindow, "modalDialogOpen", false);
        compare(appWindow.active, true);
        keyClick(Qt.Key_Escape);
        tryCompare(appWindow, "visibility", Window.Windowed);
    }
    function test_generationOptionsBelongToApplicationState() {
        appWindow.currentView = "lyrics";
        appWindow.subtitleLanguage = "Spanish";
        appWindow.subtitleModel = "base";
        appWindow.translateSubtitles = true;
        wait(20);
        compare(appWindow.subtitleLanguage, "Spanish");
        compare(appWindow.subtitleModel, "base");
        verify(appWindow.translateSubtitles);
    }
    function test_videoUsesWindowWithoutDecorativeMargins() {
        appWindow.showMediaView("video");
        appWindow.activeSubtitleText = "Windowed subtitle";
        var surface = findChild(appWindow, "playerSurface");
        for (var size of [[1120, 720], [640, 420]]) {
            appWindow.width = size[0];
            appWindow.height = size[1];
            wait(30);
            var origin = surface.mapToItem(appWindow.contentItem, 0, 0);
            compare(origin.x, 0);
            compare(origin.y, 40);
            compare(surface.width, appWindow.width);
            compare(surface.height, appWindow.height - 40 - findChild(appWindow, "playbackControls").height);
            compare(surface.color, Qt.color("#000000"));
            var caption = findChild(appWindow, "videoSubtitleOverlay");
            verify(surface.height - caption.y - caption.height >= surface.height * 0.1,
                   "Windowed subtitles must also leave room below the text");
            verify(findChild(appWindow, "thumbnailButton").visible);
            var play = findChild(appWindow, "playPauseButton");
            verify(play.visible && play.width >= 30 && play.height <= 34);
        }
    }
    function test_panelsPreservePlaybackAndVideoOutput() {
        appWindow.loadMediaFile(TestPaths.audioUrl);
        tryVerify(function () { return appWindow.mediaPlayer.seekable; });
        appWindow.mediaPlayer.pause();
        appWindow.showMediaView("video");
        var output = appWindow.videoOutput;
        var source = appWindow.mediaPlayer.source.toString();
        mouseClick(findChild(appWindow, "lyricsPanelButton"));
        compare(appWindow.panelView, "lyrics");
        compare(appWindow.mediaView, "video");
        compare(appWindow.currentView, "video");
        var surface = findChild(appWindow, "playerSurface");
        var panel = findChild(appWindow, "sidePanel");
        wait(30);
        verify(surface.visible && panel.visible);
        verify(surface.width < appWindow.width);
        mouseClick(findChild(appWindow, "expandPanelButton"));
        wait(30);
        verify(appWindow.panelExpanded && !surface.visible);
        mouseClick(findChild(appWindow, "expandPanelButton"));
        wait(30);
        verify(!appWindow.panelExpanded && surface.visible);
        mouseClick(findChild(appWindow, "playlistPanelButton"));
        compare(appWindow.panelView, "playlist");
        mouseClick(findChild(appWindow, "closePanelButton"));
        wait(30);
        verify(!panel.visible && surface.visible);
        compare(surface.width, appWindow.width);
        compare(appWindow.videoOutput, output);
        compare(appWindow.mediaPlayer.source.toString(), source);
        compare(appWindow.mediaPlayer.playbackState, MediaPlayer.PausedState);
    }
    function test_transcriptTypingDoesNotTriggerPlayerShortcuts() {
        appWindow.requestActivate();
        appWindow.currentView = "lyrics";
        appWindow.subtitleChunks = [{start: 0, end: 20, text: "f m n p words"}];
        var search = findChild(appWindow, "transcriptSearchField");
        search.forceActiveFocus();
        keyClick(Qt.Key_F);
        keyClick(Qt.Key_Space);
        keyClick(Qt.Key_M);
        compare(search.text, "f m");
        compare(appWindow.transcriptSearchQuery, "f m");
        verify(!appWindow.isMuted);
        verify(appWindow.visibility !== Window.FullScreen);
    }
    function test_seekPreviewKeepsTimeChaptersAndSubtitles() {
        appWindow.loadMediaFile(TestPaths.audioUrl);
        tryVerify(function () { return appWindow.mediaPlayer.duration > 0; });
        appWindow.mediaPlayer.pause();
        appWindow.subtitleChunks = [{start: 0, end: 60, text: "Preview line"}];
        appWindow.mediaChapters = [{time: 0, title: "Opening"}];
        var slider = appWindow.seekSlider;
        mouseMove(slider, slider.width / 2, slider.height / 2);
        var preview = findChild(appWindow, "seekPreview");
        tryCompare(preview, "visible", true);
        compare(findChild(appWindow, "seekPreviewSubtitle").text, "Preview line");
        verify(findChild(appWindow, "seekPreviewTime").text !== "0:00");
        appWindow.openPlaybackOptions();
        tryCompare(preview, "visible", false);
    }
    function test_ambientIsLimitedToChromeAndCanBeDisabledFromMenu() {
        appWindow.ambientEnabled = true;
        appWindow.ambientStrength = 1;
        compare(appWindow.ambientStrength, 0.25);
        appWindow.ambientSourceColor = "#ffcc00";
        appWindow.showMediaView("video");
        compare(findChild(appWindow, "playerSurface").color, Qt.color("#000000"));
        mouseClick(findChild(appWindow, "optionsMenuButton"));
        var options = findChild(appWindow, "optionsMenu");
        tryCompare(options, "opened", true);
        mouseClick(options.itemAt(2));
        tryCompare(findChild(appWindow, "appearanceMenu"), "opened", true);
        mouseClick(findChild(appWindow, "ambientToggle"));
        verify(!appWindow.ambientEnabled);
        tryCompare(appWindow, "chromeColor", Qt.color("#1b2835"));
        appWindow.ambientEnabled = true;
        appWindow.ambientStrength = 0.12;
    }
    function test_generationDialogAvailableWithExistingSubtitles() {
        appWindow.subtitleChunks = [{start: 0, end: 5, text: "Keep existing lines"}];
        appWindow.openSubtitleGenerator();
        tryCompare(findChild(appWindow, "subtitleGenerationPopup"), "opened", true);
        compare(appWindow.subtitleChunks[0].text, "Keep existing lines");
        verify(appWindow.modalDialogOpen);
    }

    function test_audioHasItsOwnPresentationAndLargerControls() {
        appWindow.loadMediaFile(TestPaths.audioUrl);
        tryVerify(function () { return appWindow.mediaPlayer.seekable; });
        appWindow.mediaPlayer.pause();
        appWindow.playbackOptions.rate = 1.25;
        appWindow.volumeSlider.value = 45;
        appWindow.ambientEnabled = true;
        appWindow.reduceMotion = false;
        var source = appWindow.mediaPlayer.source.toString();
        var output = appWindow.videoOutput;
        appWindow.showMediaView("video");
        wait(30);
        var play = findChild(appWindow, "playPauseButton");
        var videoButtonHeight = play.height;
        appWindow.showMediaView("audio");
        wait(30);
        verify(findChild(appWindow, "audioPresentation").visible);
        verify(findChild(appWindow, "audioArtwork").width >= 240);
        verify(findChild(appWindow, "audioAmbientLight").visible);
        verify(play.height >= 56 && play.height > videoButtonHeight);
        appWindow.showFullScreen();
        tryCompare(appWindow, "visibility", Window.FullScreen);
        var playlistButton = findChild(appWindow, "playlistPanelButton");
        verify(playlistButton.visible);
        mouseClick(playlistButton);
        compare(appWindow.panelView, "playlist");
        verify(!appWindow.panelExpanded);
        verify(findChild(appWindow, "audioPresentation").visible);
        mouseClick(findChild(appWindow, "closePanelButton"));
        compare(appWindow.mediaPlayer.source.toString(), source);
        compare(appWindow.videoOutput, output);
        compare(appWindow.mediaPlayer.playbackState, MediaPlayer.PausedState);
        compare(appWindow.playbackOptions.rate, 1.25);
        compare(appWindow.volumeSlider.value, 45);
        appWindow.showNormal();
        tryCompare(appWindow, "visibility", Window.Windowed);
        appWindow.showMediaView("video");
        wait(30);
        compare(play.height, videoButtonHeight);
        compare(findChild(appWindow, "playerSurface").height,
                appWindow.height - 40 - findChild(appWindow, "playbackControls").height);
    }
    function test_audioLayoutFitsSmallWindowsAndSidePanels_data() {
        return [{tag: "empty", loaded: false}, {tag: "single-track", loaded: true}, {tag: "multiple-tracks", loaded: true, multipleTracks: true}];
    }
    function test_audioLayoutFitsSmallWindowsAndSidePanels(data) {
        if (data.loaded) {
            appWindow.loadMediaFile(TestPaths.audioUrl);
            tryVerify(function () { return appWindow.mediaPlayer.seekable; });
            appWindow.mediaPlayer.pause();
            appWindow.playlist = [{url: TestPaths.audioUrl, title: "An intentionally long track title that must fit beside the artwork", artist: "An artist with a long name"}];
            if (data.multipleTracks)
                appWindow.playlist = appWindow.playlist.concat([{url: TestPaths.audioUrl, title: "The next track"}]);
            appWindow.activeSubtitleText = "A long live lyric line which should wrap inside its card while all playback controls remain usable.";
        }
        appWindow.availableSubtitles = [{label: "English", url: "file:///movie.srt", isEmbedded: false, embeddedIndex: -1}];
        appWindow.mediaChapters = [{time: 0, title: "Opening"}];
        for (var size of [[640, 420], [640, 800], [1120, 720]]) {
            appWindow.width = size[0];
            appWindow.height = size[1];
            appWindow.showMediaView("audio");
            for (var panel of ["", "lyrics", "playlist"]) {
                appWindow.closePanel();
                if (panel !== "") appWindow.togglePanel(panel);
                wait(30);
                var surface = findChild(appWindow, "playerSurface");
                for (var name of ["audioArtwork", "audioLiveLyrics", "audioUpNext"]) {
                    var item = findChild(appWindow, name);
                    if (name === "audioUpNext" && !data.multipleTracks) {
                        verify(!item.visible, "No next track must not produce an Up next card");
                        continue;
                    }
                    verify(item.visible, name);
                    var point = item.mapToItem(surface, 0, 0);
                    verify(point.x >= -1 && point.y >= -1, name + " starts outside the audio view");
                    verify(point.x + item.width <= surface.width + 1, name + " overflows the audio width");
                    verify(point.y + item.height <= surface.height + 1, name + " overflows the audio height");
                }
                for (var control of [findChild(appWindow, "playPauseButton"), appWindow.seekSlider, appWindow.volumeSlider]) {
                    var position = control.mapToItem(appWindow.contentItem, 0, 0);
                    verify(position.x >= 0 && position.y >= 0);
                    verify(position.x + control.width <= appWindow.width);
                    verify(position.y + control.height <= appWindow.height);
                }
            }
        }
    }
    function test_audioAmbientHonorsAppearancePreferences() {
        appWindow.showMediaView("audio");
        appWindow.ambientEnabled = true;
        appWindow.reduceMotion = false;
        var light = findChild(appWindow, "audioAmbientLight");
        verify(light.visible);
        appWindow.ambientEnabled = false;
        verify(!light.visible);
        appWindow.ambientEnabled = true;
        appWindow.reduceMotion = true;
        verify(!light.visible);
        appWindow.reduceMotion = false;
        appWindow.showMediaView("video");
        verify(!light.visible);
        compare(findChild(appWindow, "playerSurface").color, Qt.color("#000000"));
    }

    function test_audioLabelsAndUpNextFollowTheLoadedTrackAndLoopSetting() {
        appWindow.loopPlaylist = false;
        appWindow.showMediaView("audio");
        var state = findChild(appWindow, "audioPlaybackState");
        var next = findChild(appWindow, "audioUpNext");
        var title = findChild(appWindow, "audioUpNextTitle");
        compare(state.text, "OPEN MEDIA");
        verify(!next.visible);
        appWindow.loadMediaFile(TestPaths.audioUrl);
        tryCompare(appWindow, "hasLoadedTrack", true);
        tryCompare(state, "text", "NOW PLAYING");
        appWindow.mediaPlayer.pause();
        tryCompare(state, "text", "PAUSED");
        appWindow.playlist = [{url: TestPaths.audioUrl, title: "First song"}, {url: TestPaths.audioUrl, title: "Second song"}];
        tryCompare(next, "visible", true);
        compare(title.text, "Second song");
        mouseClick(next);
        compare(appWindow.currentTrackIndex, 1);
        tryCompare(next, "visible", false);
        appWindow.mediaPlayer.pause();
        appWindow.loopPlaylist = true;
        tryCompare(next, "visible", true);
        compare(title.text, "First song");
        appWindow.loopPlaylist = false;
        tryCompare(next, "visible", false);
        appWindow.seekTo(appWindow.mediaPlayer.duration - 150);
        appWindow.playCurrentTrack();
        tryCompare(appWindow, "currentTrackIndex", -1, 5000);
        compare(state.text, "PLAYBACK FINISHED");
        verify(!appWindow.hasLoadedTrack);
        verify(!next.visible);
    }

}
