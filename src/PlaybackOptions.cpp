#include "PlaybackOptions.h"
#include <QMediaMetaData>
#include <QSettings>
#include <QLocale>
#include <QAudioDevice>
#include <QScopedValueRollback>
#include <algorithm>
#include <cmath>

PlaybackOptions::PlaybackOptions(QObject *parent) : QObject(parent)
{
    const double saved = QSettings("MAPL", "MAPLPlayerNative").value("playback/rate", 1.0).toDouble();
    if (std::isfinite(saved) && saved >= 0.25 && saved <= 3)
        m_rate = saved;
    m_syncTimer.setInterval(25);
    m_syncTimer.setTimerType(Qt::PreciseTimer);
    connect(&m_syncTimer, &QTimer::timeout, this, [this] { synchronizeAudio(false); });
}

PlaybackOptions::~PlaybackOptions()
{
    blockSignals(true);
    releaseDelayedAudio();
}

void PlaybackOptions::setPlayer(QMediaPlayer *player)
{
    if (m_player == player)
        return;
    releaseDelayedAudio();
    if (m_delayMs != 0) {
        m_delayMs = 0;
        emit audioDelayChanged();
    }
    if (m_player)
        m_player->disconnect(this);
    m_player = player;
    if (player) {
        player->setPlaybackRate(m_rate);
        connect(player, &QMediaPlayer::sourceChanged, this, [this] {
            resetAudioDelay();
            emit audioTracksChanged();
        });
        connect(player, &QMediaPlayer::tracksChanged, this, [this] {
            emit audioTracksChanged();
            synchronizeAudio(true);
        });
        connect(player, &QMediaPlayer::activeTracksChanged, this, [this] {
            emit audioTracksChanged();
            synchronizeAudio(true);
        });
        connect(player, &QMediaPlayer::seekableChanged, this, &PlaybackOptions::audioTracksChanged);
        connect(player, &QMediaPlayer::hasAudioChanged, this, &PlaybackOptions::audioTracksChanged);
        connect(player, &QMediaPlayer::playbackStateChanged, this, [this] { synchronizeAudio(true); });
        connect(player, &QMediaPlayer::mediaStatusChanged, this, [this] { synchronizeAudio(false); });
        connect(player, &QMediaPlayer::positionChanged, this, [this] { synchronizeAudio(false); });
        connect(player, &QMediaPlayer::playbackRateChanged, this, [this](qreal rate) {
            if (std::isfinite(rate) && rate >= 0.25 && rate <= 3 && !qFuzzyCompare(rate, m_rate)) {
                m_rate = rate;
                QSettings("MAPL", "MAPLPlayerNative").setValue("playback/rate", rate);
                emit rateChanged();
            }
            synchronizeAudio(true);
        });
    }
    emit playerChanged();
    emit audiblePlayerChanged();
    emit audioTracksChanged();
}

void PlaybackOptions::setAudioOutput(QAudioOutput *output)
{
    if (m_mainOutput == output)
        return;
    if (m_mainOutput)
        m_mainOutput->disconnect(this);
    m_mainOutput = output;
    if (output) {
        connect(output, &QAudioOutput::volumeChanged, this, &PlaybackOptions::mirrorOutput);
        connect(output, &QAudioOutput::mutedChanged, this, &PlaybackOptions::mirrorOutput);
        connect(output, &QAudioOutput::deviceChanged, this, &PlaybackOptions::mirrorOutput);
    }
    mirrorOutput();
    emit playerChanged();
}

QVariantList PlaybackOptions::audioTracks() const
{
    QVariantList rows;
    if (!m_player || m_player->audioTracks().isEmpty())
        return rows;
    rows.append(QVariantMap{{"index", -1}, {"label", tr("No audio")}});
    const auto tracks = m_player->audioTracks();
    for (int i = 0; i < tracks.size(); ++i) {
        const auto &metadata = tracks[i];
        const auto language = static_cast<QLocale::Language>(metadata.value(QMediaMetaData::Language).toInt());
        QString label;
        if (language > QLocale::AnyLanguage && language <= QLocale::LastLanguage)
            label = QLocale::languageToString(language);
        const QString title = metadata.value(QMediaMetaData::Title).toString();
        if (!title.isEmpty())
            label = label.isEmpty() ? title : label + " — " + title;
        if (label.isEmpty())
            label = tr("Audio track %1").arg(i + 1);
        rows.append(QVariantMap{{"index", i}, {"label", label}});
    }
    return rows;
}

int PlaybackOptions::activeAudioTrack() const
{
    return m_player ? m_player->activeAudioTrack() : -1;
}

void PlaybackOptions::selectAudioTrack(int index)
{
    if (m_player && index >= -1 && index < m_player->audioTracks().size()) {
        m_player->setActiveAudioTrack(index);
        synchronizeAudio(true);
    }
}

void PlaybackOptions::setRate(double rate)
{
    if (!std::isfinite(rate) || rate < 0.25 || rate > 3)
        return;
    const bool changed = !qFuzzyCompare(m_rate, rate);
    m_rate = rate;
    if (m_player)
        m_player->setPlaybackRate(rate);
    QSettings("MAPL", "MAPLPlayerNative").setValue("playback/rate", rate);
    if (changed)
        emit rateChanged();
    synchronizeAudio(true);
}

bool PlaybackOptions::canAdjustDelay() const
{
    return m_player && m_mainOutput && m_player->source().isLocalFile()
        && m_player->hasAudio() && m_player->isSeekable();
}

void PlaybackOptions::setAudioDelayMs(int delay)
{
    delay = std::clamp(delay, -2000, 2000);
    if (delay == m_delayMs)
        return;
    if (delay != 0 && !canAdjustDelay())
        return;
    m_delayMs = delay;
    if (delay == 0) {
        releaseDelayedAudio();
    } else {
        if (!m_audio) {
            m_output = std::make_unique<QAudioOutput>();
            // Keep the primary decoder's audio clock running, including for
            // audio-only media, while the shifted decoder supplies audible PCM.
            m_clockOutput = std::make_unique<QAudioOutput>();
            m_clockOutput->setMuted(true);
            m_clockOutput->setVolume(0);
            m_audio = std::make_unique<QMediaPlayer>();
            m_audio->setAudioOutput(m_output.get());
            m_audio->setActiveVideoTrack(-1);
            m_audio->setActiveSubtitleTrack(-1);
            connect(m_audio.get(), &QMediaPlayer::mediaStatusChanged, this, [this] { synchronizeAudio(false); });
            connect(m_audio.get(), &QMediaPlayer::seekableChanged, this, [this] { synchronizeAudio(true); });
            connect(m_audio.get(), &QMediaPlayer::tracksChanged, this, [this] {
                m_audio->setActiveVideoTrack(-1);
                m_audio->setActiveSubtitleTrack(-1);
                synchronizeAudio(true);
            });
            connect(m_audio.get(), &QMediaPlayer::errorOccurred, this, [this](QMediaPlayer::Error, const QString &error) {
                // Defer deletion until the backend has finished emitting its signal.
                QPointer<QMediaPlayer> failed = m_audio.get();
                QMetaObject::invokeMethod(this, [this, error, failed] {
                    if (failed && failed == m_audio.get() && m_delayMs != 0) {
                        resetAudioDelay();
                        emit adjustmentError(tr("Audio delay was reset: %1").arg(error));
                    }
                }, Qt::QueuedConnection);
            });
            mirrorOutput();
            // Detach first: the old output's disconnect callback can otherwise
            // clear the replacement during QMediaPlayer's output handoff.
            m_player->setAudioOutput(nullptr);
            m_player->setAudioOutput(m_clockOutput.get());
            m_audio->setSource(m_player->source());
            emit audiblePlayerChanged();
        }
        synchronizeAudio(true);
    }
    emit audioDelayChanged();
}

void PlaybackOptions::resetAudioDelay()
{
    setAudioDelayMs(0);
}

void PlaybackOptions::releaseDelayedAudio()
{
    m_syncTimer.stop();
    m_forceSyncPending = false;
    if (m_audio) {
        m_audio->disconnect(this);
        m_audio->stop();
        m_audio.reset();
        m_output.reset();
        if (m_player && m_mainOutput) {
            m_player->setAudioOutput(nullptr);
            m_player->setAudioOutput(m_mainOutput);
        }
        m_clockOutput.reset();
        emit audiblePlayerChanged();
    }
}

void PlaybackOptions::mirrorOutput()
{
    if (m_mainOutput && m_output) {
        m_output->setVolume(m_mainOutput->volume());
        m_output->setMuted(m_mainOutput->isMuted());
        m_output->setDevice(m_mainOutput->device());
        if (m_clockOutput)
            m_clockOutput->setDevice(m_mainOutput->device());
    }
}

void PlaybackOptions::synchronize()
{
    synchronizeAudio(true);
}

void PlaybackOptions::synchronizeAudio(bool force)
{
    if (force)
        m_forceSyncPending = true;
    if (m_syncing || !m_audio || !m_player || m_delayMs == 0)
        return;
    QScopedValueRollback guard(m_syncing, true);
    const bool playing = m_player->playbackState() == QMediaPlayer::PlayingState;
    if (playing && !m_syncTimer.isActive())
        m_syncTimer.start();
    else if (!playing)
        m_syncTimer.stop();
    if (m_player->mediaStatus() == QMediaPlayer::EndOfMedia || m_player->mediaStatus() == QMediaPlayer::InvalidMedia) {
        m_audio->stop();
        m_syncTimer.stop();
        return;
    }
    const auto status = m_audio->mediaStatus();
    if (status != QMediaPlayer::LoadedMedia && status != QMediaPlayer::BufferingMedia
        && status != QMediaPlayer::BufferedMedia && status != QMediaPlayer::EndOfMedia)
        return;
    if (!m_audio->isSeekable())
        return;
    if (!qFuzzyCompare(m_audio->playbackRate(), m_player->playbackRate()))
        m_audio->setPlaybackRate(m_player->playbackRate());
    if (m_audio->activeAudioTrack() != m_player->activeAudioTrack())
        m_audio->setActiveAudioTrack(m_player->activeAudioTrack());
    // Delay is wall-clock milliseconds, including when playback rate changes.
    const qint64 target = m_player->position() - qRound64(m_delayMs * m_player->playbackRate());
    if (target < 0 || target >= m_audio->duration() || !playing) {
        if (m_audio->playbackState() == QMediaPlayer::PlayingState)
            m_audio->pause();
        const auto clamped = std::clamp<qint64>(target, 0, m_audio->duration());
        if (std::abs(m_audio->position() - clamped) > (m_forceSyncPending ? 0 : 100))
            m_audio->setPosition(clamped);
    } else {
        if (std::abs(m_audio->position() - target) > (m_forceSyncPending ? 0 : 100))
            m_audio->setPosition(target);
        if (m_audio->playbackState() != QMediaPlayer::PlayingState)
            m_audio->play();
    }
    m_forceSyncPending = false;
}
