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
    function init() {
        failOnWarning(/(ReferenceError|TypeError|is not defined|Cannot assign|Binding loop)/);
        var component = Qt.createComponent(TestPaths.mainQml);
        compare(component.status, Component.Ready, component.errorString());
        appWindow = createTemporaryObject(component, testCase, {
            desktopControlsEnabled: false
        });
        verify(appWindow !== null);
        appWindow.playbackOptions.rate = 1;
        appWindow.playbackHistory.clearRecentFiles();
        appWindow.playbackHistory.clearPosition(TestPaths.audioUrl);
        wait(20);
    }
    function cleanup() {
        if (appWindow)
            appWindow.close();
    }
    function test_transcriptionCancelIsAvailableAcrossViews() {
        appWindow.subtitleGenerator.generateSubtitles("", "", "", false);
        var button = findChild(appWindow, "cancelSubtitleGeneration");
        verify(button !== null);
        for (var i = 0; i < 4; ++i) {
            appWindow.currentView = ["audio", "video", "lyrics", "playlist"][i];
            wait(20);
            verify(button.visible);
            verify(button.enabled);
        }
        mouseClick(button);
        verify(!appWindow.subtitleGenerator.isProcessing);
        verify(!button.visible);
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
        appWindow.resetAudioDelay();
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
        var surface = findChild(appWindow, "playerSurface");
        for (var size of [[1120, 720], [640, 420]]) {
            appWindow.width = size[0];
            appWindow.height = size[1];
            wait(30);
            var origin = surface.mapToItem(appWindow.contentItem, 0, 0);
            compare(origin.x, 0);
            compare(origin.y, 40);
            compare(surface.width, appWindow.width);
            compare(surface.height, appWindow.height - 112);
            compare(surface.color, Qt.color("#000000"));
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
        mouseClick(findChild(appWindow, "audioPlaylistButton"));
        compare(appWindow.panelView, "playlist");
        verify(!appWindow.panelExpanded);
        verify(findChild(appWindow, "audioPresentation").visible);
        mouseClick(findChild(appWindow, "closePanelButton"));
        compare(appWindow.mediaPlayer.source.toString(), source);
        compare(appWindow.videoOutput, output);
        compare(appWindow.mediaPlayer.playbackState, MediaPlayer.PausedState);
        compare(appWindow.playbackOptions.rate, 1.25);
        compare(appWindow.volumeSlider.value, 45);
        appWindow.showMediaView("video");
        wait(30);
        compare(play.height, videoButtonHeight);
        compare(findChild(appWindow, "playerSurface").height, appWindow.height - 112);
    }
    function test_audioLayoutFitsSmallWindowsAndSidePanels_data() {
        return [{tag: "empty", loaded: false}, {tag: "playing", loaded: true}];
    }
    function test_audioLayoutFitsSmallWindowsAndSidePanels(data) {
        if (data.loaded) {
            appWindow.loadMediaFile(TestPaths.audioUrl);
            tryVerify(function () { return appWindow.mediaPlayer.seekable; });
            appWindow.mediaPlayer.pause();
            appWindow.playlist = [{url: TestPaths.audioUrl, title: "An intentionally long track title that must fit beside the artwork", artist: "An artist with a long name"}];
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
                for (var name of ["audioArtwork", "audioLiveLyrics", "audioUpNext", "audioPlaylistButton"]) {
                    var item = findChild(appWindow, name);
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

}
