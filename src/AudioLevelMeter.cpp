#include "AudioLevelMeter.h"
#include <algorithm>
#include <cmath>
#include <limits>
#include <complex>
#include <numbers>

namespace {
// In-place radix-2 FFT; all storage is bounded by the analysis window.
template<size_t Size>
void fft(std::array<std::complex<double>, Size> &values)
{
    for (size_t i = 1, j = 0; i < Size; ++i) {
        size_t bit = Size >> 1;
        for (; j & bit; bit >>= 1)
            j ^= bit;
        j ^= bit;
        if (i < j)
            std::swap(values[i], values[j]);
    }
    for (size_t length = 2; length <= Size; length <<= 1) {
        const auto step = std::polar(1.0, -2 * std::numbers::pi / length);
        for (size_t start = 0; start < Size; start += length) {
            std::complex<double> phase = 1;
            for (size_t j = 0; j < length / 2; ++j) {
                const auto even = values[start + j];
                const auto odd = values[start + j + length / 2] * phase;
                values[start + j] = even + odd;
                values[start + j + length / 2] = even - odd;
                phase *= step;
            }
        }
    }
}
}

AudioLevelMeter::AudioLevelMeter(QObject *parent) : QObject(parent)
{
    for (int i = 0; i < FftSize; ++i) {
        m_window[i] = .5 * (1 - std::cos(2 * std::numbers::pi * i / (FftSize - 1)));
        m_windowPower += m_window[i] * m_window[i];
    }
    m_staleTimer.setSingleShot(true);
    connect(&m_staleTimer, &QTimer::timeout, this, [this] {
        m_rms = m_peak = 0;
        resetSpectrum();
        emit levelsChanged();
    });
}

AudioLevelMeter::~AudioLevelMeter()
{
    detach();
}

void AudioLevelMeter::setPlayer(QMediaPlayer *player)
{
    if (m_player == player)
        return;
    detach();
    if (m_player)
        m_player->disconnect(this);
    m_player = player;
    if (player) {
        connect(player, &QMediaPlayer::audioOutputChanged, this, &AudioLevelMeter::watchOutput);
        connect(player, &QMediaPlayer::sourceChanged, this, &AudioLevelMeter::clear);
        connect(player, &QMediaPlayer::activeTracksChanged, this, &AudioLevelMeter::clear);
        connect(player, &QMediaPlayer::playbackStateChanged, this, [this](QMediaPlayer::PlaybackState state) {
            if (state != QMediaPlayer::PlayingState)
                clear();
        });
        connect(player, &QObject::destroyed, this, [this] {
            watchOutput();
            clear();
            emit playerChanged();
        });
    }
    watchOutput();
    attach();
    emit playerChanged();
}

void AudioLevelMeter::setEnabled(bool enabled)
{
    if (m_enabled == enabled)
        return;
    m_enabled = enabled;
    if (enabled)
        attach();
    else
        detach();
    emit enabledChanged();
}

void AudioLevelMeter::attach()
{
#if QT_VERSION >= QT_VERSION_CHECK(6, 8, 0)
    if (m_enabled && m_player && !m_bufferOutput) {
        m_bufferOutput = std::make_unique<QAudioBufferOutput>();
        connect(m_bufferOutput.get(), &QAudioBufferOutput::audioBufferReceived, this, &AudioLevelMeter::processBuffer);
        m_player->setAudioBufferOutput(m_bufferOutput.get());
    }
#endif
}

void AudioLevelMeter::detach()
{
#if QT_VERSION >= QT_VERSION_CHECK(6, 8, 0)
    if (m_player && m_bufferOutput && m_player->audioBufferOutput() == m_bufferOutput.get())
        m_player->setAudioBufferOutput(nullptr);
    m_bufferOutput.reset();
#endif
    clear();
}

void AudioLevelMeter::watchOutput()
{
    if (m_output)
        m_output->disconnect(this);
    m_output = m_player ? m_player->audioOutput() : nullptr;
    if (m_output) {
        connect(m_output, &QAudioOutput::volumeChanged, this, &AudioLevelMeter::levelsChanged);
        connect(m_output, &QAudioOutput::mutedChanged, this, &AudioLevelMeter::levelsChanged);
        connect(m_output, &QObject::destroyed, this, &AudioLevelMeter::levelsChanged);
    }
    emit levelsChanged();
}

double AudioLevelMeter::gain() const
{
    return m_enabled && m_player && m_player->playbackState() == QMediaPlayer::PlayingState && m_output && !m_output->isMuted()
        ? m_output->volume() : 0;
}

double AudioLevelMeter::rms() const { return m_rms * gain(); }
double AudioLevelMeter::peak() const { return m_peak * gain(); }

QVariantList AudioLevelMeter::spectrum() const
{
    QVariantList result;
    result.reserve(BandCount);
    const double volume = gain();
    for (const double band : m_bands)
        result.append(band * volume);
    return result;
}

void AudioLevelMeter::resetSpectrum()
{
    m_bands.fill(0);
    m_samplePosition = m_sampleCount = m_framesSinceSpectrum = 0;
}

void AudioLevelMeter::analyzeSpectrum()
{
    std::array<double, FftSize / 2 + 1> power{};
    std::array<std::complex<double>, FftSize> work;
    for (const auto &channel : m_samples) {
        for (int i = 0; i < FftSize; ++i)
            work[i] = channel[(m_samplePosition + i) % FftSize] * m_window[i];
        fft(work);
        for (int bin = 1; bin <= FftSize / 2; ++bin)
            power[bin] += std::norm(work[bin]);
    }
    m_bands.fill(0);
    const double low = 40;
    const double high = std::min(16000.0, m_sampleRate / 2.0);
    if (high <= low)
        return;
    const double logRange = std::log(high / low);
    for (int bin = 1; bin <= FftSize / 2; ++bin) {
        const double frequency = double(bin) * m_sampleRate / FftSize;
        if (frequency < low || frequency > high)
            continue;
        const int band = std::min(BandCount - 1, int(std::log(frequency / low) / logRange * BandCount));
        m_bands[band] += power[bin] * (bin == FftSize / 2 ? 1 : 2);
    }
    // Average channel powers instead of mixing samples: opposite-phase stereo
    // and center-channel dialogue must still appear in the visualizer.
    const double normalization = FftSize * m_windowPower * m_samples.size();
    for (double &band : m_bands)
        band = std::min(1.0, std::sqrt(band / normalization));
}

void AudioLevelMeter::clear()
{
    m_staleTimer.stop();
    m_rms = m_peak = 0;
    m_available = false;
    resetSpectrum();
    emit levelsChanged();
}

void AudioLevelMeter::processBuffer(const QAudioBuffer &buffer)
{
    if (!m_enabled || !m_player || m_player->playbackState() != QMediaPlayer::PlayingState)
        return;
    if (!buffer.isValid() || buffer.sampleCount() == 0) {
        clear();
        return;
    }
    const auto format = buffer.format();
    const int stride = format.bytesPerSample();
    if (!format.isValid() || stride <= 0) {
        clear();
        return;
    }
    const auto *samples = buffer.constData<char>();
    const int channels = format.channelCount();
    if (m_sampleRate != format.sampleRate() || int(m_samples.size()) != channels) {
        resetSpectrum();
        m_sampleRate = format.sampleRate();
        m_samples.resize(channels);
    }
    double sum = 0;
    double peak = 0;
    // Include every channel, so dialogue in a surround center channel counts.
    for (qsizetype i = 0; i < buffer.sampleCount(); ++i) {
        // Unsigned PCM has an exact silence point at 128. Normalize around it,
        // rather than the midpoint of 0..255, which gives silence a DC offset.
        double sample = format.sampleFormat() == QAudioFormat::UInt8
            ? (double(static_cast<unsigned char>(samples[i])) - 128.0) / 128.0
            : format.normalizedSampleValue(samples + i * stride);
        if (!std::isfinite(sample))
            sample = 0;
        sample = std::clamp(sample, -1.0, 1.0);
        sum += sample * sample;
        peak = std::max(peak, std::abs(sample));
        m_samples[i % channels][m_samplePosition] = sample;
        if ((i + 1) % channels == 0) {
            m_samplePosition = (m_samplePosition + 1) % FftSize;
            m_sampleCount = std::min(FftSize, m_sampleCount + 1);
            ++m_framesSinceSpectrum;
        }
    }
    m_rms = std::sqrt(sum / buffer.sampleCount());
    m_peak = peak;
    if (m_sampleCount == FftSize && m_framesSinceSpectrum >= FftSize / 4) {
        analyzeSpectrum();
        m_framesSinceSpectrum = 0;
    }
    m_available = true;
    const auto timeoutMs = buffer.duration() / (1000 * std::max(0.25, m_player->playbackRate())) + 100;
    m_staleTimer.start(int(std::clamp(timeoutMs, 250.0, double(std::numeric_limits<int>::max()))));
    emit levelsChanged();
}
