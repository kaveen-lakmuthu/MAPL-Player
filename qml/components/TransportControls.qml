import QtQuick
import QtQuick.Window
import QtQuick.Controls
import QtQuick.Layouts

Item {
    id: root
    required property var app
    property alias volumeSlider: volumeControl.slider

    width: parent.width
    height: 48

    property bool isNarrow: width < 660
    property bool rightControlsAtBottom: true

    Component.onCompleted: {
        console.log("root init width:", width);
    }
    onWidthChanged: {
        console.log("root width changed:", width);
    }

    // Playback Control Buttons (Centered)
    TransportButtons {
        id: playbackControlsLayout
        app: root.app
        narrow: root.isNarrow
    }

    // Right controls layout (always anchored to the right of root)
    RowLayout {
        id: rightControlsLayout
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        width: implicitWidth
        height: parent.height
        spacing: root.isNarrow ? 8 : 12
        z: 1

        opacity: (app.visibility === Window.FullScreen) ? (app.controlsVisible ? 1.0 : 0.0) : 1.0
        Behavior on opacity {
            NumberAnimation {
                duration: 300
            }
        }
        visible: opacity > 0.0

        // Loop Toggle (Flat circle with Canvas vector icon)
        Button {
            id: loopToggleBtn
            flat: true
            implicitWidth: 44
            implicitHeight: 44
            padding: 0
            leftPadding: 0
            rightPadding: 0
            topPadding: 0
            bottomPadding: 0
            readonly property bool looping: app.loopPlaylist
            property color iconColor: looping ? "#60a5fa" : (loopToggleBtn.hovered ? "#60a5fa" : "#94a3b8")

            background: Rectangle {
                color: loopToggleBtn.pressed ? Qt.rgba(255, 255, 255, 0.1) : (loopToggleBtn.hovered ? Qt.rgba(255, 255, 255, 0.05) : "transparent")
                radius: 18
            }

            contentItem: Canvas {
                id: loopIconCanvas
                onWidthChanged: requestPaint()
                onHeightChanged: requestPaint()
                onPaint: {
                    var ctx = getContext("2d");
                    ctx.reset();
                    ctx.strokeStyle = loopToggleBtn.iconColor;
                    ctx.lineWidth = 2.2;
                    ctx.lineCap = "round";
                    ctx.lineJoin = "round";

                    var w = width;
                    var h = height;
                    var cx = w / 2;
                    var cy = h / 2;

                    // Path 1 (top half, left arrow)
                    ctx.beginPath();
                    ctx.moveTo(cx + 7, cy - 5);
                    ctx.lineTo(cx - 4, cy - 5);
                    ctx.arcTo(cx - 9, cy - 5, cx - 9, cy, 5);
                    ctx.lineTo(cx - 9, cy + 3);
                    ctx.stroke();

                    // Arrow head (pointing left)
                    ctx.beginPath();
                    ctx.moveTo(cx - 1, cy - 9);
                    ctx.lineTo(cx - 4, cy - 5);
                    ctx.lineTo(cx - 1, cy - 1);
                    ctx.stroke();

                    // Path 2 (bottom half, right arrow)
                    ctx.beginPath();
                    ctx.moveTo(cx - 7, cy + 5);
                    ctx.lineTo(cx + 4, cy + 5);
                    ctx.arcTo(cx + 9, cy + 5, cx + 9, cy, 5);
                    ctx.lineTo(cx + 9, cy - 3);
                    ctx.stroke();

                    // Arrow head (pointing right)
                    ctx.beginPath();
                    ctx.moveTo(cx + 1, cy + 1);
                    ctx.lineTo(cx + 4, cy + 5);
                    ctx.lineTo(cx + 1, cy + 9);
                    ctx.stroke();
                }

                Connections {
                    target: loopToggleBtn
                    function onLoopingChanged() {
                        loopIconCanvas.requestPaint();
                    }
                    function onHoveredChanged() {
                        loopIconCanvas.requestPaint();
                    }
                    function onIconColorChanged() {
                        loopIconCanvas.requestPaint();
                    }
                }
            }

            onClicked: {
                app.loopPlaylist = !looping;
                app.playerController.saveLoop(app.loopPlaylist);
                app.showMessage("Playlist looping: " + (looping ? "On" : "Off"));
            }
        }

        // CC Subtitle Track Picker Button
        Button {
            id: subPickerControlsBtn
            flat: true
            implicitWidth: 44
            implicitHeight: 44
            padding: 0
            leftPadding: 0
            rightPadding: 0
            topPadding: 0
            bottomPadding: 0
            visible: app.availableSubtitles.length > 0

            background: Rectangle {
                color: subPickerControlsBtn.pressed ? Qt.rgba(255, 255, 255, 0.1) : (subPickerControlsBtn.hovered ? Qt.rgba(255, 255, 255, 0.05) : "transparent")
                radius: 18
            }

            contentItem: Item {
                anchors.fill: parent

                Rectangle {
                    anchors.centerIn: parent
                    width: 22
                    height: 16
                    radius: 3
                    color: "transparent"
                    border.color: subPickerControlsBtn.hovered ? "#60a5fa" : "#94a3b8"
                    border.width: 1.8

                    Text {
                        anchors.centerIn: parent
                        text: "CC"
                        color: subPickerControlsBtn.hovered ? "#60a5fa" : "#94a3b8"
                        font.pixelSize: 9
                        font.bold: true
                        font.letterSpacing: 0.5
                    }
                }
            }

            onClicked: {
                app.subtitlePickerVisible = !app.subtitlePickerVisible;
            }
        }

        // Chapters List Picker Button
        Button {
            id: chaptersControlsBtn
            flat: true
            implicitWidth: 44
            implicitHeight: 44
            padding: 0
            leftPadding: 0
            rightPadding: 0
            topPadding: 0
            bottomPadding: 0
            visible: app.mediaChapters.length > 0

            background: Rectangle {
                color: chaptersControlsBtn.pressed ? Qt.rgba(255, 255, 255, 0.1) : (chaptersControlsBtn.hovered ? Qt.rgba(255, 255, 255, 0.05) : "transparent")
                radius: 18
            }

            contentItem: Item {
                anchors.fill: parent

                Text {
                    anchors.centerIn: parent
                    text: "📖"
                    font.pixelSize: 18
                    color: chaptersControlsBtn.hovered ? "#60a5fa" : "#94a3b8"
                }
            }

            onClicked: {
                app.chaptersPopupVisible = !app.chaptersPopupVisible;
            }
        }

        // Hoverable Volume Control (Custom Speaker + Precise Slider margins)
        VolumeControl {
            id: volumeControl
            app: root.app
            narrow: root.isNarrow
        }

        // Fullscreen Toggle Button
        Button {
            id: fullscreenBtn
            flat: true
            implicitWidth: 44
            implicitHeight: 44
            padding: 0
            leftPadding: 0
            rightPadding: 0
            topPadding: 0
            bottomPadding: 0

            background: Rectangle {
                color: fullscreenBtn.pressed ? Qt.rgba(255, 255, 255, 0.1) : (fullscreenBtn.hovered ? Qt.rgba(255, 255, 255, 0.05) : "transparent")
                radius: 18
            }

            contentItem: Canvas {
                id: fullscreenIconCanvas
                onWidthChanged: requestPaint()
                onHeightChanged: requestPaint()
                onPaint: {
                    var ctx = getContext("2d");
                    ctx.reset();
                    ctx.strokeStyle = fullscreenBtn.hovered ? "#60a5fa" : "#94a3b8";
                    ctx.lineWidth = 2.2;
                    ctx.lineCap = "round";
                    ctx.lineJoin = "round";

                    var cx = width / 2;
                    var cy = height / 2;
                    var isFS = app.visibility === Window.FullScreen;

                    if (!isFS) {
                        // Outward corners
                        // Top-left
                        ctx.beginPath();
                        ctx.moveTo(cx - 4, cy - 9);
                        ctx.lineTo(cx - 9, cy - 9);
                        ctx.lineTo(cx - 9, cy - 4);
                        ctx.stroke();
                        // Top-right
                        ctx.beginPath();
                        ctx.moveTo(cx + 4, cy - 9);
                        ctx.lineTo(cx + 9, cy - 9);
                        ctx.lineTo(cx + 9, cy - 4);
                        ctx.stroke();
                        // Bottom-left
                        ctx.beginPath();
                        ctx.moveTo(cx - 4, cy + 9);
                        ctx.lineTo(cx - 9, cy + 9);
                        ctx.lineTo(cx - 9, cy + 4);
                        ctx.stroke();
                        // Bottom-right
                        ctx.beginPath();
                        ctx.moveTo(cx + 4, cy + 9);
                        ctx.lineTo(cx + 9, cy + 9);
                        ctx.lineTo(cx + 9, cy + 4);
                        ctx.stroke();
                    } else {
                        // Inward corners
                        // Top-left
                        ctx.beginPath();
                        ctx.moveTo(cx - 9, cy - 4);
                        ctx.lineTo(cx - 4, cy - 4);
                        ctx.lineTo(cx - 4, cy - 9);
                        ctx.stroke();
                        // Top-right
                        ctx.beginPath();
                        ctx.moveTo(cx + 9, cy - 4);
                        ctx.lineTo(cx + 4, cy - 4);
                        ctx.lineTo(cx + 4, cy - 9);
                        ctx.stroke();
                        // Bottom-left
                        ctx.beginPath();
                        ctx.moveTo(cx - 9, cy + 4);
                        ctx.lineTo(cx - 4, cy + 4);
                        ctx.lineTo(cx - 4, cy + 9);
                        ctx.stroke();
                        // Bottom-right
                        ctx.beginPath();
                        ctx.moveTo(cx + 9, cy + 4);
                        ctx.lineTo(cx + 4, cy + 4);
                        ctx.lineTo(cx + 4, cy + 9);
                        ctx.stroke();
                    }
                }

                Connections {
                    target: app
                    function onVisibilityChanged() {
                        fullscreenIconCanvas.requestPaint();
                    }
                }
                Connections {
                    target: fullscreenBtn
                    function onHoveredChanged() {
                        fullscreenIconCanvas.requestPaint();
                    }
                }
            }

            onClicked: {
                app.toggleFullscreen();
            }
        }
    }
}
