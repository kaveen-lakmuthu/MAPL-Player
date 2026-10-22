import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

RowLayout {
    id: root
    required property var app
    property alias slider: seekSlider

    spacing: 12
    width: parent.width

    Text {
        text: app.formatTime(app.mediaPlayer.position / 1000.0)
        color: "#94a3b8"
        font.pixelSize: 11
        font.bold: true
    }

    Item {
        id: seekSliderWrapper
        Layout.fillWidth: true
        Layout.preferredHeight: 24
        implicitHeight: 24

        Slider {
            id: seekSlider
            anchors.fill: parent
            leftPadding: 7
            rightPadding: 7
            topPadding: 0
            bottomPadding: 0
            from: 0
            to: 100
            value: 0

            background: Rectangle {
                x: seekSlider.leftPadding
                y: seekSlider.topPadding + seekSlider.availableHeight / 2 - height / 2
                width: seekSlider.availableWidth
                height: 6
                radius: 3
                color: "#334155"

                Rectangle {
                    width: seekSlider.visualPosition * parent.width
                    height: parent.height
                    color: "#3b82f6"
                    radius: 3
                }

                // Timeline ticks indicating subtitle/speech density
                Repeater {
                    model: (app.mediaPlayer.duration > 0) ? app.subtitleChunks : []
                    delegate: Rectangle {
                        width: 1.5
                        height: parent.height
                        color: Qt.rgba(255 / 255, 255 / 255, 255 / 255, 0.4)
                        x: {
                            var durSec = app.mediaPlayer.duration / 1000.0;
                            if (durSec <= 0)
                                return 0;
                            return (modelData.start / durSec) * parent.width - width / 2;
                        }
                        y: 0
                    }
                }

                // Timeline ticks indicating chapter marks
                Repeater {
                    model: (app.mediaPlayer.duration > 0) ? app.mediaChapters : []
                    delegate: Rectangle {
                        width: 3
                        height: parent.height
                        color: "#0f172a"
                        visible: modelData.time > 0
                        x: {
                            var durSec = app.mediaPlayer.duration / 1000.0;
                            if (durSec <= 0)
                                return 0;
                            return (modelData.time / durSec) * parent.width - width / 2;
                        }
                        y: 0
                        z: 10
                    }
                }
            }

            handle: Rectangle {
                x: seekSlider.leftPadding + seekSlider.visualPosition * (seekSlider.availableWidth - width)
                y: seekSlider.topPadding + seekSlider.availableHeight / 2 - height / 2
                width: 14
                height: 14
                radius: 7
                color: "white"
                border.color: "#3b82f6"
                border.width: 2
            }

            onMoved: {
                if (app.mediaPlayer.duration > 0) {
                    app.seekTo((value / 100) * app.mediaPlayer.duration);
                }
            }
        }

        // Sibling container for hover previews that sits above the seekSlider
        Item {
            anchors.left: seekSlider.left
            anchors.right: seekSlider.right
            anchors.verticalCenter: seekSlider.verticalCenter
            height: 80  // Generous 80px height centered on the seekbar for easy hover tracking without vertical cursor drift exit
            z: 9999

            MouseArea {
                id: seekHoverArea
                anchors.fill: parent
                hoverEnabled: true
                acceptedButtons: Qt.NoButton
                onEntered: console.log("[DEBUG] Mouse entered seekHoverArea. containsMouse:", containsMouse)
                onExited: console.log("[DEBUG] Mouse exited seekHoverArea. containsMouse:", containsMouse)
            }

            Rectangle {
                id: previewCard

                // Premium glassmorphism design and custom shadow colors
                width: 176
                height: {
                    var h = 126;
                    if (app.subtitleChunks && app.subtitleChunks.length > 0)
                        h += 30;
                    if (app.mediaChapters && app.mediaChapters.length > 0)
                        h += 18;
                    return h;
                }
                clip: true
                color: Qt.rgba(15 / 255.0, 23 / 255.0, 42 / 255.0, 0.95)
                border.color: "#3b82f6"
                border.width: 1.5
                radius: 8

                // Dynamic X positioning: centers over mouse cursor when hovering, or over the seek handle when dragging/sliding.
                x: {
                    var trackWidth = seekSlider.width - seekSlider.leftPadding - seekSlider.rightPadding;
                    var centerX = seekSlider.leftPadding + hoverPercent * trackWidth;
                    return Math.max(0, Math.min(seekSlider.width - width, centerX - width / 2));
                }
                anchors.bottom: parent.top
                anchors.bottomMargin: 8

                // Unify coordinates for hover vs active dragging
                property real hoverPercent: {
                    if (app.mediaPlayer.duration <= 0 || seekSlider.width <= 0)
                        return 0.0;
                    var trackWidth = seekSlider.width - seekSlider.leftPadding - seekSlider.rightPadding;
                    if (trackWidth <= 0)
                        return 0.0;

                    var localX;
                    if (seekSlider.pressed) {
                        localX = seekSlider.visualPosition * trackWidth;
                    } else {
                        localX = seekHoverArea.mouseX - seekSlider.leftPadding;
                    }
                    return Math.max(0, Math.min(1.0, localX / trackWidth));
                }

                // Smooth entrance/exit transitions and dynamic height/position updating
                property bool showPreview: (seekHoverArea.containsMouse || seekSlider.pressed) && app.mediaPlayer.duration > 0
                opacity: showPreview ? 1.0 : 0.0
                scale: showPreview ? 1.0 : 0.8
                visible: opacity > 0.0

                Behavior on opacity {
                    NumberAnimation {
                        duration: 150
                        easing.type: Easing.OutQuad
                    }
                }
                Behavior on scale {
                    NumberAnimation {
                        duration: 150
                        easing.type: Easing.OutQuad
                    }
                }

                Column {
                    id: previewColumn
                    visible: app.currentTimelinePreviewSheet !== ""
                    width: parent.width - 8
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.top: parent.top
                    anchors.topMargin: 4
                    spacing: 4

                    Item {
                        width: 168
                        height: 94.5
                        clip: true

                        Rectangle {
                            anchors.fill: parent
                            color: "#0f172a"
                            radius: 6
                            clip: true

                            Image {
                                id: previewImage
                                source: app.currentTimelinePreviewSheet
                                sourceClipRect: {
                                    var index = Math.max(0, Math.min(99, Math.floor(previewCard.hoverPercent * 100)));
                                    var col = index % 10;
                                    var row = Math.floor(index / 10);
                                    return Qt.rect(col * 160, row * 90, 160, 90);
                                }
                                width: 168
                                height: 94.5
                                fillMode: Image.Stretch
                                asynchronous: true
                            }
                        }
                    }

                    Text {
                        width: parent.width
                        horizontalAlignment: Text.AlignHCenter
                        color: "#e2e8f0"
                        font.pixelSize: 11
                        font.bold: true
                        font.family: "Inter"
                        text: {
                            var sec = previewCard.hoverPercent * (app.mediaPlayer.duration / 1000.0);
                            return app.formatTime(sec);
                        }
                    }

                    Text {
                        width: parent.width
                        horizontalAlignment: Text.AlignHCenter
                        elide: Text.ElideRight
                        color: "#38bdf8"
                        font.pixelSize: 10
                        font.bold: true
                        font.family: "Inter"
                        visible: app.mediaChapters && app.mediaChapters.length > 0
                        text: {
                            if (!app.mediaChapters || app.mediaChapters.length === 0)
                                return "";
                            var sec = previewCard.hoverPercent * (app.mediaPlayer.duration / 1000.0);
                            return app.getChapterAtTime(sec);
                        }
                    }

                    Text {
                        id: previewSubtitleText
                        width: parent.width
                        horizontalAlignment: Text.AlignHCenter
                        wrapMode: Text.WordWrap
                        color: "#93c5fd" // Light blue accent text for preview subtitles
                        font.pixelSize: 10
                        font.bold: true
                        font.family: "Inter, Noto Sans Sinhala, Noto Sans, sans-serif"
                        visible: text !== ""

                        text: {
                            if (app.subtitleChunks.length === 0)
                                return "";
                            var sec = previewCard.hoverPercent * (app.mediaPlayer.duration / 1000.0);
                            var bestText = "";
                            var minDuration = 999999;
                            for (var i = 0; i < app.subtitleChunks.length; i++) {
                                var chunk = app.subtitleChunks[i];
                                if (sec >= chunk.start && sec <= chunk.end) {
                                    var dur = chunk.end - chunk.start;
                                    if (dur >= 0 && dur < minDuration) {
                                        minDuration = dur;
                                        bestText = chunk.text;
                                    }
                                }
                            }
                            return bestText;
                        }
                    }
                }

                Column {
                    id: loadingColumn
                    anchors.centerIn: parent
                    spacing: 8
                    visible: app.currentTimelinePreviewSheet === ""

                    Item {
                        width: 32
                        height: 32
                        anchors.horizontalCenter: parent.horizontalCenter

                        Canvas {
                            id: spinnerCanvas
                            anchors.fill: parent
                            onPaint: {
                                var ctx = getContext("2d");
                                ctx.reset();
                                ctx.strokeStyle = "#3b82f6";
                                ctx.lineWidth = 3;
                                ctx.beginPath();
                                ctx.arc(16, 16, 12, 0, Math.PI * 1.5);
                                ctx.stroke();
                            }
                        }

                        RotationAnimator {
                            target: spinnerCanvas
                            from: 0
                            to: 360
                            duration: 1000
                            running: previewCard.showPreview && app.currentTimelinePreviewSheet === ""
                            loops: Animation.Infinite
                        }
                    }

                    Text {
                        text: "Preparing previews..."
                        color: "#94a3b8"
                        font.pixelSize: 11
                        font.bold: true
                        font.family: "Inter"
                        anchors.horizontalCenter: parent.horizontalCenter
                    }
                }
            }
        }
    }

    Text {
        text: app.mediaPlayer.duration > 0 ? ("-" + app.formatTime(Math.max(0, app.mediaPlayer.duration - app.mediaPlayer.position) / 1000.0) + " / " + app.formatTime(app.mediaPlayer.duration / 1000.0)) : "0:00"
        color: "#94a3b8"
        font.pixelSize: 11
        font.bold: true
    }
    Button {
        objectName: "playbackOptionsButton"
        text: Number(app.playbackOptions.rate.toFixed(2)) + "×"
        flat: true
        implicitWidth: 58
        implicitHeight: 30
        ToolTip.visible: hovered
        ToolTip.text: "Audio tracks, speed and audio delay"
        onClicked: app.openPlaybackOptions()
    }
}
