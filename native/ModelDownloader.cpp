#include "ModelDownloader.h"
#include <QStandardPaths>
#include <QNetworkRequest>
#include <QFileInfo>

ModelDownloader::ModelDownloader(QObject *parent)
    : QObject(parent)
    , m_manager(nullptr)
    , m_reply(nullptr)
    , m_file(nullptr)
    , m_isDownloading(false)
{
}

ModelDownloader::~ModelDownloader()
{
    cancelDownload();
}

bool ModelDownloader::checkModelExists(const QString &modelName) const
{
    QString path = getModelPath(modelName);
    QFileInfo checkFile(path);
    // Whisper tiny model is ~77MB, base is ~140MB. Check if file exists and has size > 10MB to avoid corrupted empty files.
    return checkFile.exists() && checkFile.size() > 10 * 1024 * 1024;
}

QString ModelDownloader::getModelPath(const QString &modelName) const
{
    QString cacheDir = QDir::homePath() + "/.cache/mapl-player";
    // Construct filename like ggml-tiny.bin
    QString fileName = QString("ggml-%1.bin").arg(modelName.toLower());
    return cacheDir + "/" + fileName;
}

bool ModelDownloader::isDownloading() const
{
    return m_isDownloading;
}

void ModelDownloader::startDownload(const QString &modelName)
{
    if (m_isDownloading)
        return;

    m_destPath = getModelPath(modelName);
    QFileInfo fileInfo(m_destPath);
    QDir dir = fileInfo.dir();
    if (!dir.exists()) {
        dir.mkpath(".");
    }

    m_file = new QFile(m_destPath, this);
    if (!m_file->open(QIODevice::WriteOnly)) {
        emit downloadError(tr("Failed to open local destination file for writing: %1").arg(m_destPath));
        delete m_file;
        m_file = nullptr;
        return;
    }

    // Set up network manager
    m_manager = new QNetworkAccessManager(this);
    
    // Whisper repository download URL
    QString urlStr = QString("https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-%1.bin").arg(modelName.toLower());
    QUrl url(urlStr);
    
    QNetworkRequest request(url);
    // Follow HuggingFace redirects automatically
    request.setAttribute(QNetworkRequest::RedirectPolicyAttribute, QNetworkRequest::NoLessSafeRedirectPolicy);

    m_reply = m_manager->get(request);
    m_isDownloading = true;
    emit isDownloadingChanged();

    connect(m_reply, &QNetworkReply::downloadProgress, this, &ModelDownloader::onDownloadProgress);
    connect(m_reply, &QNetworkReply::finished, this, &ModelDownloader::onFinished);
    connect(m_reply, &QNetworkReply::errorOccurred, this, &ModelDownloader::onErrorOccurred);
    
    // Directly stream data to file on arrival to minimize RAM footprint
    connect(m_reply, &QNetworkReply::readyRead, this, [this]() {
        if (m_file && m_reply) {
            m_file->write(m_reply->readAll());
        }
    });
}

void ModelDownloader::cancelDownload()
{
    if (!m_isDownloading)
        return;

    if (m_reply) {
        m_reply->abort();
    }
    
    cleanupNetwork();
    
    if (m_file) {
        m_file->close();
        m_file->remove(); // delete partially downloaded file
        delete m_file;
        m_file = nullptr;
    }
}

void ModelDownloader::onDownloadProgress(qint64 bytesReceived, qint64 bytesTotal)
{
    if (bytesTotal > 0) {
        double progress = (static_cast<double>(bytesReceived) / bytesTotal) * 100.0;
        emit progressChanged(progress);
    }
}

void ModelDownloader::onFinished()
{
    if (!m_isDownloading)
        return;

    if (m_file) {
        m_file->close();
        delete m_file;
        m_file = nullptr;
    }

    QString finalPath = m_destPath;
    cleanupNetwork();

    emit downloadFinished(finalPath);
}

void ModelDownloader::onErrorOccurred(QNetworkReply::NetworkError error)
{
    if (error == QNetworkReply::OperationCanceledError)
        return; // Handled by cancelDownload()

    QString errorStr = m_reply ? m_reply->errorString() : tr("Unknown network error occurred.");
    emit downloadError(errorStr);
    
    cancelDownload();
}

void ModelDownloader::cleanupNetwork()
{
    m_isDownloading = false;
    emit isDownloadingChanged();

    if (m_reply) {
        m_reply->deleteLater();
        m_reply = nullptr;
    }
    if (m_manager) {
        m_manager->deleteLater();
        m_manager = nullptr;
    }
}
