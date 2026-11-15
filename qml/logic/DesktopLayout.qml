import QtQuick
import QtQuick.Window
import QtCore

QtObject {
    id: root
    required property var app
    property bool restored: false
    property int normalWidth: 1120
    property int normalHeight: 720
    property bool maximized: false

    property Settings settings: Settings {
        category: "DesktopLayout"
    }

    function restore() {
        if (!app.layoutPersistenceEnabled)
            return;
        normalWidth = Math.max(app.minimumWidth, Math.min(settings.value("windowWidth", 1120), app.screen.desktopAvailableWidth));
        normalHeight = Math.max(app.minimumHeight, Math.min(settings.value("windowHeight", 720), app.screen.desktopAvailableHeight));
        app.width = normalWidth;
        app.height = normalHeight;
        // Opening a file chooses its own media presentation, but keeps the panel.
        if (app.initialFileUrl === "")
            app.showMediaView(settings.value("mediaView", "audio") === "video" ? "video" : "audio");
        var panel = settings.value("panelView", "");
        app.panelView = ["lyrics", "playlist"].indexOf(panel) >= 0 ? panel : "";
        app.setPanelExpanded(settings.value("panelExpanded", false) && app.panelView !== "");
        maximized = settings.value("maximized", false);
        restored = true;
        if (maximized)
            app.showMaximized();
    }

    function save() {
        if (!app.layoutPersistenceEnabled)
            return;
        if (app.visibility === Window.Windowed) {
            normalWidth = app.width;
            normalHeight = app.height;
            maximized = false;
        } else if (app.visibility === Window.Maximized) {
            maximized = true;
        }
        settings.setValue("windowWidth", normalWidth);
        settings.setValue("windowHeight", normalHeight);
        settings.setValue("maximized", maximized);
        settings.setValue("mediaView", app.mediaView);
        settings.setValue("panelView", app.panelView);
        settings.setValue("panelExpanded", app.panelExpanded);
        settings.sync();
    }

    // Defer geometry updates until the window manager finishes a state change.
    // Fullscreen/minimized sizes must never replace the normal window size.
    property Timer geometryTimer: Timer {
        interval: 100
        onTriggered: {
            if (!root.restored || !root.app.layoutPersistenceEnabled)
                return;
            if (root.app.visibility === Window.Windowed) {
                root.normalWidth = root.app.width;
                root.normalHeight = root.app.height;
                root.maximized = false;
            } else if (root.app.visibility === Window.Maximized) {
                root.maximized = true;
            }
        }
    }
    property Connections windowConnections: Connections {
        target: root.app
        function onWidthChanged() { root.geometryTimer.restart(); }
        function onHeightChanged() { root.geometryTimer.restart(); }
        function onVisibilityChanged() {
            if (root.restored && root.app.visibility === Window.Maximized)
                root.maximized = true;
            else if (root.restored && root.app.visibility === Window.Windowed)
                root.maximized = false;
            root.geometryTimer.restart();
        }
    }
}
