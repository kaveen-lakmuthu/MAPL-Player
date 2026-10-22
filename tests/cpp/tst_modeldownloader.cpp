#include <QtTest>
#include <QTemporaryDir>
#include <QBuffer>
#include "ModelDownloader.h"

// abort() emits synchronously, as a real QNetworkReply can do.
class SynchronousReply : public QNetworkReply
{
public:
    explicit SynchronousReply(QObject *parent) : QNetworkReply(parent) {
        open(QIODevice::ReadOnly);
        setAttribute(QNetworkRequest::HttpStatusCodeAttribute, 200);
    }
    QByteArray pending;
    qint64 bytesAvailable() const override { return pending.size() + QNetworkReply::bytesAvailable(); }
    void append(const QByteArray &data, bool notify = true) {
        pending += data;
        if (notify)
            emit readyRead();
    }
    void abort() override {
        setError(OperationCanceledError, "Cancelled");
        setFinished(true);
        emit errorOccurred(OperationCanceledError);
        emit finished();
    }
    void succeed(int status = 200) {
        setAttribute(QNetworkRequest::HttpStatusCodeAttribute, status);
        setFinished(true);
        emit finished();
    }
    void fail(bool notify = true) {
        setError(ConnectionRefusedError, "Connection refused");
        setFinished(true);
        if (notify)
            emit errorOccurred(ConnectionRefusedError);
        emit finished();
    }
protected:
    qint64 readData(char *data, qint64 maxSize) override {
        const auto size = qMin(maxSize, qint64(pending.size()));
        memcpy(data, pending.constData(), size);
        pending.remove(0, size);
        return size;
    }
};

class ShortWriteFile : public QSaveFile {
public:
    using QSaveFile::QSaveFile;
protected:
    qint64 writeData(const char *, qint64 size) override { return size - 1; }
};

class ModelDownloaderTest : public QObject
{
    Q_OBJECT
    const QByteArray content = "verified model fixture";
    void configure(ModelDownloader &downloader, const QString &directory) {
        downloader.m_modelDirectory = directory;
        downloader.m_catalog[0].bytes = content.size();
        downloader.m_catalog[0].sha256 = QCryptographicHash::hash(content, QCryptographicHash::Sha256).toHex();
    }
    QByteArray read(const QString &path) {
        QFile file(path);
        return file.open(QIODevice::ReadOnly) ? file.readAll() : QByteArray();
    }
    bool write(const QString &path, const QByteArray &bytes) {
        QFile file(path);
        return file.open(QIODevice::WriteOnly) && file.write(bytes) == bytes.size();
    }
    SynchronousReply *attachDownload(ModelDownloader &downloader, bool shortWrites = false) {
        downloader.m_activeModel = "tiny";
        downloader.m_destPath = downloader.getModelPath("tiny");
        downloader.m_file = shortWrites ? new ShortWriteFile(downloader.m_destPath, &downloader)
                                       : new QSaveFile(downloader.m_destPath, &downloader);
        downloader.m_file->setDirectWriteFallback(false);
        if (!downloader.m_file->open(QIODevice::WriteOnly))
            return nullptr;
        downloader.m_downloadHash.reset();
        downloader.m_bytesWritten = 0;
        downloader.m_manager = new QNetworkAccessManager(&downloader);
        auto *reply = new SynchronousReply(downloader.m_manager);
        downloader.m_reply = reply;
        downloader.m_isDownloading = true;
        downloader.connectReply();
        return reply;
    }
private slots:
    void cancellationNeverPublishesPartialData_data() {
        QTest::addColumn<bool>("previous");
        QTest::newRow("new-file") << false;
        QTest::newRow("preserve-existing") << true;
    }
    void cancellationNeverPublishesPartialData() {
        QFETCH(bool, previous);
        QTemporaryDir dir;
        ModelDownloader downloader;
        configure(downloader, dir.path());
        const auto path = downloader.getModelPath("tiny");
        if (previous)
            QVERIFY(write(path, "previous model"));
        auto *reply = attachDownload(downloader);
        QVERIFY(reply);
        QSignalSpy ready(&downloader, &ModelDownloader::downloadFinished);
        QSignalSpy error(&downloader, &ModelDownloader::downloadError);
        QSignalSpy cancelled(&downloader, &ModelDownloader::operationCancelled);
        reply->append(content.left(8));
        QCOMPARE(read(path), previous ? QByteArray("previous model") : QByteArray());
        downloader.cancelDownload();
        QCOMPARE(ready.count(), 0);
        QCOMPARE(error.count(), 0);
        QCOMPARE(cancelled.count(), 1);
        QVERIFY(!downloader.isBusy());
        QVERIFY(!downloader.m_file && !downloader.m_reply && !downloader.m_manager);
        QCOMPARE(read(path), previous ? QByteArray("previous model") : QByteArray());
        downloader.cancelDownload();
        reply->succeed();
        QCOMPARE(ready.count(), 0);
        QCOMPARE(cancelled.count(), 1);
        QCOMPARE(QDir(dir.path()).entryList(QDir::Files | QDir::Hidden).size(), previous ? 1 : 0);
    }
    void successPublishesOnlyAfterVerification() {
        QTemporaryDir dir;
        ModelDownloader downloader;
        configure(downloader, dir.path());
        auto *reply = attachDownload(downloader);
        QVERIFY(reply);
        QSignalSpy ready(&downloader, &ModelDownloader::downloadFinished);
        QSignalSpy errors(&downloader, &ModelDownloader::downloadError);
        QSignalSpy modelReady(&downloader, &ModelDownloader::modelReady);
        downloader.m_prepareAfterDownload = true;
        reply->append(content.left(8));
        QVERIFY(!QFile::exists(downloader.getModelPath("tiny")));
        reply->append(content.mid(8), false); // finished() must drain unread tail data.
        reply->succeed();
        QCOMPARE(ready.count(), 1);
        QCOMPARE(modelReady.count(), 1);
        QCOMPARE(errors.count(), 0);
        QCOMPARE(read(downloader.getModelPath("tiny")), content);
        QVERIFY(downloader.checkModelExists("tiny"));
        QCOMPARE(downloader.progress(), 100);
        QVERIFY(!downloader.isBusy());
    }
    void failedDownloadsPreserveExisting_data() {
        QTest::addColumn<QString>("failure");
        for (const auto &name : {"checksum", "truncated", "oversized", "network", "silent-network", "http", "short-write", "commit"})
            QTest::newRow(name) << QString(name);
    }
    void failedDownloadsPreserveExisting() {
        QFETCH(QString, failure);
        QTemporaryDir dir;
        ModelDownloader downloader;
        configure(downloader, dir.path());
        const auto path = downloader.getModelPath("tiny");
        QVERIFY(write(path, "previous model"));
        auto *reply = attachDownload(downloader, failure == "short-write");
        QVERIFY(reply);
        QSignalSpy ready(&downloader, &ModelDownloader::downloadFinished);
        QSignalSpy errors(&downloader, &ModelDownloader::downloadError);
        QByteArray bytes = content;
        if (failure == "checksum") bytes[0] = '!';
        if (failure == "truncated") bytes.chop(1);
        if (failure == "oversized") bytes.append('!');
        reply->append(bytes);
        if (failure == "commit")
            downloader.m_file->cancelWriting();
        if (failure == "network" || failure == "silent-network")
            reply->fail(failure == "network");
        else
            reply->succeed(failure == "http" ? 403 : 200);
        QCOMPARE(ready.count(), 0);
        QCOMPARE(errors.count(), 1);
        QCOMPARE(read(path), QByteArray("previous model"));
        QVERIFY(!downloader.isBusy());
        QCOMPARE(QDir(dir.path()).entryList(QDir::Files | QDir::Hidden).size(), 1);
    }
    void cancellationDoesNotDestroyReentrantDownload() {
        QTemporaryDir dir;
        ModelDownloader downloader;
        configure(downloader, dir.path());
        QVERIFY(attachDownload(downloader));
        bool restarted = false;
        SynchronousReply *next = nullptr;
        connect(&downloader, &ModelDownloader::isDownloadingChanged, this, [&] {
            if (!restarted && !downloader.isDownloading()) {
                restarted = true;
                next = attachDownload(downloader);
            }
        });
        downloader.cancelDownload();
        QVERIFY(next);
        QVERIFY(downloader.isDownloading());
        QCOMPARE(downloader.m_reply, next);
        QVERIFY(downloader.m_file);
        downloader.cancelDownload();
    }
    void destructionDiscardsUncommittedFile() {
        QTemporaryDir dir;
        auto downloader = std::make_unique<ModelDownloader>();
        configure(*downloader, dir.path());
        const auto path = downloader->getModelPath("tiny");
        QVERIFY(write(path, "previous model"));
        auto *reply = attachDownload(*downloader);
        QVERIFY(reply);
        reply->append(content.left(4));
        QSignalSpy ready(downloader.get(), &ModelDownloader::downloadFinished);
        downloader.reset();
        QCOMPARE(ready.count(), 0);
        QCOMPARE(read(path), QByteArray("previous model"));
        QCOMPARE(QDir(dir.path()).entryList(QDir::Files | QDir::Hidden).size(), 1);
    }
    void existingModelsAreVerifiedAsynchronously() {
        QTemporaryDir dir;
        ModelDownloader downloader;
        configure(downloader, dir.path());
        QVERIFY(write(downloader.getModelPath("tiny"), content));
        QVERIFY(!downloader.checkModelExists("tiny"));
        QSignalSpy ready(&downloader, &ModelDownloader::modelReady);
        downloader.prepareModel("tiny");
        QVERIFY(downloader.isBusy());
        QTRY_COMPARE(ready.count(), 1);
        QVERIFY(downloader.checkModelExists("tiny"));
        QCOMPARE(ready.first()[0].toString(), QString("tiny"));
        QVERIFY(!downloader.isBusy());
    }
    void corruptedFilesAreNeverInstalled_data() {
        QTest::addColumn<bool>("rightSize");
        QTest::newRow("wrong-hash") << true;
        QTest::newRow("old-ten-megabyte-rule") << false;
    }
    void corruptedFilesAreNeverInstalled() {
        QFETCH(bool, rightSize);
        QTemporaryDir dir;
        ModelDownloader downloader;
        configure(downloader, dir.path());
        const auto bad = rightSize ? QByteArray(content.size(), '!') : QByteArray(11 * 1024 * 1024, '!');
        QVERIFY(write(downloader.getModelPath("tiny"), bad));
        downloader.refreshModels();
        QTRY_VERIFY(!downloader.isBusy());
        QVERIFY(!downloader.checkModelExists("tiny"));
        const auto row = downloader.models().first().toMap();
        QCOMPARE(row.value("status").toString(), QString("Invalid"));
        QCOMPARE(row.value("installedBytes").toLongLong(), bad.size());
        QVERIFY(row.value("present").toBool());
        QVERIFY(!row.value("verified").toBool());
        QVERIFY(!row.value("error").toString().isEmpty());
    }
    void modificationInvalidatesCachedDisplayStatus() {
        QTemporaryDir dir;
        ModelDownloader downloader;
        configure(downloader, dir.path());
        QVERIFY(write(downloader.getModelPath("tiny"), content));
        downloader.refreshModels();
        QTRY_VERIFY(!downloader.isBusy());
        QVERIFY(downloader.checkModelExists("tiny"));
        QVERIFY(write(downloader.getModelPath("tiny"), "modified"));
        QVERIFY(!downloader.checkModelExists("tiny"));
    }
    void verificationCanBeCancelledAndShutdown() {
        QTemporaryDir dir;
        ModelDownloader downloader;
        configure(downloader, dir.path());
        QVERIFY(write(downloader.getModelPath("tiny"), content));
        QSignalSpy ready(&downloader, &ModelDownloader::modelReady);
        QSignalSpy cancelled(&downloader, &ModelDownloader::operationCancelled);
        downloader.prepareModel("tiny");
        downloader.cancelOperation();
        QVERIFY(downloader.isBusy());
        QTRY_VERIFY(!downloader.isBusy());
        QCOMPARE(ready.count(), 0);
        QCOMPARE(cancelled.count(), 1);
        QVERIFY(QFile::exists(downloader.getModelPath("tiny")));
        {
            ModelDownloader closing;
            configure(closing, dir.path());
            closing.prepareModel("tiny");
        }
    }
    void deletionHonoursBusyAndInUseGuards() {
        QTemporaryDir dir;
        ModelDownloader downloader;
        configure(downloader, dir.path());
        const auto path = downloader.getModelPath("tiny");
        QVERIFY(write(path, content));
        downloader.setInUsePath(path);
        QSignalSpy errors(&downloader, &ModelDownloader::downloadError);
        downloader.startDownload("tiny");
        QCOMPARE(errors.count(), 1);
        QVERIFY(!downloader.isBusy());
        QCOMPARE(read(path), content);
        QVERIFY(!downloader.deleteModel("tiny"));
        QVERIFY(QFile::exists(path));
        downloader.setInUsePath({});
        downloader.refreshModels();
        QVERIFY(!downloader.deleteModel("tiny"));
        QTRY_VERIFY(!downloader.isBusy());
        QVERIFY(downloader.deleteModel("tiny"));
        QVERIFY(!QFile::exists(path));
        QVERIFY(!downloader.checkModelExists("tiny"));
        QCOMPARE(downloader.models().first().toMap().value("installedBytes").toLongLong(), 0);
    }
    void unwritableDestinationDoesNotStartNetworkRequest() {
        QTemporaryDir dir;
        ModelDownloader downloader;
        configure(downloader, dir.path());
        QVERIFY(QDir().mkpath(downloader.getModelPath("tiny")));
        QSignalSpy errors(&downloader, &ModelDownloader::downloadError);
        QSignalSpy ready(&downloader, &ModelDownloader::downloadFinished);
        downloader.startDownload("tiny");
        QCOMPARE(errors.count(), 1);
        QCOMPARE(ready.count(), 0);
        QVERIFY(!downloader.isBusy());
        QVERIFY(!downloader.m_file && !downloader.m_reply && !downloader.m_manager);
        QVERIFY(QFileInfo(downloader.getModelPath("tiny")).isDir());
    }
    void unknownModelsCannotEscapeTheModelDirectory() {
        ModelDownloader downloader;
        for (const auto &name : {"../elsewhere", "", "large", "tiny/../base"}) {
            QVERIFY(downloader.getModelPath(name).isEmpty());
            QVERIFY(!downloader.deleteModel(name));
            QVERIFY(!downloader.checkModelExists(name));
            QSignalSpy errors(&downloader, &ModelDownloader::downloadError);
            downloader.startDownload(name);
            QCOMPARE(errors.count(), 1);
            QVERIFY(!downloader.isBusy());
        }
    }
    void catalogueHasPinnedChecksumsAndSizes() {
        ModelDownloader downloader;
        QCOMPARE(downloader.models().size(), 2);
        for (const auto &spec : downloader.m_catalog) {
            QCOMPARE(spec.sha256.size(), 64);
            QVERIFY(spec.bytes > 10000000);
            QCOMPARE(spec.url.scheme(), QString("https"));
            QVERIFY(spec.url.path().contains("/5359861c739e955e79d9a303bcbc70fb988958b1/"));
        }
    }
};
QTEST_GUILESS_MAIN(ModelDownloaderTest)
#include "tst_modeldownloader.moc"
