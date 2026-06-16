#include <QApplication>
#include <QQmlApplicationEngine>

int main(int argc, char *argv[]) {
    // ── Suppress VA-API hardware acceleration noise ────────────────────────
    // Qt6's FFmpeg multimedia backend probes VA-API on Linux. When the driver
    // doesn't support a specific H.264 profile (e.g. High / profile 100) it
    // prints errors like:
    //   "No support for codec h264 profile 100"
    //   "Failed setup for format vaapi: hwaccel initialisation returned error"
    //   "Late SEI is not implemented"
    // These are harmless — the backend falls back to software decoding — but
    // noisy. Setting LIBVA_DRIVER_NAME to an empty string causes libva to skip
    // driver discovery entirely, preventing the VA-API probe before Qt starts.
    // qputenv("LIBVA_DRIVER_NAME", "");           // disable VA-API driver discovery
    // qputenv("LIBVA_DRIVERS_PATH", "/dev/null"); // belt-and-suspenders
    qputenv("QML_XHR_ALLOW_FILE_READ", "1");    // allow QML XMLHttpRequest to read local files (e.g. XSPF playlists)
    qputenv("QT_FFMPEG_DECODING_HW_DEVICE_TYPES", "vaapi"); // force Qt Multimedia FFmpeg backend to use VA-API hardware decoding

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
