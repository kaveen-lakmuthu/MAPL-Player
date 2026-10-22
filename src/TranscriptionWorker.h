#ifndef TRANSCRIPTIONWORKER_H
#define TRANSCRIPTIONWORKER_H

#include <QObject>
#include <QVariantList>
#include <atomic>
#include <memory>

struct TranscriptionResult {
    QVariantList chunks;
    QString error;
};

class TranscriptionWorker : public QObject
{
    Q_OBJECT
public:
    TranscriptionWorker(const QString &mediaPath, const QString &modelPath,
                        const QString &language, bool translate,
                        std::shared_ptr<std::atomic_bool> cancelled,
                        std::shared_ptr<TranscriptionResult> result, const QString &ffmpegProgram);
    bool isCancelled() const;
public slots:
    void process();
signals:
    void progress(int value);
    void completed();
private:
    QString m_ffmpegProgram;
    QString m_mediaPath;
    QString m_modelPath;
    QString m_language;
    bool m_translate;
    std::shared_ptr<std::atomic_bool> m_cancelled;
    std::shared_ptr<TranscriptionResult> m_result;
    bool extractAudio(const QString &inputPath, const QString &outputPath);
    QVariantList runWhisper(const QString &pcmPath);
    static void whisperProgressCallback(struct whisper_context *, struct whisper_state *, int, void *);
};
#endif
