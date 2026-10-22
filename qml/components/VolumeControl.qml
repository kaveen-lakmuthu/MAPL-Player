import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

MouseArea {
    id: root
    objectName: "volumeControl"
    required property var app
    required property bool narrow
    property alias slider: volumeSlider

    Layout.preferredWidth: volumeLayout.implicitWidth
    Layout.preferredHeight: 44
    width: Layout.preferredWidth
    height: 44
    hoverEnabled: true

    VolumeWheelHandler {
        app: root.app
        // Audio/video already handle the wheel on the surrounding player.
        acceptsVolume: app.currentView !== "audio" && app.currentView !== "video"
    }

    RowLayout {
        id: volumeLayout
        spacing: 8
        anchors.verticalCenter: parent.verticalCenter

        Button {
            id: volumeIconBtn
            flat: true
            implicitWidth: 44
            implicitHeight: 44
            padding: 0
            leftPadding: 0
            rightPadding: 0
            topPadding: 0
            bottomPadding: 0
            property color iconColor: root.containsMouse || volumeIconBtn.hovered ? "#60a5fa" : "#94a3b8"

            background: Rectangle {
                color: volumeIconBtn.pressed ? Qt.rgba(255, 255, 255, 0.1) : (volumeIconBtn.hovered ? Qt.rgba(255, 255, 255, 0.05) : "transparent")
                radius: 18
            }

            contentItem: Canvas {
                id: volumeIconCanvas
                onWidthChanged: requestPaint()
                onHeightChanged: requestPaint()
                onPaint: {
                    var ctx = getContext("2d");
                    ctx.reset();
                    ctx.fillStyle = volumeIconBtn.iconColor;
                    ctx.strokeStyle = volumeIconBtn.iconColor;
                    ctx.lineWidth = 2.0;
                    ctx.lineCap = "round";

                    var w = width;
                    var h = height;
                    var cx = w / 2;
                    var cy = h / 2;
                    var left = cx - 10;
                    var speakerRight = left + 9;

                    // Speaker body
                    ctx.beginPath();
                    ctx.moveTo(left, cy - 4.5);
                    ctx.lineTo(left + 4, cy - 4.5);
                    ctx.lineTo(speakerRight, cy - 9);
                    ctx.lineTo(speakerRight, cy + 9);
                    ctx.lineTo(left + 4, cy + 4.5);
                    ctx.lineTo(left, cy + 4.5);
                    ctx.closePath();
                    ctx.fill();

                    // Sound waves
                    var vol = app.isMuted ? 0 : volumeSlider.value;
                    if (vol > 0) {
                        ctx.beginPath();
                        ctx.arc(speakerRight, cy, 6, -Math.PI / 4, Math.PI / 4, false);
                        ctx.stroke();
                    }
                    if (vol > 50) {
                        ctx.beginPath();
                        ctx.arc(speakerRight, cy, 11, -Math.PI / 4, Math.PI / 4, false);
                        ctx.stroke();
                    }
                }

                Connections {
                    target: volumeSlider
                    function onValueChanged() {
                        volumeIconCanvas.requestPaint();
                    }
                }
                Connections {
                    target: volumeIconBtn
                    function onIconColorChanged() {
                        volumeIconCanvas.requestPaint();
                    }
                }
                Connections {
                    target: app
                    function onIsMutedChanged() {
                        volumeIconCanvas.requestPaint();
                    }
                }
            }

            onClicked: {
                app.toggleMute();
            }
        }

        Rectangle {
            id: sliderContainer
            property int targetWidth: root.containsMouse ? (narrow ? 60 : 100) : 0
            Layout.preferredWidth: targetWidth
            Layout.preferredHeight: 40
            width: targetWidth
            height: 40
            color: "transparent"
            clip: true
            Behavior on targetWidth {
                NumberAnimation {
                    duration: 250
                    easing.type: Easing.InOutQuad
                }
            }

            Slider {
                id: volumeSlider
                anchors.fill: parent
                anchors.leftMargin: 4
                anchors.rightMargin: 4

                Timer {
                    id: saveVolumeTimer
                    interval: 500
                    repeat: false
                    onTriggered: {
                        app.playerController.saveVolume(volumeSlider.value);
                    }
                }
                implicitHeight: 24
                leftPadding: 0
                rightPadding: 0
                topPadding: 0
                bottomPadding: 0
                from: 0
                to: 100
                value: app.playerController.loadVolume()

                background: Rectangle {
                    x: volumeSlider.leftPadding
                    y: volumeSlider.topPadding + volumeSlider.availableHeight / 2 - height / 2
                    width: volumeSlider.availableWidth
                    height: 4
                    radius: 2
                    color: "#475569"
                    Rectangle {
                        width: volumeSlider.visualPosition * parent.width
                        height: parent.height
                        color: "#3b82f6"
                        radius: 2
                    }
                }
                handle: Rectangle {
                    x: volumeSlider.leftPadding + volumeSlider.visualPosition * (volumeSlider.availableWidth - width)
                    y: volumeSlider.topPadding + volumeSlider.availableHeight / 2 - height / 2
                    width: 10
                    height: 10
                    radius: 5
                    color: "white"
                    border.color: "#3b82f6"
                    border.width: 1
                }

                onValueChanged: {
                    saveVolumeTimer.restart();
                    if (value > 0 && app.isMuted) {
                        app.isMuted = false;
                    }
                    volumeIconCanvas.requestPaint();
                }
            }
        }

        Text {
            text: Math.round(volumeSlider.value) + "%"
            color: "#94a3b8"
            font.pixelSize: 13
            font.bold: true
            Layout.alignment: Qt.AlignVCenter
        }
    }
}
