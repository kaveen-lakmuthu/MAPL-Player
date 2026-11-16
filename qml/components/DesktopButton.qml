import QtQuick
import QtQuick.Controls
import QtQuick.Controls.Basic as Basic
import QtQuick.Layouts

Basic.Button {
    id: root
    property string glyph: ""
    property string hint: text
    property bool selected: false
    property bool prominent: false
    property real iconSize: 18
    property real cornerRadius: 5
    implicitWidth: Math.max(34, contentItem.implicitWidth + leftPadding + rightPadding)
    implicitHeight: Math.max(30, contentItem.implicitHeight + topPadding + bottomPadding)
    padding: 6
    horizontalPadding: text === "" ? 8 : 12
    focusPolicy: Qt.TabFocus
    Accessible.name: hint
    ToolTip.visible: hovered && hint !== ""
    ToolTip.delay: 600
    ToolTip.text: hint
    opacity: enabled ? 1 : 0.4
    contentItem: RowLayout {
        spacing: 8
        PlayerIcon {
            visible: root.glyph !== ""
            name: root.glyph
            Layout.preferredWidth: root.iconSize
            Layout.preferredHeight: root.iconSize
            Layout.alignment: Qt.AlignCenter
        }
        Text {
            visible: root.text !== ""
            text: root.text
            color: "#edf3fa"
            font.pixelSize: 12
            elide: Text.ElideRight
            horizontalAlignment: Text.AlignHCenter
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignCenter
        }
    }
    background: Rectangle {
        radius: root.cornerRadius
        color: root.down ? "#496278" : root.hovered ? "#3a5064" : root.selected || root.prominent ? "#355c79" : "#293947"
        border.width: root.visualFocus ? 2 : 0
        border.color: "#9dcbff"
    }
}
