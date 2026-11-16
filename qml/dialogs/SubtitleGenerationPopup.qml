import QtQuick
import QtQuick.Controls
import "../components"

PlayerPopup {
    id: root
    objectName: "subtitleGenerationPopup"
    preferredWidth: 470
    padding: 20
    background: Rectangle { color: "#202c38"; radius: 7 }
    contentItem: ScrollView {
        id: scroll
        implicitHeight: generator.implicitHeight
        contentWidth: availableWidth
        clip: true
        SubtitleGeneratorPanel { id: generator; app: root.app; width: scroll.availableWidth }
    }
}
