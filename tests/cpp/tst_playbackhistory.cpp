#include <QtTest>
#include <QTemporaryDir>
#include <QUrl>
#include "PlaybackHistory.h"

class PlaybackHistoryTest : public QObject
{
    Q_OBJECT
    QTemporaryDir settings;
    QString createFile(const QString &directory, const QString &name)
    {
        QFile file(QDir(directory).filePath(name));
        if (!file.open(QIODevice::WriteOnly))
            return {};
        file.write("media");
        return file.fileName();
    }
private slots:
    void initTestCase()
    {
        QVERIFY(settings.isValid());
        QSettings::setPath(QSettings::NativeFormat, QSettings::UserScope, settings.path());
        QSettings::setPath(QSettings::IniFormat, QSettings::UserScope, settings.path());
    }
    void init()
    {
        QSettings isolated("MAPL", "MAPLPlayerNative");
        isolated.clear();
        isolated.sync();
    }
    void persistsPositionsAndRecentFiles()
    {
        QTemporaryDir dir;
        const auto a = createFile(dir.path(), "A.mp4");
        const auto b = createFile(dir.path(), "B.mp3");
        {
            PlaybackHistory history;
            history.recordFile(a);
            history.savePosition(a, 25000, 120000);
            history.recordFile(b);
            history.savePosition(b, 45000, 180000);
            history.sync();
        }
        PlaybackHistory reopened;
        QCOMPARE(reopened.resumePosition(a), 25000);
        QCOMPARE(reopened.resumePosition(b), 45000);
        const auto entries = reopened.recentFiles();
        QCOMPARE(entries.size(), 2);
        QCOMPARE(entries.first().toMap().value("title").toString(), QString("B.mp3"));
        QCOMPARE(entries.last().toMap().value("url").toString(), QUrl::fromLocalFile(a).toString());
    }
    void encodedUrlsAndPlainPathsShareHistory()
    {
        QTemporaryDir dir;
        const auto path = createFile(dir.path(), "සිංහල Movie #100%.mp4");
        const auto url = QUrl::fromLocalFile(path).toString();
        PlaybackHistory history;
        history.recordFile(path);
        history.recordFile(url);
        history.savePosition(url, 12000, 90000);
        QCOMPARE(history.recentFiles().size(), 1);
        QCOMPARE(history.recentFiles().first().toMap().value("path").toString(), path);
        QCOMPARE(history.resumePosition(path), 12000);
    }
    void recentsAreBoundedAndReordered()
    {
        QTemporaryDir dir;
        PlaybackHistory history;
        QString oldest, newest;
        for (int i = 0; i < 25; ++i) {
            newest = createFile(dir.path(), QString::number(i) + ".mkv");
            if (i == 0)
                oldest = newest;
            history.recordFile(newest);
        }
        QCOMPARE(history.recentFiles().size(), 20);
        QCOMPARE(history.recentFiles().first().toMap().value("path").toString(), newest);
        history.recordFile(oldest);
        QCOMPARE(history.recentFiles().size(), 20);
        QCOMPARE(history.recentFiles().first().toMap().value("path").toString(), oldest);
        history.recordFile(oldest);
        QCOMPARE(history.recentFiles().size(), 20);
    }
    void clearRecentsPreservesPositions()
    {
        QTemporaryDir dir;
        const auto path = createFile(dir.path(), "movie.mp4");
        PlaybackHistory history;
        history.recordFile(path);
        history.savePosition(path, 30000, 120000);
        history.clearRecentFiles();
        QVERIFY(history.recentFiles().isEmpty());
        QCOMPARE(history.resumePosition(path), 30000);
        history.sync();
        PlaybackHistory reopened;
        QVERIFY(reopened.recentFiles().isEmpty());
        QCOMPARE(reopened.resumePosition(path), 30000);
    }
    void invalidAndMissingEntries()
    {
        QTemporaryDir dir;
        const auto path = createFile(dir.path(), "movie.mp4");
        PlaybackHistory history;
        history.recordFile("");
        history.recordFile("https://example.invalid/movie.mp4");
        history.recordFile(dir.path());
        history.recordFile(dir.filePath("missing.mp4"));
        QVERIFY(history.recentFiles().isEmpty());
        history.recordFile(path);
        QVERIFY(QFile::remove(path));
        QVERIFY(!history.isAvailable(path));
        QCOMPARE(history.recentFiles().size(), 1);
        QVERIFY(!history.recentFiles().first().toMap().value("available").toBool());
    }
    void resumeRules_data()
    {
        QTest::addColumn<qint64>("position");
        QTest::addColumn<qint64>("duration");
        QTest::addColumn<qint64>("expected");
        QTest::newRow("unfinished") << qint64(45000) << qint64(120000) << qint64(45000);
        QTest::newRow("opening") << qint64(4999) << qint64(120000) << qint64(0);
        QTest::newRow("five-seconds") << qint64(5000) << qint64(120000) << qint64(5000);
        QTest::newRow("near-end") << qint64(115000) << qint64(120000) << qint64(0);
        QTest::newRow("short-media") << qint64(20000) << qint64(30000) << qint64(20000);
        QTest::newRow("long-media-tail") << qint64(3591000) << qint64(3600000) << qint64(0);
        QTest::newRow("complete") << qint64(120000) << qint64(120000) << qint64(0);
        QTest::newRow("out-of-range") << qint64(200000) << qint64(120000) << qint64(0);
        QTest::newRow("negative") << qint64(-1) << qint64(120000) << qint64(0);
        QTest::newRow("unknown-duration") << qint64(45000) << qint64(0) << qint64(0);
    }
    void resumeRules()
    {
        QFETCH(qint64, position);
        QFETCH(qint64, duration);
        QFETCH(qint64, expected);
        PlaybackHistory history;
        history.savePosition("/tmp/movie.mp4", 20000, 120000);
        history.savePosition("/tmp/movie.mp4", position, duration);
        QCOMPARE(history.resumePosition("/tmp/movie.mp4"), expected);
    }
    void changedDurationAndExplicitReset()
    {
        PlaybackHistory history;
        history.savePosition("/tmp/movie.mp4", 80000, 120000);
        QCOMPARE(history.resumePosition("/tmp/movie.mp4", 60000), 0);
        QCOMPARE(history.resumePosition("/tmp/movie.mp4", 180000), 80000);
        history.clearPosition("/tmp/movie.mp4");
        QCOMPARE(history.resumePosition("/tmp/movie.mp4"), 0);
    }
};
QTEST_GUILESS_MAIN(PlaybackHistoryTest)
#include "tst_playbackhistory.moc"
