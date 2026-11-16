import QtQuick
import QtQuick.Controls

Dialog {
    id: root
    required property var app
    property real preferredWidth: 420
    parent: app.Overlay.overlay
    anchors.centerIn: parent
    margins: 20
    padding: 20
    width: Math.min(preferredWidth, Math.max(0, parent.width - margins * 2))
    height: Math.min(implicitHeight, Math.max(0, parent.height - margins * 2))
    modal: true
    focus: true
    closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside

    Component.onCompleted: {
        if ("popupType" in root)
            root.popupType = Popup.Item;
    }
}
