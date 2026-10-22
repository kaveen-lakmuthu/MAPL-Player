#ifndef PROCESSFIXTURE_H
#define PROCESSFIXTURE_H
#include <QFile>
#include <QJsonDocument>
#include <QJsonObject>
#include <QTemporaryDir>
#ifdef Q_OS_UNIX
#include <cerrno>
#include <csignal>
#endif

struct ProcessFixture {
    QTemporaryDir directory;
    QString input;
    QString marker;
    ProcessFixture(int delay = 20, int exitCode = 0, const QString &output = "audio")
    {
        input = directory.filePath("media.mp4");
        marker = directory.filePath("started.json");
        QFile file(input);
        if (file.open(QIODevice::WriteOnly))
            file.write(QJsonDocument(QJsonObject{{"delay", delay}, {"exit", exitCode},
                                                 {"output", output}, {"marker", marker}}).toJson());
    }
    QJsonObject info() const
    {
        QFile file(marker);
        if (!file.open(QIODevice::ReadOnly))
            return {};
        return QJsonDocument::fromJson(file.readAll()).object();
    }
    bool started() const { return info().contains("pid"); }
    QString outputPath() const { return info().value("output").toString(); }
    bool reaped() const
    {
#ifdef Q_OS_UNIX
        const auto pid = info().value("pid").toInteger();
        return pid > 0 && ::kill(pid, 0) == -1 && errno == ESRCH;
#else
        return true;
#endif
    }
};
#endif
