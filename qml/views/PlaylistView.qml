import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
    id: root
    required property var app
    readonly property var filteredIndices: {
        var result = [];
        var query = filter.text.toLowerCase();
        for (var i = 0; i < app.playlist.length; ++i) {
            if (app.playlist[i].title.toLowerCase().indexOf(query) !== -1)
                result.push(i);
        }
        return result;
    }
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
            objectName: "playlistFilter"
            Layout.fillWidth: true
            Layout.preferredHeight: 30
            leftPadding: 12
            rightPadding: 12
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
            spacing: 2
            // Preserve queue indices through filtering. C++ QVariantMap entries
            // become separate JS wrappers, so indexOf(modelData) cannot find them.
            model: root.filteredIndices
            ScrollBar.vertical: ScrollBar {}
            delegate: ItemDelegate {
                id: track
                required property int modelData
                readonly property var entry: app.playlist[modelData]
                width: list.width
                height: 34
                horizontalPadding: 12
                verticalPadding: 8
                readonly property bool isCurrent: modelData === app.currentTrackIndex
                text: (modelData + 1) + ".  " + (entry ? entry.title : "")
                contentItem: Text { text: track.text; color: track.isCurrent ? "#9dcbff" : "#d3dee9"; font.bold: track.isCurrent; font.pixelSize: 12; elide: Text.ElideRight; verticalAlignment: Text.AlignVCenter }
                background: Rectangle { color: track.isCurrent ? "#30485e" : track.hovered ? "#2b3c4d" : "transparent"; radius: 4 }
                onClicked: { app.loadTrack(modelData); app.playCurrentTrack(); }
            }
        }
        Text { visible: app.playlist.length === 0; text: "Open media or an XSPF playlist from File."; color: "#acbdcf"; font.pixelSize: 12; wrapMode: Text.WordWrap; Layout.fillWidth: true }
    }
}
