#include "PlaybackHistory.h"
#include <QCryptographicHash>
#include <QDir>
#include <QFileInfo>
#include <QUrl>
#include <algorithm>

namespace {
constexpr auto recentKey = "playback/recentFiles";
constexpr int maxRecentFiles = 20;
}

PlaybackHistory::PlaybackHistory(QObject *parent)
    : QObject(parent), m_settings("MAPL", "MAPLPlayerNative")
{
    const auto stored = m_settings.value(recentKey).toStringList();
    for (const auto &entry : stored) {
        const auto url = normalizedUrl(entry);
        if (!url.isEmpty() && !m_recentFiles.contains(url))
            m_recentFiles.append(url);
        if (m_recentFiles.size() == maxRecentFiles)
            break;
    }
}

QString PlaybackHistory::normalizedUrl(const QString &mediaUrl)
{
    if (mediaUrl.isEmpty())
        return {};
    const QUrl url(mediaUrl);
    if (!url.isLocalFile() && !url.scheme().isEmpty())
        return {};
    const auto path = url.isLocalFile() ? url.toLocalFile() : mediaUrl;
    return QUrl::fromLocalFile(QDir::cleanPath(QFileInfo(path).absoluteFilePath())).toString();
}

QString PlaybackHistory::positionKey(const QString &mediaUrl)
{
    const auto url = normalizedUrl(mediaUrl);
    if (url.isEmpty())
        return {};
    return "playback/positions/" + QCryptographicHash::hash(url.toUtf8(), QCryptographicHash::Sha256).toHex();
}

bool PlaybackHistory::isAvailable(const QString &mediaUrl) const
{
    const auto normalized = normalizedUrl(mediaUrl);
    if (normalized.isEmpty())
        return false;
    const QFileInfo file(QUrl(normalized).toLocalFile());
    return file.isFile() && file.isReadable();
}

QVariantList PlaybackHistory::recentFiles() const
{
    QVariantList result;
    for (const auto &url : m_recentFiles) {
        const auto path = QUrl(url).toLocalFile();
        result.append(QVariantMap{{"url", url}, {"title", QFileInfo(path).fileName()},
                                  {"path", path}, {"available", isAvailable(url)}});
    }
    return result;
}

void PlaybackHistory::recordFile(const QString &mediaUrl)
{
    if (!isAvailable(mediaUrl))
        return;
    const auto url = normalizedUrl(mediaUrl);
    m_recentFiles.removeAll(url);
    m_recentFiles.prepend(url);
    if (m_recentFiles.size() > maxRecentFiles)
        m_recentFiles.removeLast();
    m_settings.setValue(recentKey, m_recentFiles);
    emit recentFilesChanged();
}

void PlaybackHistory::refreshRecentFiles()
{
    emit recentFilesChanged();
}

void PlaybackHistory::clearRecentFiles()
{
    m_recentFiles.clear();
    m_settings.remove(recentKey);
    emit recentFilesChanged();
}

qint64 PlaybackHistory::resumablePosition(qint64 positionMs, qint64 durationMs)
{
    // Ignore the opening five seconds and the final 5% (at most ten seconds).
    if (durationMs <= 0 || positionMs < 5000 || positionMs >= durationMs
        || durationMs - positionMs <= std::min<qint64>(10000, durationMs / 20))
        return 0;
    return positionMs;
}

void PlaybackHistory::savePosition(const QString &mediaUrl, qint64 positionMs, qint64 durationMs)
{
    const auto key = positionKey(mediaUrl);
    if (key.isEmpty())
        return;
    const auto position = resumablePosition(positionMs, durationMs);
    if (position == 0) {
        m_settings.remove(key);
    } else {
        m_settings.setValue(key, QVariantMap{{"position", position}, {"duration", durationMs}});
    }
}

qint64 PlaybackHistory::resumePosition(const QString &mediaUrl, qint64 durationMs) const
{
    const auto key = positionKey(mediaUrl);
    if (key.isEmpty())
        return 0;
    const auto entry = m_settings.value(key).toMap();
    return resumablePosition(entry.value("position").toLongLong(),
                             durationMs > 0 ? durationMs : entry.value("duration").toLongLong());
}

void PlaybackHistory::clearPosition(const QString &mediaUrl)
{
    const auto key = positionKey(mediaUrl);
    if (!key.isEmpty())
        m_settings.remove(key);
}

void PlaybackHistory::sync()
{
    m_settings.sync();
}
