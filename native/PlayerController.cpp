#include "PlayerController.h"
#include <QFileInfo>
#include <QUrl>
#include <QFile>
#include <QTextStream>
#include <QCryptographicHash>
#include <QDir>
#include <QStandardPaths>
#include <QDebug>

PlayerController::PlayerController(QObject *parent)
    : QObject(parent)
    , m_videoSink(nullptr)
    , m_lastFrameTime(0)
    , m_previewProcess(nullptr)
{
}

PlayerController::~PlayerController()
{
    if (m_videoSink) {
        disconnect(m_videoSink, &QVideoSink::videoFrameChanged, this, &PlayerController::handleVideoFrame);
    }
    if (m_previewProcess) {
        if (m_previewProcess->state() != QProcess::NotRunning) {
            m_previewProcess->disconnect();
            m_previewProcess->kill();
            m_previewProcess->waitForFinished();
        }
        delete m_previewProcess;
    }
}

QVideoSink* PlayerController::videoSink() const
{
    return m_videoSink;
}

void PlayerController::setVideoSink(QVideoSink* sink)
{
    if (m_videoSink == sink)
        return;

    if (m_videoSink) {
        disconnect(m_videoSink, &QVideoSink::videoFrameChanged, this, &PlayerController::handleVideoFrame);
    }

    m_videoSink = sink;

    if (m_videoSink) {
        connect(m_videoSink, &QVideoSink::videoFrameChanged, this, &PlayerController::handleVideoFrame);
    }

    emit videoSinkChanged();
}

QString PlayerController::currentTrackTitle() const
{
    return m_currentTrackTitle;
}

void PlayerController::setCurrentTrackTitle(const QString &title)
{
    if (m_currentTrackTitle == title)
        return;
    m_currentTrackTitle = title;
    emit currentTrackTitleChanged();
}

void PlayerController::saveVolume(int volume)
{
    QSettings settings("MAPL", "MAPLPlayerNative");
    settings.setValue("volume", volume);
}

int PlayerController::loadVolume() const
{
    QSettings settings("MAPL", "MAPLPlayerNative");
    return settings.value("volume", 100).toInt();
}

void PlayerController::saveLoop(bool loop)
{
    QSettings settings("MAPL", "MAPLPlayerNative");
    settings.setValue("loop", loop);
}

bool PlayerController::loadLoop() const
{
    QSettings settings("MAPL", "MAPLPlayerNative");
    return settings.value("loop", false).toBool();
}

void PlayerController::captureThumbnail(const QString &trackUrl)
{
    if (m_lastImage.isNull())
        return;

    QByteArray ba;
    QBuffer buffer(&ba);
    buffer.open(QIODevice::WriteOnly);
    m_lastImage.save(&buffer, "PNG");
    QString base64 = QString::fromLatin1(ba.toBase64().constData());

    QSettings settings("MAPL", "MAPLPlayerNative");
    settings.setValue("thumbnail/" + trackUrl, base64);
    emit thumbnailCaptured(trackUrl, base64);
}

QString PlayerController::getThumbnail(const QString &trackUrl) const
{
    QSettings settings("MAPL", "MAPLPlayerNative");
    return settings.value("thumbnail/" + trackUrl, "").toString();
}

QString PlayerController::getCleanFileName(const QString &filePath) const
{
    // Resolves file:///home/user/video.mp4 -> video.mp4
    QUrl url(filePath);
    if (url.isLocalFile()) {
        return QFileInfo(url.toLocalFile()).fileName();
    }
    return QFileInfo(filePath).fileName();
}

void PlayerController::handleVideoFrame(const QVideoFrame &frame)
{
    if (!frame.isValid())
        return;

    // Limit color extraction to max 4 times per second to save CPU
    qint64 currentMsecs = QDateTime::currentMSecsSinceEpoch();
    if (currentMsecs - m_lastFrameTime < 250) {
        return;
    }
    m_lastFrameTime = currentMsecs;

    QVideoFrame cloneFrame(frame);
    if (!cloneFrame.map(QVideoFrame::ReadOnly))
        return;

    m_lastImage = cloneFrame.toImage().copy();
    cloneFrame.unmap();

    if (m_lastImage.isNull())
        return;

    // Sub-sample image to find average color quickly
    long long r = 0, g = 0, b = 0;
    int count = 0;
    int step = 8;
    for (int y = 0; y < m_lastImage.height(); y += step) {
        for (int x = 0; x < m_lastImage.width(); x += step) {
            QRgb pixel = m_lastImage.pixel(x, y);
            r += qRed(pixel);
            g += qGreen(pixel);
            b += qBlue(pixel);
            count++;
        }
    }

    if (count > 0) {
        QColor avgColor(r / count, g / count, b / count);
        emit backgroundColorChanged(avgColor.name());
    }
}

bool PlayerController::writeTextToFile(const QString &filePath, const QString &content)
{
    QUrl url(filePath);
    QString localPath = url.isLocalFile() ? url.toLocalFile() : filePath;
    QFile file(localPath);
    if (!file.open(QIODevice::WriteOnly | QIODevice::Text))
        return false;
    QTextStream out(&file);
    out << content;
    file.close();
    return true;
}

void PlayerController::generateTimelinePreviews(const QString &trackUrl, double durationSec)
{
    if (trackUrl.isEmpty() || durationSec <= 0) {
        return;
    }

    QUrl url(trackUrl);
    QString localInput = url.isLocalFile() ? url.toLocalFile() : trackUrl;

    if (!QFile::exists(localInput)) {
        qDebug() << "Timeline preview generation: File does not exist locally:" << localInput;
        return;
    }

    // Compute MD5 hash of trackUrl to generate a unique cache filename
    QByteArray hash = QCryptographicHash::hash(trackUrl.toUtf8(), QCryptographicHash::Md5).toHex();
    QString cacheDir = QDir::homePath() + "/.cache/mapl-player/previews";
    QDir().mkpath(cacheDir);
    QString cachePath = cacheDir + "/" + hash + ".jpg";

    m_currentPreviewTrack = trackUrl;
    m_currentPreviewPath = cachePath;

    // Check if already in cache
    if (QFile::exists(cachePath)) {
        qDebug() << "Timeline preview loaded from cache:" << cachePath;
        emit timelinePreviewsReady(trackUrl, cachePath);
        return;
    }

    // Cancel any running preview process
    if (m_previewProcess) {
        if (m_previewProcess->state() != QProcess::NotRunning) {
            m_previewProcess->disconnect(); // Disconnect signals to prevent false-positive warnings or callbacks on deleted object
            m_previewProcess->kill();
            m_previewProcess->waitForFinished();
        }
        delete m_previewProcess;
        m_previewProcess = nullptr;
    }

    m_previewProcess = new QProcess(this);
    m_previewProcess->setProcessChannelMode(QProcess::ForwardedChannels);

    QStringList arguments;
    arguments << "-y"
              << "-hwaccel" << "auto"      // Use hardware-accelerated decoding if available to minimize CPU and latency
              << "-discard" << "nokey"     // Tell demuxer to discard non-keyframes for ultra-fast seek/read
              << "-skip_frame" << "nokey"  // Decode only keyframes for ultra-fast generation and low CPU usage
              << "-threads" << "2"         // Limit ffmpeg to 2 threads to prevent high CPU utilization spikes
              << "-i" << localInput
              << "-vf" << QString("fps=100/%1,scale=160:90,tile=10x10").arg(durationSec)
              << "-frames:v" << "1"
              << "-an"
              << "-update" << "1"          // Write single image output correctly without sequence pattern warning
              << cachePath;

    connect(m_previewProcess, &QProcess::finished, this, [this, trackUrl, cachePath](int exitCode, QProcess::ExitStatus exitStatus) {
        if (exitStatus == QProcess::NormalExit && exitCode == 0) {
            qDebug() << "Timeline preview successfully generated:" << cachePath;
            if (m_currentPreviewTrack == trackUrl) {
                emit timelinePreviewsReady(trackUrl, cachePath);
            }
        } else {
            qWarning() << "Timeline preview generation failed for:" << trackUrl << "exit code:" << exitCode;
            QFile::remove(cachePath);
        }
    });

    qDebug() << "Starting timeline preview generation for:" << localInput << "to" << cachePath;
    m_previewProcess->start("ffmpeg", arguments);
}

QVariantList PlayerController::getFilesInFolder(const QString &fileUrl)
{
    QVariantList fileList;
    QUrl url(fileUrl);
    if (!url.isLocalFile()) {
        qDebug() << "getFilesInFolder: Not a local file URL:" << fileUrl;
        return fileList;
    }

    QString localPath = url.toLocalFile();
    QFileInfo fileInfo(localPath);
    QDir dir = fileInfo.dir();

    // Define standard media filters for scan
    QStringList filters;
    filters << "*.mp4" << "*.webm" << "*.mkv" << "*.avi" << "*.mov" << "*.flv" 
            << "*.m4v" << "*.ts" << "*.ogv"
            << "*.mp3" << "*.wav" << "*.ogg" << "*.m4a" << "*.flac";
    dir.setNameFilters(filters);
    dir.setFilter(QDir::Files | QDir::NoSymLinks);
    dir.setSorting(QDir::Name | QDir::LocaleAware);

    QFileInfoList list = dir.entryInfoList();
    for (const QFileInfo &info : list) {
        QVariantMap map;
        map["url"] = QUrl::fromLocalFile(info.absoluteFilePath()).toString();
        map["title"] = info.fileName();
        fileList.append(map);
    }

    return fileList;
}

void PlayerController::savePlayFolderToggle(bool enabled)
{
    QSettings settings("MAPL", "MAPLPlayerNative");
    settings.setValue("playFolderToggle", enabled);
}

bool PlayerController::loadPlayFolderToggle() const
{
    QSettings settings("MAPL", "MAPLPlayerNative");
    return settings.value("playFolderToggle", false).toBool();
}

QVariantList PlayerController::findSubtitleFiles(const QString &mediaUrl)
{
    QVariantList result;
    QUrl url(mediaUrl);
    if (!url.isLocalFile())
        return result;

    QString localPath = url.toLocalFile();
    QFileInfo fileInfo(localPath);
    // completeBaseName strips only the last extension: "movie.en.mp4" -> "movie.en"
    // But we want the real base without any language suffix, so use baseName of the stem
    // Strategy: strip last extension, then use that as the glob prefix
    QString stem = fileInfo.completeBaseName(); // "movie" from "movie.mp4", "movie.en" from "movie.en.mp4"
    // For most cases the stem is already right (e.g. "Ben 10 Alien Swarm 2009")
    QDir dir = fileInfo.dir();

    QStringList filters;
    filters << stem + "*.srt" << stem + "*.vtt";
    dir.setNameFilters(filters);
    dir.setFilter(QDir::Files | QDir::NoSymLinks);
    dir.setSorting(QDir::Name);

    QFileInfoList list = dir.entryInfoList();
    for (const QFileInfo &info : list) {
        QVariantMap map;
        map["url"] = QUrl::fromLocalFile(info.absoluteFilePath()).toString();

        // Extract the language label: strip the stem prefix and the file extension
        // e.g. stem="movie", file="movie.en.srt" -> langPart=".en" -> label="en"
        // e.g. stem="movie", file="movie.srt"    -> langPart=""    -> label="Default"
        QString fileStem = info.completeBaseName(); // "movie.en" or "movie"
        QString langPart;
        if (fileStem.length() > stem.length()) {
            langPart = fileStem.mid(stem.length()); // ".en"
            if (langPart.startsWith('.'))
                langPart = langPart.mid(1);          // "en"
        }
        map["label"] = langPart.isEmpty() ? tr("Default") : langPart;
        result.append(map);
    }

    return result;
}
