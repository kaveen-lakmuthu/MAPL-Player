#ifndef MODELDOWNLOADER_H
#define MODELDOWNLOADER_H

#include <QObject>
#include <QNetworkAccessManager>
#include <QNetworkReply>
#include <QFile>
#include <QDir>
#include <QtQml/QQmlEngine>

class ModelDownloader : public QObject
{
    Q_OBJECT
    Q_PROPERTY(bool isDownloading READ isDownloading NOTIFY isDownloadingChanged)
    QML_ELEMENT // Expose to QML

public:
    explicit ModelDownloader(QObject *parent = nullptr);
    ~ModelDownloader();

    Q_INVOKABLE bool checkModelExists(const QString &modelName) const;
    Q_INVOKABLE void startDownload(const QString &modelName);
    Q_INVOKABLE void cancelDownload();
    Q_INVOKABLE QString getModelPath(const QString &modelName) const;

    bool isDownloading() const;

signals:
    void progressChanged(double progress);
    void downloadFinished(const QString &filePath);
    void downloadError(const QString &errorMsg);
    void isDownloadingChanged();

private slots:
    void onDownloadProgress(qint64 bytesReceived, qint64 bytesTotal);
    void onFinished();
    void onErrorOccurred(QNetworkReply::NetworkError error);

private:
    QNetworkAccessManager *m_manager;
    QNetworkReply *m_reply;
    QFile *m_file;
    QString m_destPath;
    bool m_isDownloading;
    
    void cleanupNetwork();
};

#endif // MODELDOWNLOADER_H
