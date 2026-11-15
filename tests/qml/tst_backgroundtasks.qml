import QtQuick
import QtQuick.Controls
import QtTest
import "../../qml/logic" as Logic
import "../../qml/components" as Components
import "../../qml/dialogs" as Dialogs

TestCase {
    id: testCase
    name: "BackgroundTasks"
    when: windowShown
    property var app
    Component {
        id: appComponent
        ApplicationWindow {
            id: window
            visible: true
            width: 640
            height: 420
            property string mediaView: "video"
            property bool panelExpanded: false
            property real transcriptionProgressValue: 58
            property real downloadProgressValue: 42
            property alias modelDownloader: downloader
            property alias subtitleGenerator: generator
            property alias backgroundTasks: tasks
            readonly property bool backgroundTasksOpen: popup.visible
            function openBackgroundTasks() { popup.open(); }
            function cancelSubtitleGeneration() { generator.isCancelling = true; ++generator.cancels; }
            QtObject {
                id: downloader
                property bool isBusy: false
                property bool isVerifying: false
                property string activeModel: "tiny"
                property int cancels: 0
                function cancelOperation() { ++cancels; isBusy = false; isVerifying = false; }
            }
            QtObject {
                id: generator
                property bool isProcessing: false
                property bool isCancelling: false
                property int cancels: 0
            }
            Logic.BackgroundTasks { id: tasks; app: window }
            Dialogs.BackgroundTasksPopup { id: popup; app: window }
            Components.BackgroundTaskIndicator { app: window; anchors.right: parent.right; anchors.bottom: parent.bottom }
        }
    }
    function init() {
        failOnWarning(/(ReferenceError|TypeError|is not defined|Cannot assign|Binding loop)/);
        app = createTemporaryObject(appComponent, testCase);
        verify(app !== null);
    }
    function cleanup() { app.close(); }
    function test_concurrentJobsAndIndependentCancellation() {
        var indicator = findChild(app, "backgroundTaskIndicator");
        verify(!indicator.visible);
        app.modelDownloader.isBusy = true;
        app.subtitleGenerator.isProcessing = true;
        compare(app.backgroundTasks.count, 2);
        compare(indicator.text, "2");
        mouseClick(indicator);
        var popup = findChild(app, "backgroundTasksPopup");
        tryCompare(popup, "opened", true);
        waitForRendering(findChild(app, "cancelModelTask"));
        compare(findChild(app, "modelTaskProgress").value, 42);
        compare(findChild(app, "transcriptionTaskProgress").value, 58);
        mouseClick(findChild(app, "cancelModelTask"));
        compare(app.modelDownloader.cancels, 1);
        verify(app.subtitleGenerator.isProcessing);
        compare(indicator.text, "58%");
        var cancel = findChild(app, "cancelSubtitleGeneration");
        mouseClick(cancel);
        compare(app.subtitleGenerator.cancels, 1);
        verify(!cancel.enabled);
        verify(findChild(app, "transcriptionTaskProgress").indeterminate);
        compare(indicator.text, "…");
        app.subtitleGenerator.isProcessing = false;
        compare(app.backgroundTasks.count, 0);
        verify(indicator.visible, "Keep the control until the open popup is dismissed");
        popup.close();
        tryCompare(indicator, "visible", false);
    }
    function test_verificationAndClosingDoNotCancel() {
        app.modelDownloader.isBusy = true;
        app.modelDownloader.isVerifying = true;
        app.openBackgroundTasks();
        var popup = findChild(app, "backgroundTasksPopup");
        tryCompare(popup, "opened", true);
        compare(app.backgroundTasks.downloadLabel, "Verifying tiny");
        compare(app.backgroundTasks.badge, "…");
        verify(findChild(app, "modelTaskProgress").indeterminate);
        waitForRendering(findChild(app, "cancelModelTask"));
        verify(popup.x >= 0 && popup.y >= 0, "Popup position: " + popup.x + ", " + popup.y);
        verify(popup.x + popup.width <= app.width);
        verify(popup.y + popup.height <= app.height);
        popup.close();
        tryCompare(popup, "opened", false);
        verify(app.modelDownloader.isBusy);
        compare(app.modelDownloader.cancels, 0);
        app.openBackgroundTasks();
        tryCompare(popup, "opened", true);
        waitForRendering(findChild(app, "cancelModelTask"));
        mouseClick(findChild(app, "cancelModelTask"));
        compare(app.modelDownloader.cancels, 1);
        verify(!app.modelDownloader.isBusy);
    }
}
