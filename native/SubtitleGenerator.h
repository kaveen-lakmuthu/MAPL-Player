#ifndef SUBTITLEGENERATOR_H
#define SUBTITLEGENERATOR_H

#include <QObject>
#include <QThread>
#include <QVariantList>
#include <QVariantMap>
#include <QProcess>
#include <QDir>
#include <QFile>
#include <QDateTime>
#include <QtQml/QQmlEngine>

// Worker class that performs the actual heavy lifting in a background thread
class TranscriptionWorker : public QObject
{
    Q_OBJECT
public:
    TranscriptionWorker(const QString &mediaPath, const QString &modelPath, const QString &language, bool translate);
    ~TranscriptionWorker();

signals:
    void progress(int value);
    void finished(const QVariantList &chunks);
    void error(const QString &errorMsg);

public slots:
    void process();

private:
    QString m_mediaPath;
    QString m_modelPath;
    QString m_language;
    bool m_translate;
    
    bool extractAudio(const QString &inputPath, const QString &outputPath);
    QVariantList runWhisper(const QString &pcmPath);

    // Dynamic static callback function for whisper progress
    static void whisperProgressCallback(struct whisper_context * ctx, struct whisper_state * state, int progress, void * user_data);
};

// Main controller class exposed to the QML UI
class SubtitleGenerator : public QObject
{
    Q_OBJECT
    Q_PROPERTY(bool isProcessing READ isProcessing NOTIFY isProcessingChanged)
    QML_ELEMENT // Expose to QML automatically in Qt6

public:
    explicit SubtitleGenerator(QObject *parent = nullptr);
    ~SubtitleGenerator();

    Q_INVOKABLE void generateSubtitles(const QString &mediaPath, const QString &modelPath, const QString &language, bool translate);
    
    bool isProcessing() const;

signals:
    void progressChanged(int progress);
    void subtitlesReady(const QVariantList &chunks);
    void errorOccurred(const QString &errorMsg);
    void isProcessingChanged();

private:
    bool m_isProcessing;
};

#endif // SUBTITLEGENERATOR_H
