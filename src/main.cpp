#include <QApplication>
#include <QQmlApplicationEngine>
#include <QUrl>
#include <QFileInfo>
#include <QCommandLineParser>

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
    qputenv("QT_FFMPEG_HW_ALLOW_PROFILE_MISMATCH", "1");    // bypass strict profile checks to avoid software decoding fallback

    // Enable system-default high-DPI scaling
    QApplication app(argc, argv);

    app.setOrganizationName("MAPL");
    app.setOrganizationDomain("mapl.io");
    app.setApplicationName("MAPLPlayerNative");
    app.setApplicationVersion(QStringLiteral(MAPL_APP_VERSION));
    // Match the desktop launcher and provide a stable Wayland application ID
    // for icons, portal parenting and compositor window rules.
    app.setDesktopFileName(QStringLiteral("mapl-player"));

    QCommandLineParser parser;
    parser.setApplicationDescription(QStringLiteral("MAPL audio and video player"));
    parser.addHelpOption();
    parser.addVersionOption();
    parser.addPositionalArgument(QStringLiteral("file"), QStringLiteral("Media file or file URL to open."), QStringLiteral("[file]"));
    parser.process(app);

    // ── Parse startup file argument ────────────────────────────────────────
    // Dolphin / xdg-open passes the opened file as argv[1] (the %U token in
    // the .desktop Exec line). It may arrive as a file:// URL or a plain path.
    QString initialFileUrl;
    for (const QString &arg : parser.positionalArguments()) {
        QUrl url(arg);
        if (url.isLocalFile()) {
            // Already a well-formed file:// URL (Dolphin passes these)
            initialFileUrl = url.toString();
        } else {
            // Treat as a plain filesystem path (e.g. /home/user/movie.mkv)
            QFileInfo fi(arg);
            if (fi.exists())
                initialFileUrl = QUrl::fromLocalFile(fi.absoluteFilePath()).toString();
        }
        if (!initialFileUrl.isEmpty())
            break;
    }

    QQmlApplicationEngine engine;
    // Our QML module lives at :/MAPLPlayerNative, outside Qt's default
    // :/qt/qml import root. Resolve it from resources after installation too,
    // without relying on the generated qmldir beside the build executable.
    engine.addImportPath(QStringLiteral("qrc:/"));

    // Pass the startup file to the root QML object before the component is
    // instantiated, so it is available immediately in Component.onCompleted.
    if (!initialFileUrl.isEmpty())
        engine.setInitialProperties({{"initialFileUrl", initialFileUrl}});

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
