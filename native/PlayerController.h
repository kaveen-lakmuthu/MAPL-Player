#ifndef PLAYERCONTROLLER_H
#define PLAYERCONTROLLER_H

#include <QObject>
#include <QVideoSink>
#include <QVideoFrame>
#include <QImage>
#include <QColor>
#include <QSettings>
#include <QDateTime>
#include <QBuffer>
#include <QtQml/QQmlEngine>
#include <QProcess>

class PlayerController : public QObject
{
    Q_OBJECT
    Q_PROPERTY(QVideoSink* videoSink READ videoSink WRITE setVideoSink NOTIFY videoSinkChanged)
    Q_PROPERTY(QString currentTrackTitle READ currentTrackTitle WRITE setCurrentTrackTitle NOTIFY currentTrackTitleChanged)
    QML_ELEMENT // Expose to QML automatically in Qt6

public:
    explicit PlayerController(QObject *parent = nullptr);
    ~PlayerController();

    QVideoSink* videoSink() const;
    void setVideoSink(QVideoSink* sink);

    QString currentTrackTitle() const;
    void setCurrentTrackTitle(const QString &title);

    // PERSISTENCE AND UI HELPERS
    Q_INVOKABLE void saveVolume(int volume);
    Q_INVOKABLE int loadVolume() const;
    Q_INVOKABLE void saveLoop(bool loop);
    Q_INVOKABLE bool loadLoop() const;
    
    Q_INVOKABLE void captureThumbnail(const QString &trackUrl);
    Q_INVOKABLE QString getThumbnail(const QString &trackUrl) const;
    
    Q_INVOKABLE QString getCleanFileName(const QString &filePath) const;
    Q_INVOKABLE bool writeTextToFile(const QString &filePath, const QString &content);
    Q_INVOKABLE void generateTimelinePreviews(const QString &trackUrl, double durationSec);

signals:
    void videoSinkChanged();
    void currentTrackTitleChanged();
    void backgroundColorChanged(const QString &hexColor);
    void thumbnailCaptured(const QString &trackUrl, const QString &base64Image);
    void timelinePreviewsReady(const QString &trackUrl, const QString &spriteSheetPath);

private slots:
    void handleVideoFrame(const QVideoFrame &frame);

private:
    QVideoSink* m_videoSink;
    QString m_currentTrackTitle;
    QImage m_lastImage;
    qint64 m_lastFrameTime;
    
    QProcess* m_previewProcess;
    QString m_currentPreviewTrack;
    QString m_currentPreviewPath;
};

#endif // PLAYERCONTROLLER_H
