import QtQuick
import QtQuick.Controls
import QtQuick.Controls.Basic as Basic

Basic.Menu {
    id: root
    implicitWidth: 280
    padding: 6
    margins: 8
    overlap: 0
    delegate: DesktopMenuItem {}
    contentItem: ListView {
        implicitHeight: contentHeight
        model: root.contentModel
        currentIndex: root.currentIndex
        spacing: 2
        interactive: contentHeight > height
        clip: true
        ScrollIndicator.vertical: ScrollIndicator {}
    }
    background: Rectangle { color: "#202c38"; radius: 7 }
    Component.onCompleted: {
        if ("popupType" in root)
            root.popupType = Popup.Item;
    }
}
