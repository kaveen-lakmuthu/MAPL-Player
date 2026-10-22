#include "MprisService.h"
#include "MprisAdaptors.h"
#include <QCoreApplication>
#include <QCryptographicHash>
#include <QDBusMessage>
#include <QFileInfo>
#include <QMediaMetaData>
#include <algorithm>

namespace {
constexpr auto objectPath = "/org/mpris/MediaPlayer2";
constexpr auto playerInterface = "org.mpris.MediaPlayer2.Player";
constexpr auto rootInterface = "org.mpris.MediaPlayer2";
int nextConnection = 0;
}

MprisService::MprisService(QObject *parent) : QObject(parent)
{
    new MprisRootAdaptor(this);
    new MprisPlayerAdaptor(this);
    m_updateTimer.setSingleShot(true);
    connect(&m_updateTimer, &QTimer::timeout, this, &MprisService::publish);
}

MprisService::~MprisService() { stop(); }

bool MprisService::start()
{
    if (!m_serviceName.isEmpty())
        return true;
    m_connectionName = "mapl-mpris-" + QString::number(++nextConnection);
    m_bus = QDBusConnection::connectToBus(QDBusConnection::SessionBus, m_connectionName);
    if (!m_bus.isConnected()) {
        QDBusConnection::disconnectFromBus(m_connectionName);
        m_connectionName.clear();
        return false;
    }
    const QString base = "org.mpris.MediaPlayer2.mapl_player";
    QString name = base;
    bool registered = false;
    for (int i = 0; i < 100 && !registered; ++i) {
        if (i > 0)
            name = base + ".instance" + QString::number(QCoreApplication::applicationPid()) + '_' + QString::number(i);
        registered = m_bus.registerService(name);
    }
    if (!registered || !m_bus.registerObject(objectPath, this, QDBusConnection::ExportAdaptors)) {
        if (registered) m_bus.unregisterService(name);
        QDBusConnection::disconnectFromBus(m_connectionName);
        return false;
    }
    m_serviceName = name;
    m_lastPlayer.clear(); m_lastRoot.clear();
    emit connectionChanged();
    changed();
    return true;
}

void MprisService::stop()
{
    m_updateTimer.stop();
    if (!m_serviceName.isEmpty()) {
        m_bus.unregisterObject(objectPath);
        m_bus.unregisterService(m_serviceName);
        m_serviceName.clear();
    }
    if (!m_connectionName.isEmpty()) {
        QDBusConnection::disconnectFromBus(m_connectionName);
        m_connectionName.clear();
    }
    emit connectionChanged();
}

void MprisService::changed()
{
    emit stateChanged();
    if (!m_serviceName.isEmpty() && !m_updateTimer.isActive())
        m_updateTimer.start(0);
}

void MprisService::setPlayer(QMediaPlayer *player)
{
    if (m_player == player) return;
    if (m_player) m_player->disconnect(this);
    m_player = player;
    if (player) {
        connect(player, &QMediaPlayer::playbackStateChanged, this, &MprisService::changed);
        connect(player, &QMediaPlayer::durationChanged, this, &MprisService::changed);
        connect(player, &QMediaPlayer::metaDataChanged, this, &MprisService::changed);
        connect(player, &QMediaPlayer::seekableChanged, this, &MprisService::changed);
        connect(player, &QMediaPlayer::playbackRateChanged, this, &MprisService::changed);
        connect(player, &QObject::destroyed, this, &MprisService::changed);
    }
    changed();
}
void MprisService::setAudioOutput(QAudioOutput *output)
{
    if (m_output == output) return;
    if (m_output) m_output->disconnect(this);
    m_output = output;
    if (output) {
        connect(output, &QAudioOutput::volumeChanged, this, &MprisService::changed);
        connect(output, &QAudioOutput::mutedChanged, this, &MprisService::changed);
    }
    changed();
}
void MprisService::setWindow(QWindow *window)
{
    if (m_window == window) return;
    if (m_window) m_window->disconnect(this);
    m_window = window;
    if (window) connect(window, &QObject::destroyed, this, &MprisService::changed);
    changed();
}
void MprisService::setPlaylistCount(int value) { if (m_count != value) { m_count = value; changed(); } }
void MprisService::setTrackIndex(int value) { if (m_index != value) { m_index = value; changed(); } }
void MprisService::setTrackRevision(int value) { if (m_revision != value) { m_revision = value; changed(); } }
void MprisService::setTrackTitle(const QString &value) { if (m_title != value) { m_title = value; changed(); } }
void MprisService::setTrackUrl(const QUrl &value) { if (m_url != value) { m_url = value; changed(); } }
void MprisService::setArtUrl(const QString &value) { if (m_art != value) { m_art = value; changed(); } }
void MprisService::setLooping(bool value) { if (m_loop != value) { m_loop = value; changed(); } }

QString MprisService::playbackStatus() const
{
    if (!hasTrack() || !m_player) return "Stopped";
    if (m_player->playbackState() == QMediaPlayer::PlayingState) return "Playing";
    if (m_player->playbackState() == QMediaPlayer::PausedState) return "Paused";
    return "Stopped";
}

QDBusObjectPath MprisService::trackId() const
{
    if (!hasTrack()) return QDBusObjectPath("/org/mpris/MediaPlayer2/TrackList/NoTrack");
    const auto hash = QCryptographicHash::hash(m_url.toEncoded() + ':' + QByteArray::number(m_revision), QCryptographicHash::Sha256).toHex();
    return QDBusObjectPath("/org/mpris/MediaPlayer2/track/t" + QString::fromLatin1(hash));
}

QVariantMap MprisService::metadata() const
{
    if (!hasTrack()) return {};
    const auto data = m_player ? m_player->metaData() : QMediaMetaData();
    const auto title = data.value(QMediaMetaData::Title).toString();
    QVariantMap map{{"mpris:trackid", QVariant::fromValue(trackId())}, {"xesam:url", m_url.toString()},
                    {"xesam:title", title.isEmpty() ? m_title : title}};
    if (m_player && m_player->duration() > 0)
        map["mpris:length"] = QVariant::fromValue<qlonglong>(m_player->duration() * 1000);
    const auto artists = data.value(QMediaMetaData::ContributingArtist).toStringList();
    if (!artists.isEmpty()) map["xesam:artist"] = artists;
    const auto album = data.value(QMediaMetaData::AlbumTitle).toString();
    if (!album.isEmpty()) map["xesam:album"] = album;
    if (!m_art.isEmpty()) map["mpris:artUrl"] = m_art;
    return map;
}

void MprisService::seekToMs(qint64 position)
{
    if (!m_player || !m_player->isSeekable() || m_player->source().isEmpty()) return;
    position = std::clamp<qint64>(position, 0, m_player->duration());
    m_player->setPosition(position);
    if (hasTrack()) emit seeked(position * 1000);
}

void MprisService::seekRelativeUs(qint64 offset)
{
    if (!canSeek()) return;
    const qint64 delta = offset / 1000;
    const qint64 position = m_player->position();
    if (delta > 0 && delta > m_player->duration() - position) {
        if (canNext()) emit nextRequested();
        else emit stopRequested();
    } else {
        seekToMs(delta < -position ? 0 : position + delta);
    }
}

void MprisService::setPositionUs(const QDBusObjectPath &id, qint64 position)
{
    if (!canSeek() || id.path() != trackId().path() || position < 0 || position / 1000 > m_player->duration()
        || (position / 1000 == m_player->duration() && position % 1000 != 0)) return;
    seekToMs(position / 1000);
}

QStringList MprisService::supportedMimeTypes() const
{
    return {"video/mp4", "video/x-matroska", "video/x-msvideo", "video/quicktime", "video/webm", "video/x-flv", "video/MP2T", "video/ogg", "video/x-ms-wmv", "video/3gpp", "video/mpeg", "audio/mpeg", "audio/flac", "audio/ogg", "audio/x-wav", "audio/mp4", "audio/aac", "audio/opus", "audio/x-ms-wma", "audio/x-aiff", "audio/wavpack", "audio/x-ape"};
}

bool MprisService::acceptsUri(const QString &uri) const
{
    const QUrl url(uri, QUrl::StrictMode);
    const QFileInfo file(url.toLocalFile());
    const QStringList extensions{"mp4", "mkv", "avi", "mov", "webm", "flv", "m4v", "ts", "ogv", "wmv", "3gp", "mpg", "mpeg", "mp3", "flac", "wav", "ogg", "m4a", "aac", "opus", "wma", "aiff", "wv", "ape"};
    return url.isLocalFile() && file.isFile() && file.isReadable() && extensions.contains(file.suffix().toLower());
}

void MprisService::publish()
{
    if (m_serviceName.isEmpty()) return;
    const double volume = m_output && !m_output->isMuted() ? m_output->volume() : 0;
    QVariantMap player{{"PlaybackStatus", playbackStatus()}, {"Rate", m_player ? m_player->playbackRate() : 1.0},
                       {"Metadata", metadata()}, {"Volume", volume}, {"MinimumRate", 0.25}, {"MaximumRate", 3.0},
                       {"CanGoNext", canNext()}, {"CanGoPrevious", canPrevious()}, {"CanPlay", canPlay()},
                       {"CanPause", canPlay()}, {"CanSeek", canSeek()}, {"CanControl", true}};
    QVariantMap root{{"CanQuit", true}, {"CanRaise", m_window != nullptr}, {"HasTrackList", false},
                     {"Identity", "MAPL Player"}, {"DesktopEntry", "mapl-player"},
                     {"SupportedUriSchemes", QStringList{"file"}}, {"SupportedMimeTypes", supportedMimeTypes()}};
    auto send = [this](const QString &interface, const QVariantMap &current, QVariantMap &last) {
        QVariantMap differences;
        for (auto it = current.begin(); it != current.end(); ++it)
            if (!last.contains(it.key()) || last.value(it.key()) != it.value()) differences[it.key()] = it.value();
        last = current;
        if (differences.isEmpty()) return;
        auto message = QDBusMessage::createSignal(objectPath, "org.freedesktop.DBus.Properties", "PropertiesChanged");
        message << interface << differences << QStringList();
        m_bus.send(message);
    };
    send(playerInterface, player, m_lastPlayer);
    send(rootInterface, root, m_lastRoot);
}
