#ifndef MPRISSERVICE_H
#define MPRISSERVICE_H
#include <QObject>
#include <QPointer>
#include <QMediaPlayer>
#include <QAudioOutput>
#include <QWindow>
#include <QDBusConnection>
#include <QDBusObjectPath>
#include <QVariantMap>
#include <QTimer>
#include <QtQml/QQmlEngine>

class MprisRootAdaptor;
class MprisPlayerAdaptor;
class MprisService : public QObject
{
    Q_OBJECT
    QML_ELEMENT
    Q_PROPERTY(QMediaPlayer *player READ player WRITE setPlayer NOTIFY stateChanged)
    Q_PROPERTY(QAudioOutput *audioOutput READ audioOutput WRITE setAudioOutput NOTIFY stateChanged)
    Q_PROPERTY(QWindow *applicationWindow READ window WRITE setWindow NOTIFY stateChanged)
    Q_PROPERTY(int playlistCount READ playlistCount WRITE setPlaylistCount NOTIFY stateChanged)
    Q_PROPERTY(int trackIndex READ trackIndex WRITE setTrackIndex NOTIFY stateChanged)
    Q_PROPERTY(int trackRevision READ trackRevision WRITE setTrackRevision NOTIFY stateChanged)
    Q_PROPERTY(QString trackTitle READ trackTitle WRITE setTrackTitle NOTIFY stateChanged)
    Q_PROPERTY(QUrl trackUrl READ trackUrl WRITE setTrackUrl NOTIFY stateChanged)
    Q_PROPERTY(QString artUrl READ artUrl WRITE setArtUrl NOTIFY stateChanged)
    Q_PROPERTY(bool looping READ looping WRITE setLooping NOTIFY stateChanged)
    Q_PROPERTY(QString serviceName READ serviceName NOTIFY connectionChanged)
public:
    explicit MprisService(QObject *parent = nullptr);
    ~MprisService() override;
    QMediaPlayer *player() const { return m_player; }
    void setPlayer(QMediaPlayer *player);
    QAudioOutput *audioOutput() const { return m_output; }
    void setAudioOutput(QAudioOutput *output);
    QWindow *window() const { return m_window; }
    void setWindow(QWindow *window);
    int playlistCount() const { return m_count; }
    void setPlaylistCount(int count);
    int trackIndex() const { return m_index; }
    void setTrackIndex(int index);
    int trackRevision() const { return m_revision; }
    void setTrackRevision(int revision);
    QString trackTitle() const { return m_title; }
    void setTrackTitle(const QString &title);
    QUrl trackUrl() const { return m_url; }
    void setTrackUrl(const QUrl &url);
    QString artUrl() const { return m_art; }
    void setArtUrl(const QString &url);
    bool looping() const { return m_loop; }
    void setLooping(bool looping);
    QString serviceName() const { return m_serviceName; }
    Q_INVOKABLE bool start();
    Q_INVOKABLE void stop();
    Q_INVOKABLE void seekToMs(qint64 position);
    QString playbackStatus() const;
    QVariantMap metadata() const;
    QDBusObjectPath trackId() const;
    bool canPlay() const { return m_count > 0; }
    bool hasTrack() const { return m_index >= 0 && m_index < m_count && !m_url.isEmpty(); }
    bool canNext() const { return hasTrack() && (m_index + 1 < m_count || m_loop); }
    bool canPrevious() const { return hasTrack() && (m_index > 0 || m_loop); }
    bool canSeek() const { return hasTrack() && m_player && m_player->isSeekable(); }
    QStringList supportedMimeTypes() const;
    void seekRelativeUs(qint64 offset);
    void setPositionUs(const QDBusObjectPath &trackId, qint64 position);
    bool acceptsUri(const QString &uri) const;
    void publish();
    QDBusConnection bus() const { return m_bus; }
signals:
    void stateChanged();
    void connectionChanged();
    void playRequested();
    void pauseRequested();
    void toggleRequested();
    void stopRequested();
    void nextRequested();
    void previousRequested();
    void openUriRequested(const QString &uri);
    void rateRequested(double rate);
    void volumeRequested(double volume);
    void quitRequested();
    void seeked(qint64 microseconds);
private:
    QPointer<QMediaPlayer> m_player;
    QPointer<QAudioOutput> m_output;
    QPointer<QWindow> m_window;
    QDBusConnection m_bus{QString()};
    QString m_connectionName;
    QString m_serviceName;
    int m_count = 0;
    int m_index = -1;
    int m_revision = 0;
    QString m_title;
    QUrl m_url;
    QString m_art;
    bool m_loop = false;
    QTimer m_updateTimer;
    QVariantMap m_lastPlayer;
    QVariantMap m_lastRoot;
    void changed();
};
#endif
