import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../components"

Item {
    id: root
    required property var app
    property alias listView: transcriptListView
    anchors.fill: parent
    visible: app.panelView === "lyrics"

    ColumnLayout {
        anchors.fill: parent
        spacing: 8
        RowLayout {
            Layout.fillWidth: true
            spacing: 8
            TextField {
                id: search
                objectName: "transcriptSearchField"
                Layout.fillWidth: true
                Layout.preferredHeight: 30
                leftPadding: 12
                rightPadding: 12
                placeholderText: "Search transcript…"
                enabled: app.subtitleChunks.length > 0
                text: app.transcriptSearchQuery
                onTextEdited: app.transcriptSearchQuery = text
                color: "#edf3fa"
                background: Rectangle {
                    color: "#15212c"
                    radius: 4
                    border.width: search.activeFocus ? 1 : 0
                    border.color: "#9dcbff"
                }
            }
            DesktopButton { glyph: "settings"; hint: "Subtitle appearance, timing and export"; onClicked: app.openSubtitleSettings() }
            DesktopButton { glyph: "file"; hint: "Load lyrics or subtitles"; onClicked: app.openLyricsDialog() }
        }
        RowLayout {
            visible: app.subtitleChunks.length > 0 || app.currentLyrics !== ""
            Layout.fillWidth: true
            Text {
                Layout.fillWidth: true
                text: app.subtitleChunks.length > 0 ? app.filteredSubtitleChunks.length + " lines · click a line to seek" : "Plain lyrics"
                color: "#acbdcf"
                font.pixelSize: 11
                elide: Text.ElideRight
            }
            DesktopButton { glyph: "captions"; visible: app.availableSubtitles.length > 0; hint: "Choose subtitle track"; onClicked: app.subtitlePickerVisible = true }
            DesktopButton { glyph: "trash"; hint: "Clear lyrics and subtitles"; onClicked: app.clearSubtitles() }
        }
        ListView {
            id: transcriptListView
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: app.subtitleChunks.length > 0
            clip: true
            model: app.filteredSubtitleChunks
            ScrollBar.vertical: ScrollBar {}
            highlightRangeMode: ListView.ApplyRange
            preferredHighlightBegin: height / 3
            preferredHighlightEnd: height / 2
            onModelChanged: {
                if (app.transcriptSearchQuery.trim() === "")
                    currentIndex = app.currentActiveSubtitleIndex;
            }
            delegate: ItemDelegate {
                id: lineDelegate
                width: transcriptListView.width
                implicitHeight: row.implicitHeight + 16
                padding: 8
                horizontalPadding: 12
                property int originalIndex: modelData.originalIndex !== undefined ? modelData.originalIndex : index
                property bool isActive: originalIndex === app.currentActiveSubtitleIndex
                contentItem: RowLayout {
                    id: row
                    spacing: 10
                    Text { text: app.formatTime(modelData.start); color: lineDelegate.isActive ? "#9dcbff" : "#acbdcf"; font.pixelSize: 11; Layout.alignment: Qt.AlignTop }
                    Text { text: modelData.text; color: lineDelegate.isActive ? "#ffffff" : "#c1cedb"; font.pixelSize: 13; font.bold: lineDelegate.isActive; wrapMode: Text.WordWrap; Layout.fillWidth: true }
                }
                background: Rectangle { radius: 4; color: lineDelegate.isActive ? "#30485e" : lineDelegate.hovered ? "#2b3c4d" : "transparent" }
                onClicked: app.seekTo(modelData.start * 1000)
            }
        }
        ScrollView {
            id: plainLyrics
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: app.subtitleChunks.length === 0 && app.currentLyrics !== ""
            contentWidth: availableWidth
            clip: true
            Text {
                width: plainLyrics.availableWidth
                text: app.currentLyrics
                color: app.subtitleTextColor
                font.pixelSize: app.subtitleFontSize
                lineHeight: 1.4
                wrapMode: Text.WordWrap
            }
        }
        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: app.subtitleChunks.length === 0 && app.currentLyrics === ""
            spacing: 10
            Item { Layout.fillHeight: true }
            Text { Layout.fillWidth: true; text: "Lyrics and subtitles"; color: "#edf3fa"; font.pixelSize: 15; font.bold: true }
            Text { Layout.fillWidth: true; text: "Load a text or subtitle file, or generate timed lines locally with Whisper."; color: "#acbdcf"; font.pixelSize: 12; wrapMode: Text.WordWrap }
            DesktopButton { text: "Load lyrics or subtitles…"; onClicked: app.openLyricsDialog() }
            DesktopButton { text: "Generate with Whisper…"; onClicked: app.openSubtitleGenerator() }
            DesktopButton { text: "Manage Whisper models…"; onClicked: app.openModelManager() }
            Item { Layout.fillHeight: true }
        }
    }
}
