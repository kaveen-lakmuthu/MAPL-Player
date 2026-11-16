import QtQuick
import QtQuick.Controls

Popup {
    id: root
    required property var app
    property real preferredWidth: 460
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
        // popupType was introduced in Qt 6.8; older Qt always embeds popups.
        // Keep our custom panels in the player's scene on every desktop style.
        if ("popupType" in root)
            root.popupType = Popup.Item;
    }
}
