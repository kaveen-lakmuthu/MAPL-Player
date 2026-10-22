#include "TranscriptionWorker.h"
#include <QFile>
#include <QThread>

// Only the model inference boundary is substituted. The production worker,
// ffmpeg process management, cancellation and thread teardown run unchanged.
QVariantList TranscriptionWorker::runWhisper(const QString &pcmPath)
{
    if (!QFile::exists(pcmPath)) {
        m_result->error = "Missing PCM file";
        return {};
    }
    emit progress(42);
    if (m_modelPath == "block") {
        while (!isCancelled())
            QThread::msleep(5);
        return {};
    }
    if (m_modelPath == "error") {
        m_result->error = "Inference failed";
        return {};
    }
    if (m_modelPath == "empty")
        return {};
    return {QVariantMap{{"start", 0.0}, {"end", 1.0}, {"text", "Hello."}}};
}
