import QtQuick

DesktopButton {
    required property var app
    objectName: "backgroundTaskIndicator"
    visible: app.backgroundTasks.count > 0 || app.backgroundTasksOpen
    glyph: "tasks"
    text: app.backgroundTasks.badge
    hint: app.backgroundTasks.summary + " · Progress and cancellation"
    selected: app.backgroundTasksOpen
    implicitHeight: 26
    onClicked: app.openBackgroundTasks()
}
