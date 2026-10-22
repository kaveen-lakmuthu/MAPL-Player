import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtMultimedia

RowLayout {
    id: root
    required property var app
    required property bool narrow

    spacing: narrow ? 8 : 12
    Layout.alignment: Qt.AlignVCenter

    Button {
        id: prevBtn
        flat: true
        implicitWidth: 40
        implicitHeight: 40
        Layout.alignment: Qt.AlignVCenter
        scale: prevBtn.hovered ? 1.05 : 1.0
        Behavior on scale {
            NumberAnimation {
                duration: 100
            }
        }
        padding: 0
        leftPadding: 0
        rightPadding: 0
        topPadding: 0
        bottomPadding: 0

        background: Rectangle {
            radius: 20
            color: prevBtn.pressed ? "#1e293b" : (prevBtn.hovered ? "#334155" : "#1e293b")
            border.color: prevBtn.hovered ? "#475569" : "#334155"
            border.width: 1
        }

        contentItem: Canvas {
            id: prevCanvas
            onWidthChanged: requestPaint()
            onHeightChanged: requestPaint()
            onPaint: {
                var ctx = getContext("2d");
                ctx.reset();
                ctx.fillStyle = prevBtn.hovered ? "#60a5fa" : "#cbd5e1";

                var w = width;
                var h = height;
                var iconW = 16;
                var iconH = 16;
                var cx = w / 2;
                var cy = h / 2;
                var left = cx - iconW / 2;
                var top = cy - iconH / 2;
                var right = left + iconW;
                var bottom = top + iconH;

                // Draw vertical bar on the left
                ctx.fillRect(left, top, 3.5, iconH);

                // Draw left-pointing triangle
                ctx.beginPath();
                ctx.moveTo(left + 6.0, cy);
                ctx.lineTo(right, top);
                ctx.lineTo(right, bottom);
                ctx.closePath();
                ctx.fill();
            }
            Connections {
                target: prevBtn
                function onHoveredChanged() {
                    prevCanvas.requestPaint();
                }
            }
        }

        onClicked: {
            app.playPrev();
        }
    }

    Button {
        id: back5sBtn
        flat: true
        implicitWidth: 40
        implicitHeight: 40
        Layout.alignment: Qt.AlignVCenter
        scale: back5sBtn.hovered ? 1.05 : 1.0
        Behavior on scale {
            NumberAnimation {
                duration: 100
            }
        }
        padding: 0
        leftPadding: 0
        rightPadding: 0
        topPadding: 0
        bottomPadding: 0

        background: Rectangle {
            radius: 20
            color: back5sBtn.pressed ? "#1e293b" : (back5sBtn.hovered ? "#334155" : "#1e293b")
            border.color: back5sBtn.hovered ? "#475569" : "#334155"
            border.width: 1
        }

        contentItem: Canvas {
            id: back5sCanvas
            onWidthChanged: requestPaint()
            onHeightChanged: requestPaint()
            onPaint: {
                var ctx = getContext("2d");
                ctx.reset();
                var color = back5sBtn.hovered ? "#60a5fa" : "#cbd5e1";
                ctx.strokeStyle = color;
                ctx.fillStyle = color;
                ctx.lineWidth = 2.2;
                ctx.lineCap = "round";
                ctx.lineJoin = "round";

                var cx = width / 2;
                var cy = height / 2;

                ctx.beginPath();
                ctx.arc(cx, cy, 11, 1.7 * Math.PI, 0.35 * Math.PI, true); // counter-clockwise
                ctx.stroke();

                // Arrowhead at 1.7 * Math.PI
                var ax = cx + 11 * Math.cos(1.7 * Math.PI);
                var ay = cy + 11 * Math.sin(1.7 * Math.PI);
                ctx.beginPath();
                ctx.moveTo(ax - 4.5, ay - 3.0);
                ctx.lineTo(ax, ay);
                ctx.lineTo(ax + 3.0, ay + 4.5);
                ctx.stroke();

                ctx.font = "bold 12px sans-serif";
                ctx.textAlign = "center";
                ctx.textBaseline = "middle";
                ctx.fillText("5", cx - 0.5, cy + 0.5);
            }
            Connections {
                target: back5sBtn
                function onHoveredChanged() {
                    back5sCanvas.requestPaint();
                }
            }
        }

        onClicked: {
            app.seekRelative(-5);
        }
    }

    Button {
        id: playPauseBtn
        flat: true
        implicitWidth: 48
        implicitHeight: 48
        Layout.alignment: Qt.AlignVCenter
        scale: playPauseBtn.hovered ? 1.05 : 1.0
        Behavior on scale {
            NumberAnimation {
                duration: 100
            }
        }
        padding: 0
        leftPadding: 0
        rightPadding: 0
        topPadding: 0
        bottomPadding: 0

        background: Rectangle {
            radius: 24
            color: playPauseBtn.pressed ? "#1d4ed8" : (playPauseBtn.hovered ? "#2563eb" : "#3b82f6")
            border.color: playPauseBtn.pressed ? "#1e40af" : "#60a5fa"
            border.width: 1
        }
        contentItem: Canvas {
            id: playPauseCanvas
            onWidthChanged: requestPaint()
            onHeightChanged: requestPaint()
            onPaint: {
                var ctx = getContext("2d");
                ctx.reset();
                ctx.fillStyle = "white";

                var w = width;
                var h = height;
                var cx = w / 2;
                var cy = h / 2;
                var iconW = 14;
                var iconH = 16;
                var left = cx - iconW / 2;
                var top = cy - iconH / 2;
                var right = left + iconW;
                var bottom = top + iconH;

                var isPlaying = (app.mediaPlayer.playbackState === MediaPlayer.PlayingState);
                if (isPlaying) {
                    // Draw Pause (two vertical rectangles)
                    ctx.fillRect(left, top, 4, iconH);
                    ctx.fillRect(right - 4, top, 4, iconH);
                } else {
                    // Draw Play triangle (slightly offset right for visual balance)
                    ctx.beginPath();
                    ctx.moveTo(left + 1.5, top);
                    ctx.lineTo(right + 1.5, cy);
                    ctx.lineTo(left + 1.5, bottom);
                    ctx.closePath();
                    ctx.fill();
                }
            }

            Connections {
                target: app.mediaPlayer
                function onPlaybackStateChanged() {
                    playPauseCanvas.requestPaint();
                }
            }
            Connections {
                target: playPauseBtn
                function onHoveredChanged() {
                    playPauseCanvas.requestPaint();
                }
            }
        }
        onClicked: {
            app.togglePlayPause();
        }
    }

    Button {
        id: forward5sBtn
        flat: true
        implicitWidth: 40
        implicitHeight: 40
        Layout.alignment: Qt.AlignVCenter
        scale: forward5sBtn.hovered ? 1.05 : 1.0
        Behavior on scale {
            NumberAnimation {
                duration: 100
            }
        }
        padding: 0
        leftPadding: 0
        rightPadding: 0
        topPadding: 0
        bottomPadding: 0

        background: Rectangle {
            radius: 20
            color: forward5sBtn.pressed ? "#1e293b" : (forward5sBtn.hovered ? "#334155" : "#1e293b")
            border.color: forward5sBtn.hovered ? "#475569" : "#334155"
            border.width: 1
        }

        contentItem: Canvas {
            id: forward5sCanvas
            onWidthChanged: requestPaint()
            onHeightChanged: requestPaint()
            onPaint: {
                var ctx = getContext("2d");
                ctx.reset();
                var color = forward5sBtn.hovered ? "#60a5fa" : "#cbd5e1";
                ctx.strokeStyle = color;
                ctx.fillStyle = color;
                ctx.lineWidth = 2.2;
                ctx.lineCap = "round";
                ctx.lineJoin = "round";

                var cx = width / 2;
                var cy = height / 2;

                ctx.beginPath();
                ctx.arc(cx, cy, 11, 1.3 * Math.PI, 0.65 * Math.PI, false); // clockwise
                ctx.stroke();

                // Arrowhead at 1.3 * Math.PI
                var ax = cx + 11 * Math.cos(1.3 * Math.PI);
                var ay = cy + 11 * Math.sin(1.3 * Math.PI);
                ctx.beginPath();
                ctx.moveTo(ax + 4.5, ay - 3.0);
                ctx.lineTo(ax, ay);
                ctx.lineTo(ax - 3.0, ay + 4.5);
                ctx.stroke();

                ctx.font = "bold 12px sans-serif";
                ctx.textAlign = "center";
                ctx.textBaseline = "middle";
                ctx.fillText("5", cx - 0.5, cy + 0.5);
            }
            Connections {
                target: forward5sBtn
                function onHoveredChanged() {
                    forward5sCanvas.requestPaint();
                }
            }
        }

        onClicked: {
            app.seekRelative(5);
        }
    }

    Button {
        id: nextBtn
        flat: true
        implicitWidth: 40
        implicitHeight: 40
        Layout.alignment: Qt.AlignVCenter
        scale: nextBtn.hovered ? 1.05 : 1.0
        Behavior on scale {
            NumberAnimation {
                duration: 100
            }
        }
        padding: 0
        leftPadding: 0
        rightPadding: 0
        topPadding: 0
        bottomPadding: 0

        background: Rectangle {
            radius: 20
            color: nextBtn.pressed ? "#1e293b" : (nextBtn.hovered ? "#334155" : "#1e293b")
            border.color: nextBtn.hovered ? "#475569" : "#334155"
            border.width: 1
        }

        contentItem: Canvas {
            id: nextCanvas
            onWidthChanged: requestPaint()
            onHeightChanged: requestPaint()
            onPaint: {
                var ctx = getContext("2d");
                ctx.reset();
                ctx.fillStyle = nextBtn.hovered ? "#60a5fa" : "#cbd5e1";

                var w = width;
                var h = height;
                var iconW = 16;
                var iconH = 16;
                var cx = w / 2;
                var cy = h / 2;
                var left = cx - iconW / 2;
                var top = cy - iconH / 2;
                var right = left + iconW;
                var bottom = top + iconH;

                // Draw right-pointing triangle
                ctx.beginPath();
                ctx.moveTo(right - 6.0, cy);
                ctx.lineTo(left, top);
                ctx.lineTo(left, bottom);
                ctx.closePath();
                ctx.fill();

                // Draw vertical bar on the right
                ctx.fillRect(right - 3.5, top, 3.5, iconH);
            }
            Connections {
                target: nextBtn
                function onHoveredChanged() {
                    nextCanvas.requestPaint();
                }
            }
        }

        onClicked: {
            app.playNext();
        }
    }
}
