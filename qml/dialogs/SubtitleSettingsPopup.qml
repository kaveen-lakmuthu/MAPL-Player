import QtQuick
import QtQuick.Controls
import QtQuick.Controls.Basic as Basic
import QtQuick.Layouts
import "../components"

PlayerPopup {
    id: root
    objectName: "subtitleSettingsPopup"
    preferredWidth: 430
    padding: 18
    background: Rectangle { color: "#202c38"; radius: 7 }
    contentItem: ScrollView {
        id: scroll
        implicitHeight: settings.implicitHeight
        contentWidth: availableWidth
        clip: true
        ColumnLayout {
            id: settings
            width: scroll.availableWidth
            spacing: 12
            Label { text: "Subtitle appearance"; font.pixelSize: 16; font.bold: true }
            RowLayout {
                Layout.fillWidth: true
                Label { text: "Size"; Layout.preferredWidth: 70 }
                Basic.Slider { objectName: "subtitleFontSizeSlider"; Layout.fillWidth: true; from: 12; to: 36; stepSize: 1; value: app.subtitleFontSize; onMoved: app.subtitleFontSize = value; Accessible.name: "Subtitle font size" }
                Label { text: app.subtitleFontSize + " px"; Layout.preferredWidth: 42 }
            }
            RowLayout {
                Layout.fillWidth: true
                Label { text: "Background"; Layout.preferredWidth: 70 }
                Basic.Slider { Layout.fillWidth: true; from: 0; to: 1; stepSize: 0.05; value: app.subtitleBgOpacity; onMoved: app.subtitleBgOpacity = value; Accessible.name: "Subtitle background opacity" }
                Label { text: Math.round(app.subtitleBgOpacity * 100) + "%"; Layout.preferredWidth: 42 }
            }
            RowLayout {
                Layout.fillWidth: true
                Label { text: "Bottom gap"; Layout.preferredWidth: 70 }
                Basic.Slider {
                    objectName: "subtitleBottomGapSlider"
                    Layout.fillWidth: true
                    from: 5
                    to: 25
                    stepSize: 1
                    value: app.subtitleBottomMarginPercent
                    onMoved: app.subtitleBottomMarginPercent = value
                    Accessible.name: "Subtitle bottom gap"
                }
                Label { text: app.subtitleBottomMarginPercent + "%"; Layout.preferredWidth: 42 }
            }
            Label {
                Layout.fillWidth: true
                text: "Increase the gap to move subtitles higher. Kept above fullscreen controls."
                wrapMode: Text.Wrap
                font.pixelSize: 11
                color: "#b3c5d7"
            }
            RowLayout {
                Label { text: "Text color"; Layout.preferredWidth: 70 }
                Repeater {
                    model: ["#ffffff", "#facc15", "#4ade80", "#f87171", "#93c5fd", "#f0abfc"]
                    Basic.Button {
                        required property string modelData
                        implicitWidth: 28
                        implicitHeight: 28
                        Accessible.name: "Subtitle color " + modelData
                        background: Rectangle {
                            radius: 4
                            color: modelData
                            border.width: app.subtitleTextColor === modelData || parent.visualFocus ? 2 : 0
                            border.color: "#ffffff"
                        }
                        onClicked: app.subtitleTextColor = modelData
                    }
                }
            }
            Label { text: "Timing offset"; font.bold: true; Layout.topMargin: 8 }
            RowLayout {
                Repeater {
                    model: [-2, -0.5, 0.5, 2]
                    DesktopButton {
                        required property real modelData
                        text: (modelData > 0 ? "+" : "−") + Math.abs(modelData) + " s"
                        enabled: app.subtitleChunks.length > 0
                        onClicked: app.shiftSubtitles(modelData)
                    }
                }
            }
            Label { text: "Export"; font.bold: true; Layout.topMargin: 8 }
            RowLayout {
                Repeater {
                    model: ["SRT", "VTT", "TXT"]
                    DesktopButton {
                        required property string modelData
                        text: modelData
                        enabled: app.subtitleChunks.length > 0 || (modelData === "TXT" && app.currentLyrics !== "")
                        onClicked: {
                            app.pendingExportFormat = modelData.toLowerCase();
                            root.close();
                            app.openExportDialog();
                        }
                    }
                }
            }
            RowLayout {
                Layout.topMargin: 8
                DesktopButton { text: "Generate subtitles…"; onClicked: { root.close(); app.openSubtitleGenerator(); } }
                DesktopButton { text: "Done"; onClicked: root.close() }
            }
        }
    }
}
