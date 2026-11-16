import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../components"

PlayerPopup {
    id: root
    objectName: "recentFilesMenu"
    preferredWidth: 480
    height: Math.min(contentColumn.implicitHeight + padding * 2, parent.height - margins * 2)
    padding: 20
    background: Rectangle {
        color: "#0f172a"
        radius: 12
        border.color: "#334155"
    }
    contentItem: ColumnLayout {
        id: contentColumn
        spacing: 12
        RowLayout {
            spacing: 8
            Layout.fillWidth: true
            Label {
                text: "Recent files"
                color: "white"
                font.pixelSize: 18
                font.bold: true
                Layout.fillWidth: true
            }
            DesktopButton {
                objectName: "closeRecentFilesButton"
                text: "Close"
                onClicked: root.close()
            }
        }
        Label {
            visible: app.playbackHistory.recentFiles.length === 0
            text: "No recent files yet."
            color: "#94a3b8"
            Layout.fillWidth: true
            Layout.preferredHeight: 50
        }
        ListView {
            id: files
            objectName: "recentFilesList"
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.preferredHeight: Math.min(contentHeight, 420)
            clip: true
            model: app.playbackHistory.recentFiles
            ScrollBar.vertical: ScrollBar {}
            delegate: ItemDelegate {
                id: entry
                required property var modelData
                width: files.width
                height: 64
                horizontalPadding: 12
                verticalPadding: 10
                enabled: modelData.available
                objectName: "recentFileEntry"
                background: Rectangle {
                    color: entry.hovered ? "#1e293b" : "transparent"
                    radius: 6
                }
                contentItem: ColumnLayout {
                    spacing: 4
                    Label {
                        textFormat: Text.PlainText
                        text: entry.modelData.title + (entry.modelData.available ? "" : " (unavailable)")
                        color: entry.enabled ? "#e2e8f0" : "#64748b"
                        elide: Text.ElideMiddle
                        Layout.fillWidth: true
                    }
                    Label {
                        textFormat: Text.PlainText
                        text: entry.modelData.path
                        color: "#94a3b8"
                        font.pixelSize: 11
                        elide: Text.ElideMiddle
                        Layout.fillWidth: true
                    }
                }
                ToolTip.visible: hovered
                ToolTip.text: modelData.path
                onClicked: {
                    var url = modelData.url;
                    root.close();
                    app.openRecentFile(url);
                }
            }
        }
        DesktopButton {
            objectName: "clearRecentFilesButton"
            text: "Clear recent files"
            enabled: app.playbackHistory.recentFiles.length > 0
            Layout.alignment: Qt.AlignRight
            onClicked: app.playbackHistory.clearRecentFiles()
        }
    }
}
