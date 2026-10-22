#include <QCoreApplication>
#include <QFile>
#include <QJsonDocument>
#include <QJsonObject>
#include <QTimer>

// Deterministic stand-in for ffprobe/ffmpeg. It is a real child process, so tests
// exercise Qt process start, cancellation, timeout, exit and file cleanup.
int main(int argc, char **argv)
{
    QCoreApplication app(argc, argv);
    const auto args = app.arguments();
    const bool chapters = args.contains("-show_chapters");
    const QString input = chapters ? args.last() : args.value(args.indexOf("-i") + 1);
    QFile configFile(input);
    if (!configFile.open(QIODevice::ReadOnly))
        return 2;
    const auto config = QJsonDocument::fromJson(configFile.readAll()).object();
    const QString output = chapters ? QString() : args.last();
    if (!chapters) {
        QFile partial(output);
        if (!partial.open(QIODevice::WriteOnly))
            return 3;
        partial.write("partial");
    }
    QFile marker(config.value("marker").toString());
    if (marker.open(QIODevice::WriteOnly)) {
        marker.write(QJsonDocument(QJsonObject{{"pid", app.applicationPid()}, {"output", output}}).toJson());
        marker.close();
    }
    QTimer::singleShot(config.value("delay").toInt(20), &app, [&] {
        const QByteArray content = config.value("output").toString().toUtf8();
        QFile result;
        bool opened;
        if (chapters)
            opened = result.open(stdout, QIODevice::WriteOnly);
        else {
            result.setFileName(output);
            opened = result.open(QIODevice::WriteOnly | QIODevice::Truncate);
        }
        if (!opened) {
            app.exit(3);
            return;
        }
        result.write(content);
        result.close();
        app.exit(config.value("exit").toInt());
    });
    return app.exec();
}
