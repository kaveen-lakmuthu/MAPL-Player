#include "SubtitleGenerator.h"
#include "TranscriptionWorker.h"

SubtitleGenerator::SubtitleGenerator(QObject *parent) : QObject(parent) {}

SubtitleGenerator::~SubtitleGenerator()
{
    if (m_thread) {
        m_cancelled->store(true);
        m_thread->disconnect(this);
        // completed() quits the worker thread directly, even when the GUI event
        // loop is shutting down. Never destroy a running QThread.
        m_thread->quit();
        m_thread->wait();
        delete m_thread;
    }
}

void SubtitleGenerator::cancel()
{
    if (!isProcessing() || m_cancelled->exchange(true))
        return;
    emit isCancellingChanged();
}

void SubtitleGenerator::generateSubtitles(const QString &mediaPath, const QString &modelPath,
                                         const QString &language, bool translate)
{
    if (isProcessing())
        return;
    m_modelPath = modelPath;
    m_cancelled = std::make_shared<std::atomic_bool>(false);
    auto result = std::make_shared<TranscriptionResult>();
    auto *thread = new QThread(this);
    auto *worker = new TranscriptionWorker(mediaPath, modelPath, language, translate, m_cancelled, result, m_ffmpegProgram);
    worker->moveToThread(thread);
    m_thread = thread;
    connect(thread, &QThread::started, worker, &TranscriptionWorker::process);
    connect(worker, &TranscriptionWorker::progress, this, [this, thread, token = m_cancelled](int value) {
        if (m_thread == thread && m_cancelled == token && !token->load())
            emit progressChanged(value);
    });
    connect(worker, &TranscriptionWorker::completed, thread, &QThread::quit, Qt::DirectConnection);
    connect(thread, &QThread::finished, worker, &QObject::deleteLater);
    connect(thread, &QThread::finished, this, [this, thread, result] {
        // Join before signalling completion: no worker/process/temp files survive.
        thread->wait();
        const bool wasCancelled = m_cancelled->load();
        m_thread = nullptr;
        thread->deleteLater();
        if (wasCancelled)
            emit cancelled();
        else if (!result->error.isEmpty())
            emit errorOccurred(result->error);
        else
            emit subtitlesReady(result->chunks);
        emit isCancellingChanged();
        emit isProcessingChanged();
    });
    // Start before publishing state, so a synchronous cancellation/shutdown
    // listener always sees a thread that can finish.
    thread->start();
    emit isProcessingChanged();
}
