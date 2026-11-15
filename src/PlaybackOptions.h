#ifndef PLAYBACKOPTIONS_H
#define PLAYBACKOPTIONS_H
#include <QObject>
#include <QPointer>
#include <QMediaPlayer>
#include <QAudioOutput>
#include <QTimer>
#include <QVariantList>
#include <QtQml/QQmlEngine>
#include <memory>

class PlaybackOptions : public QObject
{
    Q_OBJECT
    QML_ELEMENT
    Q_PROPERTY(QMediaPlayer *player READ player WRITE setPlayer NOTIFY playerChanged)
    Q_PROPERTY(QMediaPlayer *audiblePlayer READ audiblePlayer NOTIFY audiblePlayerChanged)
    Q_PROPERTY(QAudioOutput *audioOutput READ audioOutput WRITE setAudioOutput NOTIFY playerChanged)
    Q_PROPERTY(QVariantList audioTracks READ audioTracks NOTIFY audioTracksChanged)
    Q_PROPERTY(int activeAudioTrack READ activeAudioTrack NOTIFY audioTracksChanged)
    Q_PROPERTY(double rate READ rate WRITE setRate NOTIFY rateChanged)
    Q_PROPERTY(int audioDelayMs READ audioDelayMs WRITE setAudioDelayMs NOTIFY audioDelayChanged)
    Q_PROPERTY(bool canAdjustDelay READ canAdjustDelay NOTIFY audioTracksChanged)
public:
    explicit PlaybackOptions(QObject *parent = nullptr);
    ~PlaybackOptions() override;
    QMediaPlayer *player() const { return m_player; }
    QMediaPlayer *audiblePlayer() const { return m_audio ? m_audio.get() : m_player.data(); }
    void setPlayer(QMediaPlayer *player);
    QAudioOutput *audioOutput() const { return m_mainOutput; }
    void setAudioOutput(QAudioOutput *output);
    QVariantList audioTracks() const;
    int activeAudioTrack() const;
    double rate() const { return m_rate; }
    void setRate(double rate);
    int audioDelayMs() const { return m_delayMs; }
    void setAudioDelayMs(int delay);
    bool canAdjustDelay() const;
    Q_INVOKABLE void selectAudioTrack(int index);
    Q_INVOKABLE void resetAudioDelay();
    Q_INVOKABLE void synchronize();
signals:
    void playerChanged();
    void audiblePlayerChanged();
    void audioTracksChanged();
    void rateChanged();
    void audioDelayChanged();
    void adjustmentError(const QString &message);
private:
    friend class PlaybackOptionsTest;
    void releaseDelayedAudio();
    void mirrorOutput();
    void synchronizeAudio(bool force);
    QPointer<QMediaPlayer> m_player;
    QPointer<QAudioOutput> m_mainOutput;
    std::unique_ptr<QMediaPlayer> m_audio;
    std::unique_ptr<QAudioOutput> m_output;
    std::unique_ptr<QAudioOutput> m_clockOutput;
    QTimer m_syncTimer;
    double m_rate = 1;
    int m_delayMs = 0;
    bool m_syncing = false;
    bool m_forceSyncPending = false;
};
#endif
