#include "SubtitleGenerator.h"
#include "whisper.h"
#include <QUrl>
#include <QFileInfo>
#include <QDebug>
#include <QRegularExpression>
#include <vector>
#include <cstring>
#include <thread>
#include <algorithm>

// --- TranscriptionWorker Implementation ---

TranscriptionWorker::TranscriptionWorker(const QString &mediaPath, const QString &modelPath, const QString &language, bool translate)
    : m_mediaPath(mediaPath)
    , m_modelPath(modelPath)
    , m_language(language)
    , m_translate(translate)
{
}

TranscriptionWorker::~TranscriptionWorker()
{
}

void TranscriptionWorker::whisperProgressCallback(struct whisper_context * /*ctx*/, struct whisper_state * /*state*/, int progress, void * user_data)
{
    TranscriptionWorker *worker = static_cast<TranscriptionWorker*>(user_data);
    emit worker->progress(progress);
}

bool TranscriptionWorker::extractAudio(const QString &inputPath, const QString &outputPath)
{
    // Convert input URL to a local file path if it is a file:/// URL
    QUrl url(inputPath);
    QString localInput = url.isLocalFile() ? url.toLocalFile() : inputPath;

    // Use QProcess to run ffmpeg
    QProcess ffmpeg;
    QStringList arguments;
    arguments << "-y" 
              << "-i" << localInput 
              << "-ar" << "16000" 
              << "-ac" << "1" 
              << "-f" << "f32le" 
              << outputPath;

    ffmpeg.start("ffmpeg", arguments);
    if (!ffmpeg.waitForStarted()) {
        qWarning() << "Failed to start ffmpeg process for audio extraction.";
        return false;
    }

    if (!ffmpeg.waitForFinished(-1)) { // Block until completion (-1 is no timeout)
        qWarning() << "ffmpeg audio extraction process crashed or timed out.";
        return false;
    }

    return ffmpeg.exitCode() == 0;
}

QVariantList TranscriptionWorker::runWhisper(const QString &pcmPath)
{
    QVariantList chunks;

    // Read the Float32 PCM values from file
    QFile file(pcmPath);
    if (!file.open(QIODevice::ReadOnly)) {
        emit error(tr("Failed to open extracted PCM file: %1").arg(pcmPath));
        return chunks;
    }

    QByteArray data = file.readAll();
    file.close();
    QFile::remove(pcmPath); // Cleanup disk immediately

    if (data.isEmpty() || data.size() % sizeof(float) != 0) {
        emit error(tr("Extracted audio PCM data is invalid or empty."));
        return chunks;
    }

    std::vector<float> pcmData(data.size() / sizeof(float));
    std::memcpy(pcmData.data(), data.constData(), data.size());

    // Initialize whisper
    struct whisper_context_params cparams = whisper_context_default_params();
    cparams.use_gpu = true; // Use system GPU if configured by compiled whisper.cpp backend

    struct whisper_context * ctx = whisper_init_from_file_with_params(m_modelPath.toUtf8().constData(), cparams);
    if (!ctx) {
        emit error(tr("Failed to initialize Whisper model from file: %1").arg(m_modelPath));
        return chunks;
    }

    // Set up Whisper params
    struct whisper_full_params wparams = whisper_full_default_params(WHISPER_SAMPLING_GREEDY);
    wparams.print_progress   = false;
    wparams.print_special    = false;
    wparams.print_realtime   = false;
    wparams.print_timestamps = false;
    wparams.translate        = m_translate;
    wparams.suppress_nst     = true;  // Suppress non-speech tokens (e.g. [Music], [Laughter])
    wparams.suppress_blank   = true;  // Suppress blank output at start
    wparams.suppress_regex   = R"(^\s*(\[[a-zA-Z].*\]|\([a-zA-Z].*\))\s*$)";
    
    // Convert language selections to ISO 639-1 two-letter codes for Whisper
    QString langCode = "auto";
    QString lowerLang = m_language.toLower();
    if (lowerLang == "english" || lowerLang == "en") {
        langCode = "en";
    } else if (lowerLang == "spanish" || lowerLang == "es") {
        langCode = "es";
    } else if (lowerLang == "french" || lowerLang == "fr") {
        langCode = "fr";
    } else if (lowerLang == "german" || lowerLang == "de") {
        langCode = "de";
    } else if (lowerLang == "japanese" || lowerLang == "ja") {
        langCode = "ja";
    } else if (lowerLang == "chinese" || lowerLang == "zh") {
        langCode = "zh";
    } else if (lowerLang == "korean" || lowerLang == "ko") {
        langCode = "ko";
    } else if (lowerLang == "russian" || lowerLang == "ru") {
        langCode = "ru";
    } else if (lowerLang == "portuguese" || lowerLang == "pt") {
        langCode = "pt";
    } else if (lowerLang == "italian" || lowerLang == "it") {
        langCode = "it";
    } else if (lowerLang == "auto-detect" || lowerLang.isEmpty()) {
        langCode = "auto";
    } else {
        langCode = lowerLang;
    }
    QByteArray langBytes = langCode.toUtf8();
    wparams.language = langBytes.constData();

    // Utilize up to 4 threads for dynamic local decoding
    wparams.n_threads = std::max(1, std::min(4, (int)std::thread::hardware_concurrency()));
    
    // Attach progress callback
    wparams.progress_callback = &TranscriptionWorker::whisperProgressCallback;
    wparams.progress_callback_user_data = this;

    // Run speech recognition
    int result = whisper_full(ctx, wparams, pcmData.data(), pcmData.size());
    if (result != 0) {
        emit error(tr("Whisper speech recognition inference failed (code %1).").arg(result));
        whisper_free(ctx);
        return chunks;
    }

    // Extract time segments
    int n_segments = whisper_full_n_segments(ctx);
    for (int i = 0; i < n_segments; ++i) {
        const char * text = whisper_full_get_segment_text(ctx, i);
        int64_t t0 = whisper_full_get_segment_t0(ctx, i);
        int64_t t1 = whisper_full_get_segment_t1(ctx, i);

        QString cleanText = QString::fromUtf8(text).trimmed();
        // Remove bracketed or parenthesized non-speech annotations (e.g. [Music], (Laughter), etc.)
        cleanText.remove(QRegularExpression(R"(\[[a-zA-Z].*?\])"));
        cleanText.remove(QRegularExpression(R"(\([a-zA-Z].*?\))"));
        cleanText = cleanText.trimmed();

        // Skip empty lines to prevent blank subtitle tracks
        if (cleanText.isEmpty()) {
            continue;
        }

        QVariantMap chunk;
        // whisper.cpp outputs in centiseconds, convert to seconds
        chunk["start"] = static_cast<double>(t0) / 100.0;
        chunk["end"] = static_cast<double>(t1) / 100.0;
        chunk["text"] = cleanText;
        chunks.append(chunk);
    }

    whisper_free(ctx);
    return chunks;
}

void TranscriptionWorker::process()
{
    // Generate unique temp file path for the audio track
    QString tempPcmPath = QDir::tempPath() + QString("/mapl_temp_%1.pcm").arg(QDateTime::currentMSecsSinceEpoch());

    emit progress(0); // Set progress to start

    // Step 1: Extract audio track to 16kHz mono PCM using ffmpeg
    if (!extractAudio(m_mediaPath, tempPcmPath)) {
        emit error(tr("Audio extraction failed. Please ensure 'ffmpeg' is installed on your system."));
        return;
    }

    // Step 2: Load model weights and run Whisper transcription
    QVariantList chunks = runWhisper(tempPcmPath);
    
    if (!chunks.isEmpty()) {
        emit finished(chunks);
    } else {
        // If runWhisper encountered an error, it already emitted the error() signal.
        // If it succeeded but returned nothing, emit error.
        QFile::remove(tempPcmPath); // Safe cleanup fallback
        if (chunks.isEmpty()) {
             emit error(tr("Transcription completed, but no dialogue segments were detected."));
        }
    }
}


// --- SubtitleGenerator Implementation ---

SubtitleGenerator::SubtitleGenerator(QObject *parent)
    : QObject(parent)
    , m_isProcessing(false)
{
}

SubtitleGenerator::~SubtitleGenerator()
{
}

bool SubtitleGenerator::isProcessing() const
{
    return m_isProcessing;
}

void SubtitleGenerator::generateSubtitles(const QString &mediaPath, const QString &modelPath, const QString &language, bool translate)
{
    if (m_isProcessing)
        return;

    m_isProcessing = true;
    emit isProcessingChanged();

    // Spawn QThread and worker
    QThread* thread = new QThread();
    TranscriptionWorker* worker = new TranscriptionWorker(mediaPath, modelPath, language, translate);
    worker->moveToThread(thread);

    // Setup signal routing
    connect(thread, &QThread::started, worker, &TranscriptionWorker::process);
    
    connect(worker, &TranscriptionWorker::progress, this, &SubtitleGenerator::progressChanged);
    
    connect(worker, &TranscriptionWorker::finished, this, [this, thread, worker](const QVariantList &chunks) {
        m_isProcessing = false;
        emit isProcessingChanged();
        emit subtitlesReady(chunks);
        thread->quit();
    });
    
    connect(worker, &TranscriptionWorker::error, this, [this, thread, worker](const QString &errorMsg) {
        m_isProcessing = false;
        emit isProcessingChanged();
        emit errorOccurred(errorMsg);
        thread->quit();
    });
    
    // Automatic cleanup loops
    connect(thread, &QThread::finished, worker, &QObject::deleteLater);
    connect(thread, &QThread::finished, thread, &QObject::deleteLater);

    thread->start();
}
