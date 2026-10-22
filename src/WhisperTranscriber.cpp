#include "TranscriptionWorker.h"
#include "whisper.h"
#include <QFile>
#include <QRegularExpression>
#include <algorithm>
#include <cstring>
#include <thread>
#include <vector>

void TranscriptionWorker::whisperProgressCallback(whisper_context *, whisper_state *, int progress, void *data)
{
    auto *worker = static_cast<TranscriptionWorker *>(data);
    if (!worker->isCancelled())
        emit worker->progress(progress);
}

QVariantList TranscriptionWorker::runWhisper(const QString &pcmPath)
{
    QVariantList chunks;

    // Read the Float32 PCM values from file
    QFile file(pcmPath);
    if (!file.open(QIODevice::ReadOnly)) {
        m_result->error = tr("Failed to open extracted PCM file: %1").arg(pcmPath);
        return chunks;
    }

    QByteArray data = file.readAll();
    file.close();
    QFile::remove(pcmPath); // Cleanup disk immediately

    if (data.isEmpty() || data.size() % sizeof(float) != 0) {
        m_result->error = tr("Extracted audio PCM data is invalid or empty.");
        return chunks;
    }

    std::vector<float> pcmData(data.size() / sizeof(float));
    std::memcpy(pcmData.data(), data.constData(), data.size());

    if (isCancelled())
        return {};

    // Initialize whisper
    struct whisper_context_params cparams = whisper_context_default_params();
    cparams.use_gpu = true; // Use system GPU if configured by compiled whisper.cpp backend

    struct whisper_context * ctx = whisper_init_from_file_with_params(m_modelPath.toUtf8().constData(), cparams);
    if (!ctx) {
        m_result->error = tr("Failed to initialize Whisper model from file: %1").arg(m_modelPath);
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

    wparams.abort_callback = [](void *data) {
        return static_cast<TranscriptionWorker *>(data)->isCancelled();
    };
    wparams.abort_callback_user_data = this;
    wparams.encoder_begin_callback = [](whisper_context *, whisper_state *, void *data) {
        return !static_cast<TranscriptionWorker *>(data)->isCancelled();
    };
    wparams.encoder_begin_callback_user_data = this;
    if (isCancelled()) {
        whisper_free(ctx);
        return {};
    }

    // Run speech recognition
    int result = whisper_full(ctx, wparams, pcmData.data(), pcmData.size());
    if (isCancelled()) {
        whisper_free(ctx);
        return {};
    }
    if (result != 0) {
        m_result->error = tr("Whisper speech recognition inference failed (code %1).").arg(result);
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

