import QtQuick
import QtQuick.Controls
import QtQuick.Controls.Basic as Basic

Basic.ComboBox {
    id: root
    padding: 6
    spacing: 8
    delegate: Basic.ItemDelegate {
        required property var modelData
        required property int index
        width: ListView.view.width
        text: root.textRole === "" ? modelData : modelData[root.textRole]
        font: root.font
        palette: root.palette
        highlighted: root.highlightedIndex === index
        leftPadding: 12
        rightPadding: 12
        topPadding: 8
        bottomPadding: 8
        implicitHeight: Math.max(34, implicitContentHeight + topPadding + bottomPadding)
        background: Rectangle {
            radius: 4
            color: parent.down ? "#496278" : parent.highlighted || parent.hovered ? "#35516a" : "transparent"
        }
    }
    popup: Basic.Popup {
        y: root.height + 4
        width: root.width
        height: Math.min(contentItem.implicitHeight + topPadding + bottomPadding,
                         Math.max(0, root.Window.height - margins * 2))
        margins: 8
        padding: 6
        focus: true
        font: root.font
        palette: root.palette
        contentItem: ListView {
            implicitHeight: contentHeight
            model: root.delegateModel
            currentIndex: root.highlightedIndex
            highlightMoveDuration: 0
            spacing: 2
            clip: true
            ScrollIndicator.vertical: ScrollIndicator {}
        }
        background: Rectangle { color: "#202c38"; radius: 7 }
    }
}
