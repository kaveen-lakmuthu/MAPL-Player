#ifndef MEDIAFIXTURE_H
#define MEDIAFIXTURE_H
#include <QTemporaryDir>
#include <QFile>
#include <QDataStream>
#include <QUrl>

struct MediaFixture {
    QTemporaryDir directory;
    QString path;
    MediaFixture() {
        path = directory.filePath("Audio #100%.wav");
        QFile file(path);
        if (!file.open(QIODevice::WriteOnly)) return;
        const QByteArray data(60 * 8000 * 2, char(0));
        QDataStream stream(&file);
        stream.setByteOrder(QDataStream::LittleEndian);
        stream.writeRawData("RIFF", 4);
        stream << quint32(36 + data.size());
        stream.writeRawData("WAVEfmt ", 8);
        stream << quint32(16) << quint16(1) << quint16(1) << quint32(8000)
               << quint32(16000) << quint16(2) << quint16(16);
        stream.writeRawData("data", 4);
        stream << quint32(data.size());
        stream.writeRawData(data.constData(), data.size());
    }
    QUrl url() const { return QUrl::fromLocalFile(path); }
};
#endif
