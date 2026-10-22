#ifndef MODELDOWNLOADER_H
#define MODELDOWNLOADER_H

#include <QObject>
#include <QNetworkAccessManager>
#include <QNetworkReply>
#include <QSaveFile>
#include <QCryptographicHash>
#include <QThread>
#include <QVariantList>
#include <QHash>
#include <QtQml/QQmlEngine>
#include <atomic>
#include <memory>

class ModelDownloader : public QObject
{
    Q_OBJECT
    Q_PROPERTY(bool isDownloading READ isDownloading NOTIFY isDownloadingChanged)
    Q_PROPERTY(bool isBusy READ isBusy NOTIFY busyChanged)
    Q_PROPERTY(bool isVerifying READ isVerifying NOTIFY busyChanged)
    Q_PROPERTY(QString activeModel READ activeModel NOTIFY busyChanged)
    Q_PROPERTY(double progress READ progress NOTIFY progressChanged)
    Q_PROPERTY(QVariantList models READ models NOTIFY modelsChanged)
    Q_PROPERTY(QString inUsePath READ inUsePath WRITE setInUsePath NOTIFY modelsChanged)
    QML_ELEMENT
public:
    explicit ModelDownloader(QObject *parent = nullptr);
    ~ModelDownloader() override;
    // Cached display status only. prepareModel always rehashes existing files.
    Q_INVOKABLE bool checkModelExists(const QString &modelName) const;
    Q_INVOKABLE void prepareModel(const QString &modelName);
    Q_INVOKABLE void refreshModels();
    Q_INVOKABLE void startDownload(const QString &modelName);
    Q_INVOKABLE void cancelDownload();
    Q_INVOKABLE void cancelOperation();
    Q_INVOKABLE bool deleteModel(const QString &modelName);
    Q_INVOKABLE QString getModelPath(const QString &modelName) const;
    bool isDownloading() const { return m_isDownloading; }
    bool isVerifying() const { return m_verificationThread != nullptr; }
    bool isBusy() const { return isDownloading() || isVerifying(); }
    QString activeModel() const { return m_activeModel; }
    double progress() const { return m_progress; }
    QVariantList models() const;
    QString inUsePath() const { return m_inUsePath; }
    void setInUsePath(const QString &path);
signals:
    void progressChanged(double progress);
    void downloadFinished(const QString &filePath);
    void downloadError(const QString &errorMsg);
    void modelError(const QString &modelName, const QString &errorMsg);
    void operationCancelled(const QString &modelName);
    void modelReady(const QString &modelName, const QString &filePath);
    void isDownloadingChanged();
    void busyChanged();
    void modelsChanged();
private slots:
    void onDownloadProgress(qint64 bytesReceived, qint64 bytesTotal);
    void onFinished();
    void onErrorOccurred(QNetworkReply::NetworkError error);
private:
    friend class ModelDownloaderTest;
    struct ModelSpec {
        QString name;
        QString title;
        qint64 bytes;
        QByteArray sha256;
        QUrl url;
    };
    struct ModelState {
        QString status;
        QString error;
        QByteArray fingerprint;
        bool verified = false;
    };
    QList<ModelSpec> m_catalog;
    QHash<QString, ModelState> m_states;
    QString m_modelDirectory;
    QString m_activeModel;
    QString m_inUsePath;
    QNetworkAccessManager *m_manager = nullptr;
    QNetworkReply *m_reply = nullptr;
    QSaveFile *m_file = nullptr;
    QString m_destPath;
    bool m_isDownloading = false;
    bool m_prepareAfterDownload = false;
    bool m_shuttingDown = false;
    qint64 m_bytesWritten = 0;
    double m_progress = 0;
    QCryptographicHash m_downloadHash{QCryptographicHash::Sha256};
    QThread *m_verificationThread = nullptr;
    std::shared_ptr<std::atomic_bool> m_cancelVerification;
    const ModelSpec *specFor(const QString &modelName) const;
    static QByteArray fingerprint(const QString &path);
    bool isInUse(const QString &modelName) const;
    void verifyModels(const QStringList &names, bool prepare);
    void beginDownload(const QString &name, bool prepare);
    void notifyIdle();
    void connectReply();
    bool drainReply();
    void failDownload(const QString &message);
    void cleanupNetwork();
};
#endif
