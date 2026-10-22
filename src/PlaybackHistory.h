#ifndef PLAYBACKHISTORY_H
#define PLAYBACKHISTORY_H

#include <QObject>
#include <QSettings>
#include <QVariantList>
#include <QtQml/QQmlEngine>

class PlaybackHistory : public QObject
{
    Q_OBJECT
    QML_ELEMENT
    Q_PROPERTY(QVariantList recentFiles READ recentFiles NOTIFY recentFilesChanged)
public:
    explicit PlaybackHistory(QObject *parent = nullptr);
    QVariantList recentFiles() const;
    Q_INVOKABLE bool isAvailable(const QString &mediaUrl) const;
    Q_INVOKABLE void recordFile(const QString &mediaUrl);
    Q_INVOKABLE void refreshRecentFiles();
    Q_INVOKABLE void clearRecentFiles();
    Q_INVOKABLE void savePosition(const QString &mediaUrl, qint64 positionMs, qint64 durationMs);
    Q_INVOKABLE qint64 resumePosition(const QString &mediaUrl, qint64 durationMs = 0) const;
    Q_INVOKABLE void clearPosition(const QString &mediaUrl);
    Q_INVOKABLE void sync();
signals:
    void recentFilesChanged();
private:
    static QString normalizedUrl(const QString &mediaUrl);
    static QString positionKey(const QString &mediaUrl);
    static qint64 resumablePosition(qint64 positionMs, qint64 durationMs);
    QSettings m_settings;
    QStringList m_recentFiles;
};
#endif
