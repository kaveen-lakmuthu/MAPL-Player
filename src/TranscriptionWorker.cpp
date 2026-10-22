#include "TranscriptionWorker.h"
#include <QProcess>
#include <QDir>
#include <QTemporaryDir>
#include <QUrl>

TranscriptionWorker::TranscriptionWorker(const QString &mediaPath, const QString &modelPath,
                                       const QString &language, bool translate,
                                       std::shared_ptr<std::atomic_bool> cancelled,
                                       std::shared_ptr<TranscriptionResult> result, const QString &ffmpegProgram)
    : m_ffmpegProgram(ffmpegProgram), m_mediaPath(mediaPath), m_modelPath(modelPath), m_language(language), m_translate(translate),
      m_cancelled(std::move(cancelled)), m_result(std::move(result))
{
}

bool TranscriptionWorker::isCancelled() const
{
    return m_cancelled->load(std::memory_order_relaxed);
}

bool TranscriptionWorker::extractAudio(const QString &inputPath, const QString &outputPath)
{
    const QUrl url(inputPath);
    const QString localInput = url.isLocalFile() ? url.toLocalFile() : inputPath;
    QProcess ffmpeg;
    ffmpeg.setStandardOutputFile(QProcess::nullDevice());
    ffmpeg.setStandardErrorFile(QProcess::nullDevice());
    connect(&ffmpeg, &QProcess::started, &ffmpeg, [&] {
        if (isCancelled())
            ffmpeg.kill();
    });
    ffmpeg.start(m_ffmpegProgram, {"-v", "error", "-nostdin", "-y", "-i", localInput,
                           "-ar", "16000", "-ac", "1", "-f", "f32le", outputPath});
    // This loop runs only in the worker. It bounds cancellation latency while
    // extracting audio and reaps ffmpeg before its temporary directory is removed.
    while (ffmpeg.state() != QProcess::NotRunning) {
        if (isCancelled()) {
            ffmpeg.kill();
            ffmpeg.waitForFinished();
            return false;
        }
        ffmpeg.waitForFinished(50);
    }
    return ffmpeg.error() != QProcess::FailedToStart && ffmpeg.exitStatus() == QProcess::NormalExit
        && ffmpeg.exitCode() == 0;
}

void TranscriptionWorker::process()
{
    {
        // Scope cleanup happens before completed(), including every error/cancel path.
        QTemporaryDir temp(QDir::tempPath() + "/mapl-transcription-XXXXXX");
        if (!isCancelled()) {
            emit progress(0);
            if (!temp.isValid()) {
                m_result->error = tr("Could not create a temporary audio directory.");
            } else if (!extractAudio(m_mediaPath, temp.filePath("audio.pcm"))) {
                m_result->error = tr("Audio extraction failed. Please ensure 'ffmpeg' is installed on your system.");
            } else if (!isCancelled()) {
                m_result->chunks = runWhisper(temp.filePath("audio.pcm"));
                if (m_result->chunks.isEmpty() && m_result->error.isEmpty() && !isCancelled())
                    m_result->error = tr("Transcription completed, but no dialogue segments were detected.");
            }
        }
    }
    emit completed();
}
