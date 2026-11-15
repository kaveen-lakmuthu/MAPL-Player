import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../components"

PlayerPopup {
    id: root
    objectName: "backgroundTasksPopup"
    preferredWidth: 380
    anchors.centerIn: null
    x: Math.max(margins, parent.width - width - 12)
    y: Math.max(margins, parent.height - height - (app.mediaView === "audio" && !app.panelExpanded ? 116 : 72) - 8)
    modal: false
    padding: 14
    background: Rectangle { color: "#202c38"; radius: 7 }
    contentItem: ScrollView {
        id: scroll
        implicitHeight: content.implicitHeight
        contentWidth: availableWidth
        clip: true
        ColumnLayout {
            id: content
            width: scroll.availableWidth
            spacing: 12
            RowLayout {
                Layout.fillWidth: true
                Text { text: "Background tasks"; color: "#edf3fa"; font.bold: true; Layout.fillWidth: true }
                DesktopButton { glyph: "close"; hint: "Close background tasks"; onClicked: root.close() }
            }
            ColumnLayout {
                Layout.fillWidth: true
                visible: root.app.backgroundTasks.downloading
                RowLayout {
                    Layout.fillWidth: true
                    Text { text: root.app.backgroundTasks.downloadLabel; color: "#edf3fa"; elide: Text.ElideRight; Layout.fillWidth: true }
                    Text { text: root.app.modelDownloader.isVerifying ? "" : Math.round(root.app.downloadProgressValue) + "%"; color: "#b9c8d7" }
                    DesktopButton { objectName: "cancelModelTask"; text: "Cancel"; hint: "Cancel model download or verification"; onClicked: root.app.modelDownloader.cancelOperation() }
                }
                ProgressBar {
                    objectName: "modelTaskProgress"
                    Layout.fillWidth: true
                    from: 0; to: 100
                    value: root.app.downloadProgressValue
                    indeterminate: root.app.modelDownloader.isVerifying
                    Accessible.name: root.app.backgroundTasks.downloadLabel
                }
            }
            ColumnLayout {
                Layout.fillWidth: true
                visible: root.app.backgroundTasks.transcribing
                RowLayout {
                    Layout.fillWidth: true
                    Text { text: root.app.backgroundTasks.transcriptionLabel; color: "#edf3fa"; elide: Text.ElideRight; Layout.fillWidth: true }
                    Text { text: root.app.subtitleGenerator.isCancelling ? "" : Math.round(root.app.transcriptionProgressValue) + "%"; color: "#b9c8d7" }
                    DesktopButton {
                        objectName: "cancelSubtitleGeneration"
                        text: "Cancel"
                        hint: "Cancel transcription"
                        enabled: !root.app.subtitleGenerator.isCancelling
                        onClicked: root.app.cancelSubtitleGeneration()
                    }
                }
                ProgressBar {
                    objectName: "transcriptionTaskProgress"
                    Layout.fillWidth: true
                    from: 0; to: 100
                    value: root.app.transcriptionProgressValue
                    indeterminate: root.app.subtitleGenerator.isCancelling
                    Accessible.name: root.app.backgroundTasks.transcriptionLabel
                }
            }
            Text { visible: root.app.backgroundTasks.count === 0; text: "No background tasks"; color: "#b9c8d7" }
        }
    }
}
