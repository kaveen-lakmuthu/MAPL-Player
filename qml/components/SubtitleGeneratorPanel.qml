import QtQuick
import QtQuick.Controls
import QtQuick.Controls.Basic as Basic
import QtQuick.Layouts

Item {
    id: root
    required property var app

    Layout.fillWidth: true
    Layout.fillHeight: true
    visible: app.subtitleChunks.length === 0 && app.currentLyrics === ""

    ColumnLayout {
        anchors.centerIn: parent
        spacing: 20
        width: parent.width * 0.9

        Text {
            text: "No Lyrics or Subtitles loaded."
            color: "#94a3b8"
            font.pixelSize: 14
            font.bold: true
            Layout.alignment: Qt.AlignHCenter
        }

        Button {
            id: loadLyricsPromptBtn
            flat: true
            Layout.preferredHeight: 36
            Layout.alignment: Qt.AlignHCenter
            scale: loadLyricsPromptBtn.hovered ? 1.03 : 1.0
            Behavior on scale {
                NumberAnimation {
                    duration: 100
                }
            }
            padding: 0
            background: Rectangle {
                color: loadLyricsPromptBtn.pressed ? "#0f172a" : (loadLyricsPromptBtn.hovered ? "#334155" : "#1e293b")
                radius: 8
                border.color: "#475569"
                border.width: 1
            }
            contentItem: Text {
                text: "📂 Load Lyrics or Subtitles (.txt, .srt)"
                color: "white"
                font.bold: true
                font.pixelSize: 13
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                leftPadding: 16
                rightPadding: 16
            }
            onClicked: app.openLyricsDialog()
        }

        Rectangle {
            Layout.fillWidth: true
            height: 1
            color: "#334155"
        }

        Text {
            text: "Local Speech-to-Text Generator"
            color: "white"
            font.pixelSize: 14
            font.bold: true
            Layout.alignment: Qt.AlignHCenter
        }

        // High Contrast Custom Grids for Inputs
        GridLayout {
            columns: 2
            rowSpacing: 12
            columnSpacing: 18
            Layout.alignment: Qt.AlignHCenter

            Text {
                text: "Whisper Model:"
                color: "#cbd5e0"
                font.pixelSize: 12
            }
            // These custom text items use Basic's replaceable content item;
            // the KDE desktop ComboBox expects its own editable text field.
            Basic.ComboBox {
                id: modelSelector
                Layout.preferredWidth: 160
                Layout.preferredHeight: 30
                model: ["Tiny (Fast, 77.7 MB)", "Base (Accurate, 148 MB)"]
                currentIndex: app.subtitleModel === "tiny" ? 0 : 1
                onActivated: app.subtitleModel = currentIndex === 0 ? "tiny" : "base"
                padding: 0

                contentItem: Text {
                    text: modelSelector.displayText
                    color: "white"
                    font.pixelSize: 12
                    verticalAlignment: Text.AlignVCenter
                    leftPadding: 8
                    rightPadding: 8
                    elide: Text.ElideRight
                }
                background: Rectangle {
                    color: "#1e293b"
                    radius: 6
                    border.color: "#475569"
                    border.width: 1
                }
                delegate: ItemDelegate {
                    width: modelSelector.width
                    padding: 0
                    contentItem: Text {
                        text: modelData
                        color: hovered ? "white" : "#cbd5e0"
                        font.pixelSize: 12
                        verticalAlignment: Text.AlignVCenter
                        leftPadding: 8
                        rightPadding: 8
                    }
                    background: Rectangle {
                        color: hovered ? "#2563eb" : "#1e293b"
                    }
                }
                popup: Popup {
                    y: modelSelector.height
                    width: modelSelector.width
                    implicitHeight: contentItem.implicitHeight + 2
                    padding: 1
                    contentItem: ListView {
                        clip: true
                        implicitHeight: contentHeight
                        model: modelSelector.popup.visible ? modelSelector.delegateModel : null
                        currentIndex: modelSelector.highlightedIndex
                        ScrollIndicator.vertical: ScrollIndicator {}
                    }
                    background: Rectangle {
                        color: "#1e293b"
                        border.color: "#475569"
                        border.width: 1
                        radius: 6
                    }
                }
            }

            Text {
                text: "Transcription Mode:"
                color: "#cbd5e0"
                font.pixelSize: 12
            }
            Basic.ComboBox {
                id: taskSelector
                Layout.preferredWidth: 160
                Layout.preferredHeight: 30
                model: ["Transcribe (Original)", "Translate to English"]
                currentIndex: app.translateSubtitles ? 1 : 0
                onActivated: app.translateSubtitles = currentIndex === 1
                padding: 0

                contentItem: Text {
                    text: taskSelector.displayText
                    color: "white"
                    font.pixelSize: 12
                    verticalAlignment: Text.AlignVCenter
                    leftPadding: 8
                    rightPadding: 8
                    elide: Text.ElideRight
                }
                background: Rectangle {
                    color: "#1e293b"
                    radius: 6
                    border.color: "#475569"
                    border.width: 1
                }
                delegate: ItemDelegate {
                    width: taskSelector.width
                    padding: 0
                    contentItem: Text {
                        text: modelData
                        color: hovered ? "white" : "#cbd5e0"
                        font.pixelSize: 12
                        verticalAlignment: Text.AlignVCenter
                        leftPadding: 8
                        rightPadding: 8
                    }
                    background: Rectangle {
                        color: hovered ? "#2563eb" : "#1e293b"
                    }
                }
                popup: Popup {
                    y: taskSelector.height
                    width: taskSelector.width
                    implicitHeight: contentItem.implicitHeight + 2
                    padding: 1
                    contentItem: ListView {
                        clip: true
                        implicitHeight: contentHeight
                        model: taskSelector.popup.visible ? taskSelector.delegateModel : null
                        currentIndex: taskSelector.highlightedIndex
                        ScrollIndicator.vertical: ScrollIndicator {}
                    }
                    background: Rectangle {
                        color: "#1e293b"
                        border.color: "#475569"
                        border.width: 1
                        radius: 6
                    }
                }
            }

            Text {
                text: "Audio Language:"
                color: "#cbd5e0"
                font.pixelSize: 12
            }
            Basic.ComboBox {
                id: languageSelector
                Layout.preferredWidth: 160
                Layout.preferredHeight: 30
                model: ["Auto-Detect", "English", "Spanish", "French", "German", "Japanese", "Chinese", "Korean", "Russian", "Portuguese", "Italian"]
                currentIndex: Math.max(0, model.indexOf(app.subtitleLanguage))
                onActivated: app.subtitleLanguage = currentText
                enabled: taskSelector.currentIndex === 0
                padding: 0

                contentItem: Text {
                    text: languageSelector.displayText
                    color: "white"
                    font.pixelSize: 12
                    verticalAlignment: Text.AlignVCenter
                    leftPadding: 8
                    rightPadding: 8
                    elide: Text.ElideRight
                }
                background: Rectangle {
                    color: "#1e293b"
                    radius: 6
                    border.color: "#475569"
                    border.width: 1
                }
                delegate: ItemDelegate {
                    width: languageSelector.width
                    padding: 0
                    contentItem: Text {
                        text: modelData
                        color: hovered ? "white" : "#cbd5e0"
                        font.pixelSize: 12
                        verticalAlignment: Text.AlignVCenter
                        leftPadding: 8
                        rightPadding: 8
                    }
                    background: Rectangle {
                        color: hovered ? "#2563eb" : "#1e293b"
                    }
                }
                popup: Popup {
                    y: languageSelector.height
                    width: languageSelector.width
                    implicitHeight: contentItem.implicitHeight + 2
                    padding: 1
                    contentItem: ListView {
                        clip: true
                        implicitHeight: contentHeight
                        model: languageSelector.popup.visible ? languageSelector.delegateModel : null
                        currentIndex: languageSelector.highlightedIndex
                        ScrollIndicator.vertical: ScrollIndicator {}
                    }
                    background: Rectangle {
                        color: "#1e293b"
                        border.color: "#475569"
                        border.width: 1
                        radius: 6
                    }
                }
            }
        }

        Button {
            id: startSubsGenBtn
            flat: true
            Layout.preferredHeight: 38
            Layout.alignment: Qt.AlignHCenter
            enabled: app.currentTrackIndex !== -1 && !app.modelDownloader.isBusy && !app.subtitleGenerator.isProcessing
            scale: startSubsGenBtn.enabled && startSubsGenBtn.hovered ? 1.03 : 1.0
            Behavior on scale {
                NumberAnimation {
                    duration: 100
                }
            }
            padding: 0
            background: Rectangle {
                color: startSubsGenBtn.enabled ? (startSubsGenBtn.pressed ? "#15803d" : (startSubsGenBtn.hovered ? "#22c55e" : "#16a34a")) : "#334155"
                radius: 8
                border.color: startSubsGenBtn.enabled && startSubsGenBtn.hovered ? "#4ade80" : "transparent"
                border.width: 1
            }
            contentItem: Text {
                text: "✨ Generate Synced Lyrics & Subs"
                color: startSubsGenBtn.enabled ? "white" : "#94a3b8"
                font.bold: true
                font.pixelSize: 13
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                leftPadding: 18
                rightPadding: 18
            }
            onClicked: app.generateSubtitlesForCurrentTrack()
        }

        // Downloader progress layout (Custom ProgressBar)
        ColumnLayout {
            Layout.fillWidth: true
            visible: app.modelDownloader.isDownloading
            spacing: 8
            Text {
                text: "Downloading Whisper model weights (first-run only)..."
                color: "white"
                font.pixelSize: 12
            }
            ProgressBar {
                id: downloadProgressBar
                value: app.downloadProgressValue
                Layout.fillWidth: true
                from: 0
                to: 100
                background: Rectangle {
                    implicitHeight: 6
                    color: "#334155"
                    radius: 3
                }
                contentItem: Item {
                    implicitHeight: 6
                    Rectangle {
                        width: downloadProgressBar.visualPosition * parent.width
                        height: parent.height
                        color: "#3b82f6"
                        radius: 3
                    }
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            visible: app.modelDownloader.isBusy
            Text {
                text: app.modelDownloader.isVerifying ? "Verifying model checksum…" : "Downloading " + app.modelDownloader.activeModel + "…"
                color: "#cbd5e1"
                Layout.fillWidth: true
                font.pixelSize: 12
            }
            Button {
                text: "Cancel"
                onClicked: app.modelDownloader.cancelOperation()
            }
        }

        // Transcription progress layout (Custom ProgressBar)
        ColumnLayout {
            Layout.fillWidth: true
            visible: app.subtitleGenerator.isProcessing
            spacing: 8
            Text {
                text: app.subtitleGenerator.isCancelling ? "Cancelling transcription…" : "Transcribing audio locally..."
                color: "white"
                font.pixelSize: 12
            }
            ProgressBar {
                id: transcriptionProgress
                value: app.transcriptionProgressValue
                Layout.fillWidth: true
                from: 0
                to: 100
                background: Rectangle {
                    implicitHeight: 6
                    color: "#334155"
                    radius: 3
                }
                contentItem: Item {
                    implicitHeight: 6
                    Rectangle {
                        width: transcriptionProgress.visualPosition * parent.width
                        height: parent.height
                        color: "#22c55e"
                        radius: 3
                    }
                }
            }
        }
    }
}
