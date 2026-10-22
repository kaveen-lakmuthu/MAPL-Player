import QtQuick
import QtTest
import QtQuick.Controls
import "../../qml/dialogs" as Dialogs

TestCase {
    id: testCase
    name: "ModelManagement"
    when: windowShown
    property var app
    property var manager
    Component {
        id: appComponent
        ApplicationWindow {
            visible: true
            width: 850
            height: 700
            property alias modelDownloader: backend
            QtObject {
                id: backend
                property bool isBusy: false
                property bool isDownloading: false
                property bool isVerifying: false
                property string activeModel: ""
                property real progress: 0
                property var downloads: []
                property var deletions: []
                property int cancels: 0
                property var models: [
                    {
                        name: "tiny",
                        title: "Tiny",
                        expectedBytes: 77691713,
                        installedBytes: 0,
                        present: false,
                        verified: false,
                        status: "Not installed",
                        error: "",
                        inUse: false
                    },
                    {
                        name: "base",
                        title: "Base",
                        expectedBytes: 147951465,
                        installedBytes: 147951465,
                        present: true,
                        verified: true,
                        status: "Installed",
                        error: "",
                        inUse: false
                    }
                ]
                function update(name, changes) {
                    models = models.map(function (model) {
                        return model.name === name ? Object.assign({}, model, changes) : model;
                    });
                }
                function startDownload(name) {
                    downloads = downloads.concat([name]);
                    activeModel = name;
                    isBusy = true;
                    isDownloading = true;
                    progress = 42;
                    update(name, {
                        status: "Downloading"
                    });
                }
                function cancelOperation() {
                    ++cancels;
                    update(activeModel, {
                        status: "Not installed"
                    });
                    isBusy = false;
                    isDownloading = false;
                    activeModel = "";
                }
                function deleteModel(name) {
                    deletions = deletions.concat([name]);
                    update(name, {
                        status: "Not installed",
                        installedBytes: 0,
                        present: false,
                        verified: false
                    });
                    return true;
                }
            }
        }
    }
    Component {
        id: managerComponent
        Dialogs.ModelManager {}
    }
    function init() {
        failOnWarning(/(ReferenceError|TypeError|is not defined|Cannot assign|Binding loop)/);
        app = createTemporaryObject(appComponent, testCase);
        manager = createTemporaryObject(managerComponent, app, {
            app: app
        });
        manager.open();
        tryCompare(manager, "opened", true);
        waitForRendering(manager.contentItem);
    }
    function cleanup() {
        manager.close();
    }
    function button(name) {
        var list = findChild(manager, "modelList");
        var index = name.endsWith("tiny") ? 0 : 1;
        tryVerify(function () {
            return list.itemAtIndex(index) !== null;
        });
        var result = findChild(list.itemAtIndex(index), name);
        verify(result !== null, name);
        return result;
    }
    function test_downloadShowsProgressAndCanCancel() {
        mouseClick(button("downloadModel_tiny"));
        compare(app.modelDownloader.downloads[0], "tiny");
        verify(!button("downloadModel_base").enabled);
        verify(!button("deleteModel_base").enabled);
        verify(button("cancelModel_tiny").visible);
        waitForRendering(manager.contentItem);
        mouseClick(button("cancelModel_tiny"));
        compare(app.modelDownloader.cancels, 1);
        verify(!app.modelDownloader.isBusy);
    }
    function test_deleteUpdatesInstalledSize() {
        mouseClick(button("deleteModel_base"));
        compare(app.modelDownloader.deletions[0], "base");
        compare(app.modelDownloader.models[1].installedBytes, 0);
        verify(!button("deleteModel_base").visible);
        compare(button("downloadModel_base").text, "Download");
    }
    function test_inUseModelCannotBeDeletedOrReplaced() {
        app.modelDownloader.update("base", {
            inUse: true
        });
        verify(!button("deleteModel_base").enabled);
        verify(!button("downloadModel_base").enabled);
    }
    function test_expectedSizesUseDecimalMegabytes() {
        compare(manager.sizeLabel(77691713), "77.7 MB");
        compare(manager.sizeLabel(147951465), "148.0 MB");
    }
}
