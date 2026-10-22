import QtQuick
import QtQuick.Window
import QtQuick.Controls
import QtQuick.Layouts

Rectangle {
    id: root
    required property var app

    Layout.fillHeight: true
    Layout.preferredWidth: (app.visibility !== Window.FullScreen && app.sidebarExpanded) ? 155 : 0
    width: Layout.preferredWidth
    clip: true
    color: "#0f172a" // Deep Slate-900
    visible: app.visibility !== Window.FullScreen

    Behavior on Layout.preferredWidth {
        NumberAnimation {
            duration: 220
            easing.type: Easing.OutQuart
        }
    }

    // Decorative separator border
    Rectangle {
        anchors.right: parent.right
        width: 1
        height: parent.height
        color: "#1e293b" // Slate-800
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 14
        spacing: 14
        opacity: Math.max(0.0, Math.min(1.0, (root.width - 80) / 75))
        visible: root.width > 80

        // Logo/Header Space with collapse button
        Item {
            Layout.preferredHeight: 50
            Layout.fillWidth: true
            RowLayout {
                anchors.fill: parent
                spacing: 6

                Text {
                    text: "MAPL"
                    color: "white"
                    font.bold: true
                    font.pixelSize: 18
                    font.letterSpacing: 1.5
                    Layout.fillWidth: true
                }

                // Collapse button — lives inside the panel
                Button {
                    id: collapseSidebarBtn
                    implicitWidth: 28
                    implicitHeight: 28
                    flat: true
                    padding: 0
                    Layout.alignment: Qt.AlignVCenter

                    background: Rectangle {
                        color: collapseSidebarBtn.hovered ? "#1e293b" : "transparent"
                        radius: 6
                        border.color: collapseSidebarBtn.hovered ? "#334155" : "transparent"
                        border.width: 1
                    }

                    contentItem: Text {
                        text: "☰"
                        color: collapseSidebarBtn.hovered ? "white" : "#64748b"
                        font.pixelSize: 15
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }

                    onClicked: app.sidebarExpanded = false
                }
            }
        }

        // Open Files Button (Modern flat look matching Electron)
        Button {
            id: openFilesBtn
            Layout.fillWidth: true
            Layout.preferredHeight: 38
            flat: true
            padding: 0
            scale: openFilesBtn.hovered ? 1.03 : 1.0
            Behavior on scale {
                NumberAnimation {
                    duration: 100
                }
            }
            background: Rectangle {
                color: openFilesBtn.pressed ? "#3b82f6" : (openFilesBtn.hovered ? "#63b3ed" : "#4a5568")
                radius: 12
            }
            contentItem: Text {
                text: "📂 Open Files"
                color: "white"
                font.pixelSize: 13
                font.bold: true
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                elide: Text.ElideRight
            }
            onClicked: app.sidebarOpen = !app.sidebarOpen
        }

        Button {
            objectName: "recentFilesButton"
            Layout.fillWidth: true
            Layout.preferredHeight: 34
            text: "Recent files"
            flat: true
            onClicked: app.openRecentFiles()
        }

        Button {
            objectName: "modelsButton"
            Layout.fillWidth: true
            Layout.preferredHeight: 34
            text: app.modelDownloader.isBusy ? (app.modelDownloader.isDownloading ? "Models · " + Math.round(app.modelDownloader.progress) + "%" : "Models · checking…") : "Whisper models"
            flat: true
            onClicked: app.openModelManager()
        }

        Rectangle {
            Layout.fillWidth: true
            height: 1
            color: "#1e293b"
        }

        Button {
            id: audioTabBtn
            Layout.fillWidth: true
            Layout.preferredHeight: 38
            flat: true
            padding: 0
            scale: audioTabBtn.hovered ? 1.02 : 1.0
            Behavior on scale {
                NumberAnimation {
                    duration: 100
                }
            }
            background: Rectangle {
                color: app.currentView === "audio" ? "#1d4ed8" : (audioTabBtn.hovered ? "#4a5568" : "transparent")
                radius: 12
            }
            contentItem: Text {
                text: "🎵 Audio View"
                color: app.currentView === "audio" ? "white" : (audioTabBtn.hovered ? "white" : "#d1d5db")
                font.bold: app.currentView === "audio"
                font.pixelSize: 13
                horizontalAlignment: Text.AlignLeft
                leftPadding: 12
                verticalAlignment: Text.AlignVCenter
                elide: Text.ElideRight
            }
            onClicked: app.currentView = "audio"
        }

        Button {
            id: videoTabBtn
            Layout.fillWidth: true
            Layout.preferredHeight: 38
            flat: true
            enabled: app.currentTrackIndex !== -1
            padding: 0
            scale: videoTabBtn.hovered && videoTabBtn.enabled ? 1.02 : 1.0
            Behavior on scale {
                NumberAnimation {
                    duration: 100
                }
            }
            background: Rectangle {
                color: app.currentView === "video" ? "#1d4ed8" : (videoTabBtn.hovered ? "#4a5568" : "transparent")
                radius: 12
                opacity: videoTabBtn.enabled ? 1.0 : 0.4
            }
            contentItem: Text {
                text: "📺 Video View"
                color: app.currentView === "video" ? "white" : (videoTabBtn.hovered ? "white" : "#d1d5db")
                font.bold: app.currentView === "video"
                font.pixelSize: 13
                horizontalAlignment: Text.AlignLeft
                leftPadding: 12
                verticalAlignment: Text.AlignVCenter
                elide: Text.ElideRight
            }
            onClicked: app.currentView = "video"
        }

        // View Tabs (Flat Sidebar Buttons matching Electron)
        Button {
            id: lyricsTabBtn
            Layout.fillWidth: true
            Layout.preferredHeight: 38
            flat: true
            padding: 0
            scale: lyricsTabBtn.hovered ? 1.02 : 1.0
            Behavior on scale {
                NumberAnimation {
                    duration: 100
                }
            }
            background: Rectangle {
                color: app.currentView === "lyrics" ? "#1d4ed8" : (lyricsTabBtn.hovered ? "#4a5568" : "transparent")
                radius: 12
            }
            contentItem: Text {
                text: "📝 Lyrics & Subs"
                color: app.currentView === "lyrics" ? "white" : (lyricsTabBtn.hovered ? "white" : "#d1d5db")
                font.bold: app.currentView === "lyrics"
                font.pixelSize: 13
                horizontalAlignment: Text.AlignLeft
                leftPadding: 12
                verticalAlignment: Text.AlignVCenter
                elide: Text.ElideRight
            }
            onClicked: app.currentView = "lyrics"
        }

        Button {
            id: playlistTabBtn
            Layout.fillWidth: true
            Layout.preferredHeight: 38
            flat: true
            padding: 0
            scale: playlistTabBtn.hovered ? 1.02 : 1.0
            Behavior on scale {
                NumberAnimation {
                    duration: 100
                }
            }
            background: Rectangle {
                color: app.currentView === "playlist" ? "#1d4ed8" : (playlistTabBtn.hovered ? "#4a5568" : "transparent")
                radius: 12
            }
            contentItem: Text {
                text: "📋 Playlist"
                color: app.currentView === "playlist" ? "white" : (playlistTabBtn.hovered ? "white" : "#d1d5db")
                font.bold: app.currentView === "playlist"
                font.pixelSize: 13
                horizontalAlignment: Text.AlignLeft
                leftPadding: 12
                verticalAlignment: Text.AlignVCenter
                elide: Text.ElideRight
            }
            onClicked: app.currentView = "playlist"
        }

        Button {
            id: captureTabBtn
            Layout.fillWidth: true
            Layout.preferredHeight: 38
            flat: true
            padding: 0
            visible: app.currentView === "video"
            scale: captureTabBtn.hovered ? 1.02 : 1.0
            Behavior on scale {
                NumberAnimation {
                    duration: 100
                }
            }
            background: Rectangle {
                color: captureTabBtn.hovered ? "#4a5568" : "transparent"
                radius: 12
            }
            contentItem: Text {
                text: "📷 Capture Cover"
                color: captureTabBtn.hovered ? "white" : "#d1d5db"
                font.pixelSize: 13
                horizontalAlignment: Text.AlignLeft
                leftPadding: 12
                verticalAlignment: Text.AlignVCenter
                elide: Text.ElideRight
            }
            onClicked: {
                if (app.currentTrackIndex !== -1) {
                    app.playerController.captureThumbnail(app.playlist[app.currentTrackIndex].url);
                    app.showMessage("Thumbnail frame captured!");
                }
            }
        }

        Item {
            Layout.fillHeight: true
        } // Spacer

        // About Button (matches panel view layout)
        Button {
            id: aboutTabBtn
            Layout.fillWidth: true
            Layout.preferredHeight: 36
            flat: true
            padding: 0
            background: Rectangle {
                color: aboutTabBtn.hovered ? "#4a5568" : "transparent"
                radius: 12
            }
            contentItem: Text {
                text: "ℹ️ About Application"
                color: aboutTabBtn.hovered ? "white" : "#d1d5db"
                font.pixelSize: 12
                horizontalAlignment: Text.AlignLeft
                leftPadding: 12
                verticalAlignment: Text.AlignVCenter
                elide: Text.ElideRight
            }
            onClicked: app.openAboutDialog()
        }
    }
}
