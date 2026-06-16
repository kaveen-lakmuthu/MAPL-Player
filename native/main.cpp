#include <QApplication>
#include <QQmlApplicationEngine>

int main(int argc, char *argv[]) {
    // Enable system-default high-DPI scaling
    QApplication app(argc, argv);
    
    app.setOrganizationName("MAPL");
    app.setOrganizationDomain("mapl.io");
    app.setApplicationName("MAPLPlayerNative");

    QQmlApplicationEngine engine;
    
    // Qt 6 QML module resource loading URL
    const QUrl url(QStringLiteral("qrc:/MAPLPlayerNative/main.qml"));
    
    QObject::connect(&engine, &QQmlApplicationEngine::objectCreated,
                     &app, [url](QObject *obj, const QUrl &objUrl) {
        if (!obj && url == objUrl)
            QCoreApplication::exit(-1);
    }, Qt::QueuedConnection);
    
    engine.load(url);

    return app.exec();
}
