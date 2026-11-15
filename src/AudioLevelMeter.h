#ifndef AUDIOLEVELMETER_H
#define AUDIOLEVELMETER_H

#include <QObject>
#include <QPointer>
#include <QMediaPlayer>
#include <QAudioOutput>
#include <QAudioBuffer>
#include <QTimer>
#include <QtQml/QQmlEngine>
#include <memory>
#include <array>
#include <vector>
#include <QVariantList>
#if QT_VERSION >= QT_VERSION_CHECK(6, 8, 0)
#include <QAudioBufferOutput>
#endif

// Observes decoded PCM without creating another player or changing audio routing.
class AudioLevelMeter : public QObject
{
    Q_OBJECT
    QML_ELEMENT
    Q_PROPERTY(QMediaPlayer *player READ player WRITE setPlayer NOTIFY playerChanged)
    Q_PROPERTY(bool enabled READ enabled WRITE setEnabled NOTIFY enabledChanged)
    Q_PROPERTY(bool available READ available NOTIFY levelsChanged)
    Q_PROPERTY(double rms READ rms NOTIFY levelsChanged)
    Q_PROPERTY(double peak READ peak NOTIFY levelsChanged)
    Q_PROPERTY(QVariantList spectrum READ spectrum NOTIFY levelsChanged)
public:
    explicit AudioLevelMeter(QObject *parent = nullptr);
    ~AudioLevelMeter() override;
    QMediaPlayer *player() const { return m_player; }
    void setPlayer(QMediaPlayer *player);
    bool enabled() const { return m_enabled; }
    void setEnabled(bool enabled);
    bool available() const { return m_available; }
    double rms() const;
    double peak() const;
    QVariantList spectrum() const;
    Q_INVOKABLE void clear();
signals:
    void playerChanged();
    void enabledChanged();
    void levelsChanged();
private:
    friend class AudioLevelMeterTest;
    void attach();
    void detach();
    void watchOutput();
    void processBuffer(const QAudioBuffer &buffer);
    void resetSpectrum();
    void analyzeSpectrum();
    double gain() const;
    static constexpr int FftSize = 4096;
    static constexpr int BandCount = 24;
    QPointer<QMediaPlayer> m_player;
    QPointer<QAudioOutput> m_output;
#if QT_VERSION >= QT_VERSION_CHECK(6, 8, 0)
    std::unique_ptr<QAudioBufferOutput> m_bufferOutput;
#endif
    QTimer m_staleTimer;
    bool m_enabled = true;
    bool m_available = false;
    double m_rms = 0;
    double m_peak = 0;
    std::array<double, BandCount> m_bands{};
    std::array<double, FftSize> m_window{};
    double m_windowPower = 0;
    std::vector<std::array<double, FftSize>> m_samples;
    int m_sampleRate = 0;
    int m_samplePosition = 0;
    int m_sampleCount = 0;
    int m_framesSinceSpectrum = 0;
};
#endif
