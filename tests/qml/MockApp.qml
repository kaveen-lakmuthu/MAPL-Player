import QtQuick
import QtMultimedia
import "../../qml/logic" as Logic

Item {
    id: root
    property var playlist: []
    property int currentTrackIndex: -1
    property bool playFolderToggle: false
    property int mediaRevision: 0
    property var subtitleGenerationRequest: null
    property var subtitleChunks: []
    property string activeSubtitleText: ""
    property string currentLyrics: ""
    property string currentTimelinePreviewSheet: ""
    property var availableSubtitles: []
    property bool subtitlePickerVisible: false
    property bool subtitleDetectionDone: false
    property string activeSubtitleUrl: ""
    property int activeEmbeddedTrackIndex: -1
    property var mediaChapters: []
    property bool chaptersPopupVisible: false
    property string currentThumbnailDataUrl: ""
    property string currentView: "audio"
    property bool sidebarOpen: false
    property string messageText: ""
    property int themeResets: 0
    property real transcriptionProgressValue: 0
    property real downloadProgressValue: 0
    property string subtitleModel: "tiny"
    property string subtitleLanguage: "English"
    property bool translateSubtitles: false
    property alias mediaPlayer: player
    property alias playerController: controller
    property alias subtitleGenerator: generator
    property alias modelDownloader: downloader
    property alias playbackSession: session
    property alias playbackMemory: memory
    property alias playbackHistory: history
    property alias subtitleJobs: jobs
    property alias subtitleFiles: files

    function showMessage(message) {
        messageText = message;
    }
    function resetTheme() {
        ++themeResets;
    }
    function seekTo(position) {
        player.position = position;
    }
    function resetAudioDelay() {
    }
    function loadTrack(index) {
        session.loadTrack(index);
    }
    function playCurrentTrack() {
        session.playCurrentTrack();
    }
    function loadMediaFile(url) {
        session.loadMediaFile(url);
    }
    function generateSubtitlesForCurrentTrack() {
        jobs.generateSubtitlesForCurrentTrack();
    }
    function invalidateSubtitleFiles() {
        files.invalidate();
    }
    function clearSubtitles() {
        files.clear();
    }
    function loadSubtitleFile(url, showTranscript) {
        files.load(url, undefined, showTranscript);
    }
    function selectEmbeddedSubtitle(index) {
        files.selectEmbedded(index);
    }
    function cancelSubtitleGeneration() {
        jobs.cancelGeneration();
    }
    function track(url, title) {
        return {
            url: url,
            title: title
        };
    }
    function loadExamplePlaylist(index) {
        playlist = [track("file:///A.mp4", "A"), track("file:///B.mp4", "B"), track("file:///C.mp4", "C")];
        session.loadTrack(index);
        session.playCurrentTrack();
    }

    Logic.PlaybackMemory {
        id: memory
        app: root
    }
    Logic.PlaybackSession {
        id: session
        app: root
    }
    Logic.SubtitleFiles {
        id: files
        app: root
    }
    Logic.SubtitleJobs {
        id: jobs
        app: root
    }

    QtObject {
        id: player
        property url source
        property int playbackState: MediaPlayer.StoppedState
        property int mediaStatus: MediaPlayer.NoMedia
        property int activeSubtitleTrack: -1
        property real position: 0
        property real duration: 100000
        property bool seekable: true
        property int pauseCalls: 0
        onSourceChanged: {
            playbackState = MediaPlayer.StoppedState;
            mediaStatus = MediaPlayer.LoadingMedia;
            position = 0;
        }
        onMediaStatusChanged: session.handleMediaStatusChanged(mediaStatus)
        function play() {
            if (mediaStatus === MediaPlayer.EndOfMedia)
                position = 0;
            mediaStatus = MediaPlayer.LoadedMedia;
            playbackState = MediaPlayer.PlayingState;
        }
        function pause() {
            ++pauseCalls;
            playbackState = MediaPlayer.PausedState;
        }
        function stop() {
            position = 0;
            playbackState = MediaPlayer.StoppedState;
        }
        function finish() {
            position = duration;
            playbackState = MediaPlayer.StoppedState;
            mediaStatus = MediaPlayer.EndOfMedia;
        }
    }
    QtObject {
        id: history
        property var positions: ({})
        property var saves: []
        property var recentFiles: []
        property bool available: true
        property int refreshCount: 0
        function isAvailable(url) {
            return available;
        }
        function recordFile(url) {
            var entries = recentFiles.filter(function (entry) {
                return entry.url !== url;
            });
            recentFiles = [
                {
                    url: url,
                    title: url.split("/").pop(),
                    path: url,
                    available: true
                }
            ].concat(entries).slice(0, 20);
        }
        function refreshRecentFiles() {
            ++refreshCount;
        }
        function clearRecentFiles() {
            recentFiles = [];
        }
        function savePosition(url, position, duration) {
            saves = saves.concat([
                {
                    url: url,
                    position: position,
                    duration: duration
                }
            ]);
            var next = Object.assign({}, positions);
            next[url] = position >= 5000 && duration - position > Math.min(10000, duration / 20) ? position : 0;
            positions = next;
        }
        function resumePosition(url, duration) {
            var position = positions[url] || 0;
            if (duration !== undefined && duration > 0 && duration - position <= Math.min(10000, duration / 20))
                return 0;
            return position;
        }
        function clearPosition(url) {
            var next = Object.assign({}, positions);
            next[url] = 0;
            positions = next;
        }
        function sync() {
        }
    }
    QtObject {
        id: controller
        property bool looping: false
        property var folderTracks: []
        function loadLoop() {
            return looping;
        }
        function getFilesInFolder(url) {
            return folderTracks.slice();
        }
        function getCleanFileName(url) {
            return url.split("/").pop();
        }
        property var chapterCalls: []
        property var extractionCalls: []
        property int cancelCount: 0
        signal mediaChaptersReady(int requestId, var chapters)
        signal embeddedSubtitleReady(int requestId, string fileUrl)
        signal embeddedSubtitleError(int requestId, string message)
        function scanMediaChapters(url, id) {
            chapterCalls = chapterCalls.concat([
                {
                    url: url,
                    id: id
                }
            ]);
        }
        function extractEmbeddedSubtitle(url, index, id) {
            extractionCalls = extractionCalls.concat([
                {
                    url: url,
                    index: index,
                    id: id
                }
            ]);
        }
        function cancelMediaJobs() {
            ++cancelCount;
        }
        function cancelSubtitleExtraction() {
            ++cancelCount;
        }
        function getThumbnail(url) {
            return "";
        }
    }
    QtObject {
        id: generator
        property bool isProcessing: false
        property bool isCancelling: false
        property int cancelCalls: 0
        signal cancelled
        property var calls: []
        signal progressChanged(int progress)
        signal subtitlesReady(var chunks)
        signal errorOccurred(string errorMsg)
        function generateSubtitles(mediaPath, modelPath, language, translate) {
            if (isProcessing)
                return;
            calls = calls.concat([
                {
                    mediaPath: mediaPath,
                    modelPath: modelPath,
                    language: language,
                    translate: translate
                }
            ]);
            isProcessing = true;
        }
        function cancel() {
            if (isProcessing) {
                isCancelling = true;
                ++cancelCalls;
            }
        }
        function finishCancellation() {
            isProcessing = false;
            isCancelling = false;
            cancelled();
        }
        function complete(chunks) {
            isProcessing = false;
            isCancelling = false;
            subtitlesReady(chunks);
        }
        function fail(message) {
            isProcessing = false;
            errorOccurred(message);
        }
    }
    QtObject {
        id: downloader
        property bool isDownloading: false
        property bool isVerifying: false
        readonly property bool isBusy: isDownloading || isVerifying
        property string activeModel: ""
        property bool cached: true
        property var calls: []
        signal progressChanged(real progress)
        signal modelReady(string modelName, string filePath)
        signal operationCancelled(string modelName)
        signal downloadFinished(string filePath)
        signal downloadError(string errorMsg)
        signal modelError(string modelName, string errorMsg)
        function checkModelExists(model) {
            return cached;
        }
        function getModelPath(model) {
            return "/models/ggml-" + model + ".bin";
        }
        function prepareModel(model) {
            if (isBusy)
                return;
            if (cached)
                modelReady(model, getModelPath(model));
            else
                startDownload(model);
        }
        function startDownload(model) {
            if (isDownloading)
                return;
            calls = calls.concat([model]);
            activeModel = model;
            isDownloading = true;
        }
        function complete() {
            isDownloading = false;
            cached = true;
            downloadFinished(getModelPath(calls[calls.length - 1]));
            modelReady(calls[calls.length - 1], getModelPath(calls[calls.length - 1]));
        }
        function fail(message) {
            isDownloading = false;
            modelError(activeModel, message);
            downloadError(message);
        }
    }
}
