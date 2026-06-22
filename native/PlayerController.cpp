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
            m_previewProcess->kill();
            m_previewProcess->waitForFinished();
        }
        delete m_previewProcess;
        m_previewProcess = nullptr;
    }

    m_previewProcess = new QProcess(this);

    QStringList arguments;
    arguments << "-y"
              << "-i" << localInput
              << "-vf" << QString("fps=100/%1,scale=160:90,tile=10x10").arg(durationSec)
              << "-frames:v" << "1"
              << "-an"
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
