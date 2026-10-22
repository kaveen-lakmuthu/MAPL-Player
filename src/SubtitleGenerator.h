#ifndef SUBTITLEGENERATOR_H
#define SUBTITLEGENERATOR_H

#include <QObject>
#include <QThread>
#include <QVariantList>
#include <QtQml/QQmlEngine>
#include <atomic>
#include <memory>

class SubtitleGenerator : public QObject
{
    Q_OBJECT
    Q_PROPERTY(bool isProcessing READ isProcessing NOTIFY isProcessingChanged)
    Q_PROPERTY(bool isCancelling READ isCancelling NOTIFY isCancellingChanged)
    Q_PROPERTY(QString activeModelPath READ activeModelPath NOTIFY isProcessingChanged)
    QML_ELEMENT
public:
    explicit SubtitleGenerator(QObject *parent = nullptr);
    ~SubtitleGenerator() override;
    Q_INVOKABLE void generateSubtitles(const QString &mediaPath, const QString &modelPath,
                                      const QString &language, bool translate);
    Q_INVOKABLE void cancel();
    QString activeModelPath() const { return isProcessing() ? m_modelPath : QString(); }
    bool isProcessing() const { return m_thread != nullptr; }
    bool isCancelling() const { return isProcessing() && m_cancelled->load(); }
signals:
    void progressChanged(int progress);
    void subtitlesReady(const QVariantList &chunks);
    void errorOccurred(const QString &errorMsg);
    void cancelled();
    void isProcessingChanged();
    void isCancellingChanged();
private:
    friend class SubtitleGeneratorTest;
    QString m_ffmpegProgram = "ffmpeg";
    QString m_modelPath;
    QThread *m_thread = nullptr;
    std::shared_ptr<std::atomic_bool> m_cancelled;
};
#endif
