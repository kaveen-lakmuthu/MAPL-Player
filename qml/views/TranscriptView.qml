import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../components"

Item {
    id: root
    required property var app
    property alias listView: transcriptListView

    anchors.fill: parent
    visible: app.currentView === "lyrics"

    // ── Local state ──────────────────────────────────
    property bool settingsOpen: false

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        // ── Top toolbar ─────────────────────────────
        Rectangle {
            id: toolbarCard
            Layout.fillWidth: true
            Layout.preferredHeight: 52
            color: "#0f172a" // Deep Slate-900
            radius: 8
            border.color: "#1e293b" // Slate-800
            border.width: 1
            visible: app.subtitleChunks.length > 0 || app.currentLyrics !== ""

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 10
                anchors.rightMargin: 10
                spacing: 8

                // Search field (only meaningful with synced subs)
                TextField {
                    id: transcriptSearchField
                    Layout.fillWidth: true
                    Layout.preferredHeight: 34
                    visible: app.subtitleChunks.length > 0
                    placeholderText: "🔍 Search transcript…"
                    color: "white"
                    font.pixelSize: 13
                    background: Rectangle {
                        color: "#020617" // extra contrast background
                        radius: 7
                        border.color: transcriptSearchField.activeFocus ? "#3b82f6" : "#334155"
                        border.width: 1
                        Behavior on border.color {
                            ColorAnimation {
                                duration: 150
                            }
                        }
                    }
                    onTextChanged: app.transcriptSearchQuery = text
                }

                // Settings toggle
                Button {
                    id: subSettingsToggleBtn
                    flat: true
                    Layout.preferredWidth: 36
                    Layout.preferredHeight: 36
                    padding: 0
                    visible: app.subtitleChunks.length > 0 || app.currentLyrics !== ""
                    background: Rectangle {
                        color: root.settingsOpen ? "#1d4ed8" : (subSettingsToggleBtn.hovered ? "#334155" : "transparent")
                        radius: 7
                        border.color: root.settingsOpen ? "#3b82f6" : "#475569"
                        border.width: 1
                        Behavior on color {
                            ColorAnimation {
                                duration: 150
                            }
                        }
                    }
                    contentItem: Text {
                        text: "⚙"
                        color: "white"
                        font.pixelSize: 18
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                    onClicked: root.settingsOpen = !root.settingsOpen
                }

                // Load file button
                Button {
                    id: loadTextFileBtnNew
                    flat: true
                    Layout.preferredWidth: 36
                    Layout.preferredHeight: 36
                    padding: 0
                    background: Rectangle {
                        color: loadTextFileBtnNew.pressed ? "#1e293b" : (loadTextFileBtnNew.hovered ? "#334155" : "transparent")
                        radius: 7
                        border.color: "#475569"
                        border.width: 1
                    }
                    contentItem: Text {
                        text: "📄"
                        color: "white"
                        font.pixelSize: 16
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                    onClicked: app.openLyricsDialog()
                }

                // Subtitle track picker button
                Button {
                    id: openPickerBtn
                    flat: true
                    Layout.preferredWidth: 36
                    Layout.preferredHeight: 36
                    padding: 0
                    visible: app.availableSubtitles.length > 0
                    background: Rectangle {
                        color: openPickerBtn.pressed ? "#1e293b" : (openPickerBtn.hovered ? "#334155" : "transparent")
                        radius: 7
                        border.color: "#475569"
                        border.width: 1
                    }
                    contentItem: Text {
                        text: "🔤"
                        color: "white"
                        font.pixelSize: 16
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                    onClicked: app.subtitlePickerVisible = !app.subtitlePickerVisible
                }

                // Clear button
                Button {
                    id: clearSubsBtnNew
                    flat: true
                    Layout.preferredWidth: 36
                    Layout.preferredHeight: 36
                    padding: 0
                    background: Rectangle {
                        color: clearSubsBtnNew.pressed ? "#991b1b" : (clearSubsBtnNew.hovered ? "#7f1d1d" : "transparent")
                        radius: 7
                        border.color: "#991b1b"
                        border.width: 1
                    }
                    contentItem: Text {
                        text: "🗑️"
                        color: "#fca5a5"
                        font.pixelSize: 16
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                    onClicked: {
                        app.subtitleChunks = [];
                        app.currentLyrics = "";
                        app.transcriptSearchQuery = "";
                    }
                }
            }
        }

        // ── Collapsible settings panel ───────────────
        Rectangle {
            id: settingsPanel
            Layout.fillWidth: true

            // Drive layout height via an animatable property so the
            // ColumnLayout reflows correctly while the panel opens/closes.
            property real targetHeight: (root.settingsOpen && (app.subtitleChunks.length > 0 || app.currentLyrics !== "")) ? (settingsPanelContent.implicitHeight + 20) : 0
            Behavior on targetHeight {
                NumberAnimation {
                    duration: 200
                    easing.type: Easing.InOutQuad
                }
            }
            Layout.preferredHeight: targetHeight
            // clip hides children while collapsed; no need to set visible: false
            clip: true
            color: "#0a111e"
            radius: 8
            border.color: targetHeight > 0 ? "#1e3a5f" : "transparent"
            border.width: 1

            ColumnLayout {
                id: settingsPanelContent
                anchors {
                    left: parent.left
                    right: parent.right
                    top: parent.top
                    margins: 10
                }
                spacing: 10

                // ── Subtitle Customizer ─────────────
                Text {
                    text: "Subtitle Appearance"
                    color: "#94a3b8"
                    font.pixelSize: 10
                    font.bold: true
                    font.letterSpacing: 1.2
                }

                // Font size
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8
                    Text {
                        text: "Size"
                        color: "#cbd5e1"
                        font.pixelSize: 11
                        Layout.preferredWidth: 36
                    }
                    Slider {
                        id: fontSizeSlider
                        Layout.fillWidth: true
                        from: 12
                        to: 36
                        value: app.subtitleFontSize
                        stepSize: 1
                        onValueChanged: app.subtitleFontSize = value
                        background: Rectangle {
                            x: fontSizeSlider.leftPadding
                            y: fontSizeSlider.topPadding + fontSizeSlider.availableHeight / 2 - height / 2
                            width: fontSizeSlider.availableWidth
                            height: 4
                            radius: 2
                            color: "#334155"
                            Rectangle {
                                width: fontSizeSlider.visualPosition * parent.width
                                height: parent.height
                                color: "#3b82f6"
                                radius: 2
                            }
                        }
                        handle: Rectangle {
                            x: fontSizeSlider.leftPadding + fontSizeSlider.visualPosition * (fontSizeSlider.availableWidth - width)
                            y: fontSizeSlider.topPadding + fontSizeSlider.availableHeight / 2 - height / 2
                            width: 14
                            height: 14
                            radius: 7
                            color: "#3b82f6"
                            border.color: "white"
                            border.width: 2
                        }
                    }
                    Text {
                        text: app.subtitleFontSize + "px"
                        color: "#60a5fa"
                        font.pixelSize: 11
                        Layout.preferredWidth: 32
                    }
                }

                // Background opacity
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8
                    Text {
                        text: "BG α"
                        color: "#cbd5e1"
                        font.pixelSize: 11
                        Layout.preferredWidth: 36
                    }
                    Slider {
                        id: bgOpacitySlider
                        Layout.fillWidth: true
                        from: 0
                        to: 1
                        value: app.subtitleBgOpacity
                        stepSize: 0.05
                        onValueChanged: app.subtitleBgOpacity = value
                        background: Rectangle {
                            x: bgOpacitySlider.leftPadding
                            y: bgOpacitySlider.topPadding + bgOpacitySlider.availableHeight / 2 - height / 2
                            width: bgOpacitySlider.availableWidth
                            height: 4
                            radius: 2
                            color: "#334155"
                            Rectangle {
                                width: bgOpacitySlider.visualPosition * parent.width
                                height: parent.height
                                color: "#3b82f6"
                                radius: 2
                            }
                        }
                        handle: Rectangle {
                            x: bgOpacitySlider.leftPadding + bgOpacitySlider.visualPosition * (bgOpacitySlider.availableWidth - width)
                            y: bgOpacitySlider.topPadding + bgOpacitySlider.availableHeight / 2 - height / 2
                            width: 14
                            height: 14
                            radius: 7
                            color: "#3b82f6"
                            border.color: "white"
                            border.width: 2
                        }
                    }
                    Text {
                        text: Math.round(app.subtitleBgOpacity * 100) + "%"
                        color: "#60a5fa"
                        font.pixelSize: 11
                        Layout.preferredWidth: 32
                    }
                }

                // Text colour row
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8
                    Text {
                        text: "Color"
                        color: "#cbd5e1"
                        font.pixelSize: 11
                        Layout.preferredWidth: 36
                    }
                    Repeater {
                        model: ["#ffffff", "#facc15", "#4ade80", "#f87171", "#93c5fd", "#f0abfc"]
                        delegate: Rectangle {
                            width: 20
                            height: 20
                            radius: 4
                            color: modelData
                            border.color: app.subtitleTextColor === modelData ? "white" : "transparent"
                            border.width: 2
                            Behavior on border.color {
                                ColorAnimation {
                                    duration: 100
                                }
                            }
                            MouseArea {
                                anchors.fill: parent
                                onClicked: app.subtitleTextColor = modelData
                            }
                        }
                    }
                }

                // ── Re-sync controls ────────────────
                Rectangle {
                    Layout.fillWidth: true
                    height: 1
                    color: "#1e3a5f"
                }

                Text {
                    text: "Timing Offset"
                    color: app.subtitleChunks.length > 0 ? "#94a3b8" : "#475569"
                    font.pixelSize: 10
                    font.bold: true
                    font.letterSpacing: 1.2
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 6
                    Repeater {
                        model: [
                            {
                                label: "−2s",
                                delta: -2.0
                            },
                            {
                                label: "−0.5s",
                                delta: -0.5
                            },
                            {
                                label: "+0.5s",
                                delta: 0.5
                            },
                            {
                                label: "+2s",
                                delta: 2.0
                            }
                        ]
                        delegate: Button {
                            flat: true
                            Layout.fillWidth: true
                            Layout.preferredHeight: 28
                            enabled: app.subtitleChunks.length > 0
                            padding: 0
                            background: Rectangle {
                                color: parent.pressed ? "#1e3a5f" : (parent.hovered ? "#1e293b" : "#0f172a")
                                radius: 6
                                border.color: "#334155"
                                border.width: 1
                            }
                            contentItem: Text {
                                text: modelData.label
                                color: app.subtitleChunks.length > 0 ? "#93c5fd" : "#475569"
                                font.pixelSize: 11
                                font.bold: true
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                            }
                            onClicked: app.shiftSubtitles(modelData.delta)
                        }
                    }
                }

                // ── Export buttons ──────────────────
                Rectangle {
                    Layout.fillWidth: true
                    height: 1
                    color: "#1e3a5f"
                }

                Text {
                    text: "Export"
                    color: "#94a3b8"
                    font.pixelSize: 10
                    font.bold: true
                    font.letterSpacing: 1.2
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 6
                    Repeater {
                        model: ["SRT", "VTT", "TXT"]
                        delegate: Button {
                            flat: true
                            Layout.fillWidth: true
                            Layout.preferredHeight: 34
                            enabled: modelData === "TXT" ? (app.subtitleChunks.length > 0 || app.currentLyrics !== "") : (app.subtitleChunks.length > 0)
                            padding: 0
                            background: Rectangle {
                                color: parent.pressed ? "#1e3a5f" : (parent.hovered ? "#1e293b" : "#0f172a")
                                radius: 6
                                border.color: "#334155"
                                border.width: 1
                            }
                            contentItem: Text {
                                text: "💾 " + modelData
                                color: (modelData === "TXT" ? (app.subtitleChunks.length > 0 || app.currentLyrics !== "") : (app.subtitleChunks.length > 0)) ? "#6ee7b7" : "#475569"
                                font.pixelSize: 11
                                font.bold: true
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                            }
                            onClicked: {
                                app.pendingExportFormat = modelData.toLowerCase();
                                app.openExportDialog();
                            }
                        }
                    }
                }

                Item {
                    height: 2
                }
            }
        }

        // ── Case A: Filtered synced subtitle list ────
        ListView {
            id: transcriptListView
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: app.subtitleChunks.length > 0
            clip: true
            model: app.filteredSubtitleChunks

            highlightRangeMode: ListView.ApplyRange
            preferredHighlightBegin: height / 3
            preferredHighlightEnd: height / 2

            // Keep the highlight tracking the active subtitle when searching
            onModelChanged: {
                if (app.transcriptSearchQuery.trim() === "") {
                    currentIndex = app.currentActiveSubtitleIndex;
                }
            }

            delegate: ItemDelegate {
                width: transcriptListView.width
                implicitHeight: delegateRowLayout.implicitHeight + 16
                padding: 8

                // When filtering, compare against originalIndex if available
                property int origIdx: modelData.originalIndex !== undefined ? modelData.originalIndex : index
                property bool isActive: origIdx === app.currentActiveSubtitleIndex

                contentItem: RowLayout {
                    id: delegateRowLayout
                    spacing: 12
                    Text {
                        text: app.formatTime(modelData.start)
                        color: isActive ? "#60a5fa" : "#64748b"
                        font.bold: true
                        font.pixelSize: isActive ? 14 : 12
                    }
                    Text {
                        text: modelData.text
                        color: isActive ? "white" : "#94a3b8"
                        font.bold: isActive
                        font.pixelSize: isActive ? 15 : 13
                        wrapMode: Text.WordWrap
                        Layout.fillWidth: true
                    }
                }
                background: Rectangle {
                    color: isActive ? Qt.rgba(59 / 255.0, 130 / 255.0, 246 / 255.0, 0.15) : (hovered ? "#334155" : "transparent")
                    radius: 8
                    border.color: isActive ? "#3b82f6" : "transparent"
                    border.width: 1
                }
                onClicked: {
                    app.seekTo(modelData.start * 1000.0);
                }
            }
        }

        // ── Case B: Scrollable plain lyrics sheet ────
        ScrollView {
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: app.subtitleChunks.length === 0 && app.currentLyrics !== ""
            clip: true

            Text {
                width: parent.width
                text: app.currentLyrics
                color: app.subtitleTextColor
                font.pixelSize: app.subtitleFontSize
                lineHeight: 1.5
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
            }
        }

        // ── Case C: Unloaded state (Generator Interface) ──
        SubtitleGeneratorPanel {
            app: root.app
        }
    }
}
