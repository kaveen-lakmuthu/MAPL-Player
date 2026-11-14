import QtQuick
import QtQuick.Controls
import QtQuick.Controls.Basic as Basic
import QtQuick.Layouts

RowLayout {
    id: root
    required property var app
    property alias slider: seekSlider
    spacing: 8
    implicitHeight: 30

    Text { text: app.formatTime(app.mediaPlayer.position / 1000); color: "#c2ceda"; font.pixelSize: 11 }
    Item {
        Layout.fillWidth: true
        Layout.preferredHeight: 28
        Basic.Slider {
            id: seekSlider
            anchors.fill: parent
            leftPadding: 5
            rightPadding: 5
            topPadding: 0
            bottomPadding: 0
            from: 0
            to: 100
            value: 0
            enabled: app.mediaPlayer.seekable
            Accessible.name: "Playback position"
            background: Rectangle {
                x: seekSlider.leftPadding
                y: seekSlider.availableHeight / 2 - height / 2
                width: seekSlider.availableWidth
                height: 4
                radius: 2
                color: "#526477"
                Rectangle { width: seekSlider.visualPosition * parent.width; height: parent.height; radius: 2; color: "#8bbbed" }
                Repeater {
                    model: app.mediaPlayer.duration > 0 ? app.subtitleChunks : []
                    Rectangle {
                        required property var modelData
                        width: 1.5
                        height: parent.height
                        color: "#aaffffff"
                        x: modelData.start / (app.mediaPlayer.duration / 1000) * parent.width - width / 2
                    }
                }
                Repeater {
                    model: app.mediaPlayer.duration > 0 ? app.mediaChapters : []
                    Rectangle {
                        required property var modelData
                        visible: modelData.time > 0
                        width: 3
                        height: parent.height
                        color: "#18222d"
                        x: modelData.time / (app.mediaPlayer.duration / 1000) * parent.width - width / 2
                    }
                }
            }
            handle: Rectangle {
                x: seekSlider.leftPadding + seekSlider.visualPosition * (seekSlider.availableWidth - width)
                y: seekSlider.availableHeight / 2 - height / 2
                width: 10
                height: 10
                radius: 5
                color: "#edf3fa"
                border.width: seekSlider.visualFocus ? 2 : 0
                border.color: "#8bbbed"
            }
            onMoved: {
                if (app.mediaPlayer.duration > 0)
                    app.seekTo(value / 100 * app.mediaPlayer.duration);
            }
        }
        MouseArea {
            id: hover
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.NoButton
        }
        Rectangle {
            id: preview
            objectName: "seekPreview"
            readonly property real fraction: {
                var trackWidth = seekSlider.availableWidth;
                if (trackWidth <= 0) return 0;
                return seekSlider.pressed ? seekSlider.visualPosition : Math.max(0, Math.min(1, (hover.mouseX - seekSlider.leftPadding) / trackWidth));
            }
            readonly property real seconds: fraction * app.mediaPlayer.duration / 1000
            width: 176
            height: previewContent.implicitHeight + 8
            x: Math.max(0, Math.min(seekSlider.width - width, seekSlider.leftPadding + fraction * seekSlider.availableWidth - width / 2))
            anchors.bottom: parent.top
            anchors.bottomMargin: 8
            color: "#f0202c38"
            radius: 5
            visible: (hover.containsMouse || seekSlider.pressed) && app.mediaPlayer.duration > 0 && !app.modalDialogOpen
            z: 1000

            Column {
                id: previewContent
                anchors.top: parent.top
                anchors.topMargin: 4
                anchors.horizontalCenter: parent.horizontalCenter
                width: parent.width - 8
                spacing: 4
                Item {
                    width: 168
                    height: 94.5
                    visible: app.mediaPlayer.hasVideo
                    clip: true
                    Image {
                        anchors.fill: parent
                        source: app.currentTimelinePreviewSheet
                        sourceClipRect: {
                            var index = Math.max(0, Math.min(99, Math.floor(preview.fraction * 100)));
                            return Qt.rect(index % 10 * 160, Math.floor(index / 10) * 90, 160, 90);
                        }
                        fillMode: Image.Stretch
                        asynchronous: true
                    }
                    Text {
                        anchors.centerIn: parent
                        visible: app.currentTimelinePreviewSheet === ""
                        text: "Preparing previews…"
                        color: "#c2ceda"
                        font.pixelSize: 11
                    }
                }
                Text {
                    objectName: "seekPreviewTime"
                    width: parent.width
                    text: app.formatTime(preview.seconds)
                    horizontalAlignment: Text.AlignHCenter
                    color: "#edf3fa"
                    font.pixelSize: 11
                }
                Text {
                    width: parent.width
                    text: app.getChapterAtTime(preview.seconds)
                    visible: text !== ""
                    color: "#9dcbff"
                    font.pixelSize: 11
                    horizontalAlignment: Text.AlignHCenter
                    elide: Text.ElideRight
                }
                Text {
                    objectName: "seekPreviewSubtitle"
                    width: parent.width
                    visible: text !== ""
                    text: {
                        var best = "";
                        var shortest = Infinity;
                        for (var i = 0; i < app.subtitleChunks.length; ++i) {
                            var chunk = app.subtitleChunks[i];
                            var duration = chunk.end - chunk.start;
                            if (preview.seconds >= chunk.start && preview.seconds <= chunk.end && duration >= 0 && duration < shortest) {
                                shortest = duration;
                                best = chunk.text;
                            }
                        }
                        return best;
                    }
                    color: "#c2ceda"
                    font.pixelSize: 11
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.WordWrap
                    maximumLineCount: 2
                    elide: Text.ElideRight
                }
            }
        }
    }
    Text {
        text: app.mediaPlayer.duration > 0 ? "-" + app.formatTime(Math.max(0, app.mediaPlayer.duration - app.mediaPlayer.position) / 1000) + " / " + app.formatTime(app.mediaPlayer.duration / 1000) : "0:00"
        color: "#c2ceda"
        font.pixelSize: 11
    }
    DesktopButton {
        objectName: "playbackOptionsButton"
        text: Number(app.playbackOptions.rate.toFixed(2)) + "×"
        hint: "Audio tracks, speed and audio delay"
        implicitHeight: 26
        implicitWidth: 48
        onClicked: app.openPlaybackOptions()
    }
}
