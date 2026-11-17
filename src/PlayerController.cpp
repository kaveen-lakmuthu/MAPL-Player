#include "PlayerController.h"
#include "BackgroundProcess.h"
#include <QTemporaryFile>
#include <QFileInfo>
#include <QUrl>
#include <QFile>
#include <QSaveFile>
#include <QXmlStreamReader>
#include <QCryptographicHash>
#include <QDir>
#include <QStandardPaths>
#include <QDebug>
#include <QJsonDocument>
#include <QJsonObject>
#include <QJsonArray>

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
    // Reap children before the temporary directory is removed.
    for (auto *job : findChildren<BackgroundProcess *>(QString(), Qt::FindDirectChildrenOnly)) {
        job->disconnect(this);
        delete job;
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
    resetVideoFrame();

    if (m_videoSink) {
        connect(m_videoSink, &QVideoSink::videoFrameChanged, this, &PlayerController::handleVideoFrame);
    }

    emit videoSinkChanged();
}

bool PlayerController::hasVideoFrame() const
{
    return !m_lastImage.isNull();
}

void PlayerController::resetVideoFrame()
{
    const bool hadFrame = hasVideoFrame();
    m_lastImage = QImage();
    m_lastFrameTime = 0;
    if (hadFrame)
        emit hasVideoFrameChanged();
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
    if (trackUrl.isEmpty() || !hasVideoFrame())
        return;

    // Color sampling is throttled. Capture the displayed frame rather than
    // the earlier frame retained for ambient color extraction.
    if (m_videoSink) {
        const QImage currentImage = m_videoSink->videoFrame().toImage();
        if (!currentImage.isNull())
            m_lastImage = currentImage;
    }

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

    const bool hadFrame = hasVideoFrame();
    const QImage image = cloneFrame.toImage().copy();
    cloneFrame.unmap();
    if (image.isNull())
        return;
    m_lastImage = image;
    if (!hadFrame)
        emit hasVideoFrameChanged();

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

QVariantMap PlayerController::parseXspf(const QString &xml, const QString &playlistUrl) const
{
    QXmlStreamReader reader(xml);
    const auto isElement = [&reader](const char *name) {
        return reader.name() == QLatin1String(name)
            && (reader.namespaceUri().isEmpty() || reader.namespaceUri() == QLatin1String("http://xspf.org/ns/0/"));
    };
    const auto elementBase = [&reader](const QUrl &parent) {
        const auto base = reader.attributes().value(QLatin1String("http://www.w3.org/XML/1998/namespace"),
                                                    QLatin1String("base"));
        return base.isEmpty() ? parent : parent.resolved(QUrl(base.toString()));
    };
    if (!reader.readNextStartElement() || !isElement("playlist"))
        return {{"tracks", QVariantList()}, {"error", tr("Invalid XSPF playlist.")}};

    const auto playlistBase = elementBase(QUrl(playlistUrl));
    QVariantList tracks;
    while (reader.readNextStartElement()) {
        if (!isElement("trackList")) {
            reader.skipCurrentElement();
            continue;
        }
        const auto listBase = elementBase(playlistBase);
        while (reader.readNextStartElement()) {
            if (!isElement("track")) {
                reader.skipCurrentElement();
                continue;
            }
            const auto trackBase = elementBase(listBase);
            QUrl location;
            QString title;
            while (reader.readNextStartElement()) {
                if (isElement("location")) {
                    const auto locationBase = elementBase(trackBase);
                    const auto text = reader.readElementText().trimmed();
                    if (location.isEmpty() && !text.isEmpty()) {
                        QUrl candidate(text);
                        if (candidate.isRelative())
                            candidate = locationBase.resolved(candidate);
                        if (candidate.isValid() && !candidate.isRelative())
                            location = candidate;
                    }
                } else if (isElement("title")) {
                    const auto text = reader.readElementText().trimmed();
                    if (title.isEmpty())
                        title = text;
                } else {
                    reader.skipCurrentElement();
                }
            }
            if (!location.isEmpty()) {
                const auto url = location.toString();
                tracks.append(QVariantMap{{"url", url}, {"title", title.isEmpty() ? getCleanFileName(url) : title}});
            }
        }
    }
    // Validate the complete document, including text after the playlist ends.
    while (!reader.atEnd())
        reader.readNext();
    if (reader.hasError())
        return {{"tracks", QVariantList()}, {"error", tr("Invalid XSPF: %1").arg(reader.errorString())}};
    return {{"tracks", tracks}, {"error", QString()}};
}

bool PlayerController::writeTextToFile(const QString &filePath, const QString &content)
{
    QUrl url(filePath);
    QString localPath = url.isLocalFile() ? url.toLocalFile() : filePath;
    QSaveFile file(localPath);
    // Never fall back to truncating the destination if a temporary file
    // cannot be created. Failed writes must leave an earlier export intact.
    file.setDirectWriteFallback(false);
    if (!file.open(QIODevice::WriteOnly))
        return false;
    const QByteArray bytes = content.toUtf8();
    if (file.write(bytes) != bytes.size()) {
        file.cancelWriting();
        return false;
    }
    return file.commit();
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

    // Keep folder playback aligned with the media file dialog's formats.
    QStringList filters;
    filters << "*.mp4" << "*.webm" << "*.mkv" << "*.avi" << "*.mov" << "*.flv" 
            << "*.m4v" << "*.ts" << "*.ogv" << "*.wmv" << "*.3gp" << "*.mpg" << "*.mpeg"
            << "*.mp3" << "*.wav" << "*.ogg" << "*.m4a" << "*.flac"
            << "*.aac" << "*.opus" << "*.wma" << "*.aiff" << "*.wv" << "*.ape";
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
    const QString stem = fileInfo.completeBaseName();
    const QString qualifiedPrefix = stem + '.';
    QDir dir = fileInfo.dir();

    // Filter only extensions here: the media name may contain glob characters.
    dir.setNameFilters({"*.srt", "*.vtt"});
    dir.setFilter(QDir::Files | QDir::NoSymLinks);
    dir.setSorting(QDir::Name);

    QFileInfoList list = dir.entryInfoList();
    for (const QFileInfo &info : list) {
        const QString fileStem = info.completeBaseName();
        QString label;
        if (fileStem.compare(stem, Qt::CaseInsensitive) == 0) {
            label = tr("Default");
        } else if (fileStem.startsWith(qualifiedPrefix, Qt::CaseInsensitive)
                   && fileStem.size() > qualifiedPrefix.size()) {
            // Keep language/kind tags, but never match Episode10 to Episode1.
            label = fileStem.mid(qualifiedPrefix.size());
        } else {
            continue;
        }
        QVariantMap map;
        map["url"] = QUrl::fromLocalFile(info.absoluteFilePath()).toString();
        map["label"] = label;
        result.append(map);
    }

    return result;
}

void PlayerController::cancelSubtitleExtraction()
{
    auto *job = m_subtitleProcess;
    m_subtitleProcess = nullptr;
    if (job)
        job->cancel();
}

void PlayerController::cancelMediaJobs()
{
    cancelSubtitleExtraction();
    auto *job = m_chapterProcess;
    m_chapterProcess = nullptr;
    if (job)
        job->cancel();
}

void PlayerController::extractEmbeddedSubtitle(const QString &mediaUrl, int trackIndex, int requestId)
{
    cancelSubtitleExtraction();
    auto *job = new BackgroundProcess(this);
    m_subtitleProcess = job;
    QTemporaryFile output(m_subtitleDirectory.filePath("subtitle-XXXXXX.srt"));
    const bool valid = trackIndex >= 0 && m_subtitleDirectory.isValid() && output.open();
    const QString path = output.fileName();
    output.setAutoRemove(false);
    output.close();
    connect(job, &BackgroundProcess::completed, this,
            [this, job, requestId, path](bool success, const QByteArray &) {
        if (m_subtitleProcess != job) {
            if (!path.isEmpty())
                QFile::remove(path);
            return;
        }
        m_subtitleProcess = nullptr;
        if (success && QFileInfo(path).size() > 0) {
            emit embeddedSubtitleReady(requestId, QUrl::fromLocalFile(path).toString());
        } else {
            if (!path.isEmpty())
                QFile::remove(path);
            emit embeddedSubtitleError(requestId, tr("Failed to extract embedded subtitles."));
        }
    });
    const QUrl url(mediaUrl);
    const QString localInput = url.isLocalFile() ? url.toLocalFile() : mediaUrl;
    if (!valid || !QFile::exists(localInput)) {
        // Keep even validation failures asynchronous for callers assigning request IDs.
        QTimer::singleShot(0, job, [job] { emit job->completed(false, {}); job->deleteLater(); });
        return;
    }
    job->start(m_ffmpegProgram, {"-v", "error", "-nostdin", "-y", "-i", localInput,
               "-map", QString("0:s:%1").arg(trackIndex), "-c:s", "srt", path}, m_subtitleTimeoutMs);
}

void PlayerController::scanMediaChapters(const QString &mediaUrl, int requestId)
{
    auto *previous = m_chapterProcess;
    m_chapterProcess = nullptr;
    if (previous)
        previous->cancel();
    auto *job = new BackgroundProcess(this);
    m_chapterProcess = job;
    connect(job, &BackgroundProcess::completed, this,
            [this, job, requestId](bool success, const QByteArray &output) {
        if (m_chapterProcess != job)
            return;
        m_chapterProcess = nullptr;
        QVariantList chapters;
        if (success) {
            const auto array = QJsonDocument::fromJson(output).object().value("chapters").toArray();
            for (const auto &value : array) {
                const auto chapter = value.toObject();
                QString title = chapter.value("tags").toObject().value("title").toString();
                if (title.isEmpty())
                    title = tr("Chapter %1").arg(chapters.size() + 1);
                chapters.append(QVariantMap{{"time", chapter.value("start_time").toVariant().toDouble()},
                                            {"title", title}});
            }
        }
        emit mediaChaptersReady(requestId, chapters);
    });
    const QUrl url(mediaUrl);
    const QString localInput = url.isLocalFile() ? url.toLocalFile() : mediaUrl;
    if (mediaUrl.isEmpty() || !QFile::exists(localInput)) {
        QTimer::singleShot(0, job, [job] { emit job->completed(false, {}); job->deleteLater(); });
        return;
    }
    job->start(m_ffprobeProgram, {"-v", "error", "-print_format", "json", "-show_chapters", localInput},
               m_chapterTimeoutMs);
}
