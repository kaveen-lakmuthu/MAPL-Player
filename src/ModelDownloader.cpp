#include "ModelDownloader.h"
#include <QStandardPaths>
#include <QNetworkRequest>
#include <QFileInfo>
#include <QFile>
#include <QDir>
#include <QDateTime>
#include <algorithm>

ModelDownloader::ModelDownloader(QObject *parent) : QObject(parent)
{
    // Official Git LFS SHA-256 objects and exact sizes, pinned to this revision.
    // See docs/model-catalog.md for provenance and the update procedure.
    const QString source = "https://huggingface.co/ggerganov/whisper.cpp/resolve/5359861c739e955e79d9a303bcbc70fb988958b1/ggml-";
    m_catalog = {
        {"tiny", "Tiny", 77691713, "be07e048e1e599ad46341c8d2a135645097a538221678b7acdd1b1919c6e1b21", QUrl(source + "tiny.bin")},
        {"base", "Base", 147951465, "60ed5bc3dd14eea856493d334349b405782ddcaf0028d4b5df4088345fba2efe", QUrl(source + "base.bin")}
    };
    m_modelDirectory = QStandardPaths::writableLocation(QStandardPaths::GenericCacheLocation) + "/mapl-player";
}

ModelDownloader::~ModelDownloader()
{
    m_shuttingDown = true;
    cleanupNetwork();
    if (m_verificationThread) {
        m_cancelVerification->store(true);
        m_verificationThread->disconnect(this);
        m_verificationThread->wait();
        delete m_verificationThread;
    }
}

const ModelDownloader::ModelSpec *ModelDownloader::specFor(const QString &name) const
{
    for (const auto &spec : m_catalog)
        if (spec.name == name.toLower())
            return &spec;
    return nullptr;
}

QString ModelDownloader::getModelPath(const QString &name) const
{
    const auto *spec = specFor(name);
    return spec ? QDir(m_modelDirectory).filePath("ggml-" + spec->name + ".bin") : QString();
}

QByteArray ModelDownloader::fingerprint(const QString &path)
{
    const QFileInfo file(path);
    if (!file.isFile() || !file.isReadable())
        return {};
    return QByteArray::number(file.size()) + ':' + QByteArray::number(file.lastModified().toMSecsSinceEpoch())
        + ':' + QByteArray::number(file.fileTime(QFileDevice::FileMetadataChangeTime).toMSecsSinceEpoch());
}

bool ModelDownloader::checkModelExists(const QString &name) const
{
    const auto *spec = specFor(name);
    if (!spec)
        return false;
    const auto state = m_states.value(spec->name);
    return state.verified && !state.fingerprint.isEmpty()
        && state.fingerprint == fingerprint(getModelPath(spec->name));
}

bool ModelDownloader::isInUse(const QString &name) const
{
    return !m_inUsePath.isEmpty() && QFileInfo(m_inUsePath).absoluteFilePath() == QFileInfo(getModelPath(name)).absoluteFilePath();
}

void ModelDownloader::setInUsePath(const QString &path)
{
    if (path != m_inUsePath) {
        m_inUsePath = path;
        emit modelsChanged();
    }
}

QVariantList ModelDownloader::models() const
{
    QVariantList list;
    for (const auto &spec : m_catalog) {
        const QFileInfo file(getModelPath(spec.name));
        const auto state = m_states.value(spec.name);
        const bool present = file.isFile();
        QString status = state.status;
        if (status.isEmpty() || (state.verified && !checkModelExists(spec.name)))
            status = present ? tr("Not verified") : tr("Not installed");
        list.append(QVariantMap{{"name", spec.name}, {"title", spec.title}, {"expectedBytes", spec.bytes},
                                {"installedBytes", present ? file.size() : 0}, {"present", present},
                                {"verified", checkModelExists(spec.name)}, {"status", status},
                                {"error", state.error}, {"inUse", isInUse(spec.name)}});
    }
    return list;
}

void ModelDownloader::prepareModel(const QString &name)
{
    if (isBusy())
        return;
    const auto *spec = specFor(name);
    if (!spec) {
        emit modelError(name.toLower(), tr("Unknown Whisper model."));
        emit downloadError(tr("Unknown Whisper model."));
        return;
    }
    // Every use verifies the file, even if its cached display status is valid.
    if (QFileInfo(getModelPath(spec->name)).isFile()) {
        verifyModels({spec->name}, true);
    } else {
        beginDownload(spec->name, true);
    }
}

void ModelDownloader::refreshModels()
{
    if (isBusy())
        return;
    QStringList names;
    for (const auto &spec : m_catalog) {
        if (QFileInfo(getModelPath(spec.name)).isFile())
            names.append(spec.name);
        else
            m_states.remove(spec.name);
    }
    emit modelsChanged();
    if (!names.isEmpty())
        verifyModels(names, false);
}

void ModelDownloader::verifyModels(const QStringList &names, bool prepare)
{
    struct Result { bool valid = false; QString error; QByteArray fingerprint; };
    auto results = std::make_shared<QHash<QString, Result>>();
    auto cancelled = std::make_shared<std::atomic_bool>(false);
    m_cancelVerification = cancelled;
    m_activeModel = names.first();
    QList<ModelSpec> specs;
    QHash<QString, QString> paths;
    for (const auto &name : names) {
        specs.append(*specFor(name));
        paths[name] = getModelPath(name);
        m_states[name] = {tr("Verifying"), {}, {}, false};
    }
    auto *thread = QThread::create([specs, paths, results, cancelled] {
        for (const auto &spec : specs) {
            if (cancelled->load())
                break;
            const auto path = paths.value(spec.name);
            Result result;
            result.fingerprint = fingerprint(path);
            QFile file(path);
            if (QFileInfo(path).size() != spec.bytes) {
                result.error = tr("File size does not match the model catalogue.");
            } else if (!file.open(QIODevice::ReadOnly)) {
                result.error = file.errorString();
            } else {
                QCryptographicHash hash(QCryptographicHash::Sha256);
                while (!file.atEnd() && !cancelled->load()) {
                    const auto data = file.read(256 * 1024);
                    if (data.isEmpty() && file.error() != QFileDevice::NoError)
                        break;
                    hash.addData(data);
                }
                result.valid = !cancelled->load() && file.error() == QFileDevice::NoError
                    && hash.result().toHex() == spec.sha256 && result.fingerprint == fingerprint(path);
                if (!result.valid)
                    result.error = tr("SHA-256 verification failed. Download this model again.");
            }
            results->insert(spec.name, result);
        }
    });
    thread->setParent(this);
    m_verificationThread = thread;
    connect(thread, &QThread::finished, this, [this, thread, results, cancelled, names, prepare] {
        thread->wait();
        m_verificationThread = nullptr;
        thread->deleteLater();
        const auto model = names.first();
        for (const auto &name : names) {
            const auto result = results->value(name);
            const bool valid = !cancelled->load() && result.valid && result.fingerprint == fingerprint(getModelPath(name));
            m_states[name] = {cancelled->load() ? tr("Not verified") : valid ? tr("Installed") : tr("Invalid"),
                              cancelled->load() ? QString() : result.error, valid ? result.fingerprint : QByteArray(), valid};
        }
        m_activeModel.clear();
        if (prepare && !cancelled->load() && !m_states.value(model).verified) {
            beginDownload(model, true);
        } else {
            if (cancelled->load())
                emit operationCancelled(model);
            else if (prepare)
                emit modelReady(model, getModelPath(model));
            emit busyChanged();
            emit modelsChanged();
        }
    });
    // Publish state only after the worker can be cancelled and joined safely.
    thread->start();
    emit busyChanged();
    emit modelsChanged();
}

void ModelDownloader::startDownload(const QString &name)
{
    beginDownload(name, false);
}

void ModelDownloader::beginDownload(const QString &name, bool prepare)
{
    if (isBusy())
        return;
    const auto *spec = specFor(name);
    if (!spec) {
        emit modelError(name.toLower(), tr("Unknown Whisper model."));
        emit downloadError(tr("Unknown Whisper model."));
        return;
    }
    if (isInUse(spec->name)) {
        emit modelError(spec->name, tr("This model is in use by transcription."));
        emit downloadError(tr("This model is in use by transcription."));
        return;
    }
    m_activeModel = spec->name;
    m_destPath = getModelPath(spec->name);
    m_states[spec->name] = {tr("Downloading"), {}, {}, false};
    if (!QDir().mkpath(m_modelDirectory)) {
        failDownload(tr("Could not create the model directory."));
        return;
    }
    m_file = new QSaveFile(m_destPath, this);
    m_file->setDirectWriteFallback(false);
    if (!m_file->open(QIODevice::WriteOnly)) {
        failDownload(tr("Could not write the model: %1").arg(m_file->errorString()));
        return;
    }
    m_downloadHash.reset();
    m_bytesWritten = 0;
    m_progress = 0;
    m_prepareAfterDownload = prepare;
    m_manager = new QNetworkAccessManager(this);
    QNetworkRequest request(spec->url);
    request.setAttribute(QNetworkRequest::RedirectPolicyAttribute, QNetworkRequest::NoLessSafeRedirectPolicy);
    m_reply = m_manager->get(request);
    m_reply->setReadBufferSize(512 * 1024);
    m_isDownloading = true;
    connectReply();
    emit progressChanged(0);
    emit isDownloadingChanged();
    emit busyChanged();
    emit modelsChanged();
}

void ModelDownloader::connectReply()
{
    connect(m_reply, &QNetworkReply::downloadProgress, this, &ModelDownloader::onDownloadProgress);
    connect(m_reply, &QNetworkReply::finished, this, &ModelDownloader::onFinished);
    connect(m_reply, &QNetworkReply::errorOccurred, this, &ModelDownloader::onErrorOccurred);
    connect(m_reply, &QNetworkReply::readyRead, this, [this] { drainReply(); });
}

bool ModelDownloader::drainReply()
{
    if (!m_reply || !m_file)
        return false;
    const auto *spec = specFor(m_activeModel);
    while (m_reply->bytesAvailable() > 0) {
        const auto data = m_reply->read(256 * 1024);
        if (data.isEmpty())
            break;
        if (!spec || m_bytesWritten + data.size() > spec->bytes) {
            failDownload(tr("Downloaded model exceeds its expected size."));
            return false;
        }
        if (m_file->write(data) != data.size()) {
            failDownload(tr("Failed to write model data: %1").arg(m_file->errorString()));
            return false;
        }
        m_downloadHash.addData(data);
        m_bytesWritten += data.size();
    }
    return true;
}

void ModelDownloader::onDownloadProgress(qint64 received, qint64)
{
    const auto *spec = specFor(m_activeModel);
    if (!spec || !m_isDownloading)
        return;
    m_progress = std::clamp(100.0 * received / spec->bytes, 0.0, 99.0);
    emit progressChanged(m_progress);
}

void ModelDownloader::onFinished()
{
    if (!m_isDownloading || !m_reply)
        return;
    const int status = m_reply->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt();
    if (m_reply->error() != QNetworkReply::NoError || status < 200 || status >= 300) {
        failDownload(tr("Model download failed: %1").arg(m_reply->errorString()));
        return;
    }
    if (!drainReply())
        return;
    const auto *spec = specFor(m_activeModel);
    if (!spec || m_bytesWritten != spec->bytes || m_downloadHash.result().toHex() != spec->sha256) {
        failDownload(tr("Model checksum verification failed. The download was discarded."));
        return;
    }
    if (!m_file->commit()) {
        failDownload(tr("Could not publish the model: %1").arg(m_file->errorString()));
        return;
    }
    const auto model = m_activeModel;
    const auto path = m_destPath;
    const bool prepare = m_prepareAfterDownload;
    m_states[model] = {tr("Installed"), {}, fingerprint(path), true};
    m_progress = 100;
    cleanupNetwork();
    emit progressChanged(100);
    emit downloadFinished(path);
    if (prepare)
        emit modelReady(model, path);
    notifyIdle();
}

void ModelDownloader::onErrorOccurred(QNetworkReply::NetworkError)
{
    if (m_isDownloading)
        failDownload(m_reply ? m_reply->errorString() : tr("Network error."));
}

void ModelDownloader::failDownload(const QString &message)
{
    const auto model = m_activeModel;
    if (!model.isEmpty())
        m_states[model] = {tr("Download failed"), message, {}, false};
    cleanupNetwork();
    emit modelError(model, message);
    emit downloadError(message);
    notifyIdle();
}

void ModelDownloader::cancelDownload()
{
    if (!m_isDownloading)
        return;
    const auto model = m_activeModel;
    m_states[model] = {};
    cleanupNetwork();
    emit operationCancelled(model);
    notifyIdle();
}

void ModelDownloader::cancelOperation()
{
    if (m_verificationThread)
        m_cancelVerification->store(true);
    else
        cancelDownload();
}

bool ModelDownloader::deleteModel(const QString &name)
{
    const auto *spec = specFor(name);
    if (!spec || isBusy() || isInUse(spec->name))
        return false;
    const auto path = getModelPath(spec->name);
    if (QFile::exists(path) && !QFile::remove(path)) {
        m_states[spec->name].error = tr("Could not delete this model.");
        emit modelsChanged();
        return false;
    }
    m_states.remove(spec->name);
    emit modelsChanged();
    return true;
}

void ModelDownloader::cleanupNetwork()
{
    // Detach before abort: Qt can synchronously emit finished() from abort().
    auto *reply = m_reply;
    auto *file = m_file;
    auto *manager = m_manager;
    m_reply = nullptr;
    m_file = nullptr;
    m_manager = nullptr;
    m_isDownloading = false;
    m_prepareAfterDownload = false;
    m_activeModel.clear();
    if (reply) {
        reply->disconnect(this);
        if (!reply->isFinished())
            reply->abort();
        reply->deleteLater();
    }
    if (file) {
        // Without commit(), QSaveFile discards its temporary file and preserves
        // any model already at the destination. Never enable direct fallback.
        delete file;
    }
    if (manager)
        manager->deleteLater();
}

void ModelDownloader::notifyIdle()
{
    if (!m_shuttingDown) {
        emit isDownloadingChanged();
        emit busyChanged();
        emit modelsChanged();
    }
}
