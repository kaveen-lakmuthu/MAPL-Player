import QtQuick
import QtQuick.Window

WheelHandler {
    required property var app
    property bool acceptsVolume: true
    enabled: acceptsVolume && !app.modalDialogOpen
    target: null
    acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
    acceptedModifiers: Qt.NoModifier
    orientation: Qt.Vertical

    onWheel: event => {
        // One standard wheel notch is 120 angle units. Preserve smaller
        // high-resolution deltas; pixel-only touchpads use 40 pixels per step.
        var steps = event.angleDelta.y !== 0 ? event.angleDelta.y / 120 : event.pixelDelta.y / 40;
        if (steps === 0) {
            event.accepted = false;
            return;
        }
        event.accepted = true;
        app.changeVolume(steps * 5);
        if (app.visibility === Window.FullScreen) {
            app.controlsVisible = true;
            app.restartControlsHideTimer();
        }
    }
}
