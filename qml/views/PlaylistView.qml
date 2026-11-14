import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
    id: root
    required property var app
    anchors.fill: parent
    visible: app.panelView === "playlist"

    ColumnLayout {
        anchors.fill: parent
        spacing: 8
        CheckBox {
            text: "Auto-load folder files"
            checked: app.playFolderToggle
            onClicked: {
                app.playFolderToggle = !app.playFolderToggle;
                app.playerController.savePlayFolderToggle(app.playFolderToggle);
            }
        }
        TextField {
            id: filter
            Layout.fillWidth: true
            Layout.preferredHeight: 30
            placeholderText: "Filter playlist…"
            color: "#edf3fa"
            background: Rectangle { color: "#15212c"; radius: 4; border.width: filter.activeFocus ? 1 : 0; border.color: "#9dcbff" }
        }
        ListView {
            id: list
            objectName: "playlistListView"
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            model: app.playlist.filter(track => track.title.toLowerCase().indexOf(filter.text.toLowerCase()) !== -1)
            ScrollBar.vertical: ScrollBar {}
            delegate: ItemDelegate {
                id: track
                width: list.width
                height: 34
                property bool isCurrent: modelData.url === app.playlist[app.currentTrackIndex]?.url
                contentItem: Text { text: (index + 1) + ".  " + modelData.title; color: track.isCurrent ? "#9dcbff" : "#d3dee9"; font.bold: track.isCurrent; font.pixelSize: 12; elide: Text.ElideRight; verticalAlignment: Text.AlignVCenter }
                background: Rectangle { color: track.isCurrent ? "#30485e" : track.hovered ? "#2b3c4d" : "transparent"; radius: 4 }
                onClicked: { app.loadTrack(app.playlist.indexOf(modelData)); app.playCurrentTrack(); }
            }
        }
        Text { visible: app.playlist.length === 0; text: "Open media or an XSPF playlist from File."; color: "#acbdcf"; font.pixelSize: 12; wrapMode: Text.WordWrap; Layout.fillWidth: true }
    }
}
