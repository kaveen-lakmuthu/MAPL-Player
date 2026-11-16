import QtQuick
import QtQuick.Controls.Basic as Basic

Basic.MenuItem {
    id: root
    implicitHeight: Math.max(34, implicitContentHeight + topPadding + bottomPadding,
                             implicitIndicatorHeight + topPadding + bottomPadding)
    leftPadding: 12
    rightPadding: 12
    topPadding: 8
    bottomPadding: 8
    spacing: 10
    icon.width: 18
    icon.height: 18
    background: Rectangle {
        radius: 4
        color: root.down ? "#496278" : root.highlighted ? "#35516a" : "transparent"
        border.width: root.visualFocus ? 1 : 0
        border.color: "#9dcbff"
    }
}
