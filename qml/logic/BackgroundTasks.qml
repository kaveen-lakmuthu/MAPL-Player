import QtQml

QtObject {
    required property var app
    readonly property bool downloading: app.modelDownloader.isBusy
    readonly property bool transcribing: app.subtitleGenerator.isProcessing
    readonly property int count: Number(downloading) + Number(transcribing)
    readonly property string downloadLabel: (app.modelDownloader.isVerifying ? "Verifying " : "Downloading ") + (app.modelDownloader.activeModel || "Whisper models")
    readonly property string transcriptionLabel: app.subtitleGenerator.isCancelling ? "Cancelling transcription…" : "Transcribing locally"
    readonly property string summary: count > 1 ? "2 background tasks" : downloading ? downloadLabel : transcribing ? transcriptionLabel : "No background tasks"
    readonly property string badge: count > 1 ? "2" : downloading ? (app.modelDownloader.isVerifying ? "…" : Math.round(app.downloadProgressValue) + "%") : transcribing ? (app.subtitleGenerator.isCancelling ? "…" : Math.round(app.transcriptionProgressValue) + "%") : ""
}
