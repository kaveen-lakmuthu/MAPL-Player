import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

ColumnLayout {
    id: root
    required property var app
    spacing: 12
    Text { text: "Generate lyrics & subtitles"; color: "#edf3fa"; font.pixelSize: 16; font.bold: true; Layout.fillWidth: true; wrapMode: Text.WordWrap }
    Text { text: "Whisper processes the current track locally. Models can be downloaded and managed separately."; color: "#b9c8d7"; font.pixelSize: 12; wrapMode: Text.WordWrap; Layout.fillWidth: true }
    GridLayout {
        columns: 2
        Layout.fillWidth: true
        columnSpacing: 12
        rowSpacing: 10
        Label { text: "Model" }
        DesktopComboBox {
            Layout.fillWidth: true
            model: ["Tiny · fast · 77.7 MB", "Base · accurate · 148 MB"]
            currentIndex: app.subtitleModel === "tiny" ? 0 : 1
            onActivated: app.subtitleModel = currentIndex === 0 ? "tiny" : "base"
        }
        Label { text: "Task" }
        DesktopComboBox {
            Layout.fillWidth: true
            model: ["Transcribe original", "Translate to English"]
            currentIndex: app.translateSubtitles ? 1 : 0
            onActivated: app.translateSubtitles = currentIndex === 1
        }
        Label { text: "Language" }
        DesktopComboBox {
            Layout.fillWidth: true
            model: ["Auto-Detect", "English", "Spanish", "French", "German", "Japanese", "Chinese", "Korean", "Russian", "Portuguese", "Italian"]
            currentIndex: Math.max(0, model.indexOf(app.subtitleLanguage))
            enabled: !app.translateSubtitles
            onActivated: app.subtitleLanguage = currentText
        }
    }
    RowLayout {
        spacing: 8
        DesktopButton {
            text: "Generate"
            prominent: true
            enabled: app.currentTrackIndex !== -1 && !app.modelDownloader.isBusy && !app.subtitleGenerator.isProcessing
            onClicked: {
                app.generateSubtitlesForCurrentTrack();
                if (app.backgroundTasks.count > 0)
                    app.openBackgroundTasks();
            }
        }
        DesktopButton { text: "Whisper models…"; onClicked: app.openModelManager() }
    }
    Text { visible: app.currentTrackIndex < 0; text: "Open a media file first."; color: "#b9c8d7"; font.pixelSize: 12 }
    DesktopButton {
        visible: app.backgroundTasks.count > 0
        text: "View background tasks…"
        onClicked: app.openBackgroundTasks()
    }
}
