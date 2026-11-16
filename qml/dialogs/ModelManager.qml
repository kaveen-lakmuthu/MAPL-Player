import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../components"

PlayerPopup {
    id: root
    objectName: "modelManager"
    preferredWidth: 540
    height: Math.min(460, parent.height - margins * 2)
    padding: 20
    function sizeLabel(bytes) {
        return (bytes / 1000000).toFixed(1) + " MB";
    }
    background: Rectangle {
        color: "#0f172a"
        border.color: "#334155"
        radius: 12
    }
    contentItem: ColumnLayout {
        spacing: 14
        RowLayout {
            spacing: 8
            Layout.fillWidth: true
            Label {
                text: "Whisper models"
                color: "white"
                font.pixelSize: 18
                font.bold: true
                Layout.fillWidth: true
            }
            DesktopButton {
                text: "Close"
                onClicked: root.close()
            }
        }
        Label {
            text: "Download a model once for offline subtitle generation."
            color: "#94a3b8"
            wrapMode: Text.Wrap
            Layout.fillWidth: true
        }
        ListView {
            id: modelList
            objectName: "modelList"
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            spacing: 12
            model: app.modelDownloader.models
            ScrollBar.vertical: ScrollBar {}
            delegate: Rectangle {
                id: row
                required property var modelData
                width: modelList.width
                height: rowContent.implicitHeight + 24
                color: "#1e293b"
                radius: 8
                ColumnLayout {
                    id: rowContent
                    anchors.fill: parent
                    anchors.margins: 12
                    spacing: 8
                    RowLayout {
                        spacing: 8
                        Layout.fillWidth: true
                        Label {
                            text: row.modelData.title + " · " + root.sizeLabel(row.modelData.expectedBytes)
                            color: "white"
                            font.bold: true
                            Layout.fillWidth: true
                        }
                        Label {
                            text: row.modelData.status + (row.modelData.inUse ? " · In use" : "")
                            color: row.modelData.verified ? "#4ade80" : "#cbd5e1"
                        }
                    }
                    Label {
                        visible: row.modelData.present
                        text: "On disk: " + root.sizeLabel(row.modelData.installedBytes)
                        color: "#94a3b8"
                    }
                    Label {
                        visible: row.modelData.error !== ""
                        text: row.modelData.error
                        color: "#fca5a5"
                        wrapMode: Text.Wrap
                        Layout.fillWidth: true
                    }
                    ProgressBar {
                        Layout.fillWidth: true
                        visible: app.modelDownloader.isBusy && (app.modelDownloader.activeModel === row.modelData.name || row.modelData.status === "Verifying")
                        indeterminate: app.modelDownloader.isVerifying
                        from: 0
                        to: 100
                        value: app.modelDownloader.progress
                    }
                    RowLayout {
                        spacing: 8
                        DesktopButton {
                            objectName: "downloadModel_" + row.modelData.name
                            text: row.modelData.present ? "Download again" : "Download"
                            enabled: !app.modelDownloader.isBusy && !row.modelData.inUse
                            onClicked: app.modelDownloader.startDownload(row.modelData.name)
                        }
                        DesktopButton {
                            objectName: "deleteModel_" + row.modelData.name
                            text: "Delete"
                            visible: row.modelData.present
                            enabled: !app.modelDownloader.isBusy && !row.modelData.inUse
                            onClicked: app.modelDownloader.deleteModel(row.modelData.name)
                        }
                        DesktopButton {
                            objectName: "cancelModel_" + row.modelData.name
                            text: "Cancel"
                            visible: app.modelDownloader.isBusy && app.modelDownloader.activeModel === row.modelData.name
                            onClicked: app.modelDownloader.cancelOperation()
                        }
                    }
                }
            }
        }
        Label {
            text: "Closing this window keeps downloads running. Use Cancel to stop them."
            color: "#94a3b8"
            font.pixelSize: 11
            wrapMode: Text.Wrap
            Layout.fillWidth: true
        }
    }
}
