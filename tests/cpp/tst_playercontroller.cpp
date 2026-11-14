#include <QtTest>
#include <memory>
#include <QStandardPaths>
#include <QTemporaryDir>
#include <QUrl>
#include <QVideoFrameFormat>
#include "PlayerController.h"
#include "BackgroundProcess.h"
#include "ProcessFixture.h"

class PlayerControllerTest : public QObject
{
    Q_OBJECT
    QTemporaryDir settingsDirectory;
private slots:
    void initTestCase()
    {
        QVERIFY(settingsDirectory.isValid());
        QSettings::setPath(QSettings::NativeFormat, QSettings::UserScope, settingsDirectory.path());
    }
    void thumbnailRequiresAFrameFromTheCurrentTrack()
    {
        PlayerController controller;
        QSignalSpy available(&controller, &PlayerController::hasVideoFrameChanged);
        QSignalSpy captured(&controller, &PlayerController::thumbnailCaptured);
        QVERIFY(!controller.hasVideoFrame());
        controller.captureThumbnail("file:///first.mp4");
        QCOMPARE(captured.count(), 0);

        QVideoFrame frame(QVideoFrameFormat(QSize(16, 16), QVideoFrameFormat::Format_RGBA8888));
        QVERIFY(frame.map(QVideoFrame::WriteOnly));
        QImage pixels(frame.bits(0), 16, 16, frame.bytesPerLine(0), QImage::Format_RGBA8888);
        pixels.fill(QColor("#d04030"));
        frame.unmap();
        controller.handleVideoFrame(frame);
        QVERIFY(controller.hasVideoFrame());
        QCOMPARE(available.count(), 1);
        controller.captureThumbnail("file:///first.mp4");
        QCOMPARE(captured.count(), 1);
        const QString firstCover = controller.getThumbnail("file:///first.mp4");
        QCOMPARE(QImage::fromData(QByteArray::fromBase64(firstCover.toLatin1())).pixelColor(0, 0), QColor("#d04030"));

        controller.resetVideoFrame();
        QVERIFY(!controller.hasVideoFrame());
        QCOMPARE(available.count(), 2);
        controller.captureThumbnail("file:///second.mp4");
        QCOMPARE(captured.count(), 1);
        QVERIFY(controller.getThumbnail("file:///second.mp4").isEmpty());
        QCOMPARE(controller.getThumbnail("file:///first.mp4"), firstCover);
        // Resetting a track also resets the sampling throttle for its first frame.
        controller.handleVideoFrame(frame);
        QVERIFY(controller.hasVideoFrame());
        QCOMPARE(available.count(), 3);
    }
    void asyncChapters()
    {
        ProcessFixture fixture(250, 0, R"({"chapters":[{"start_time":"12.5","tags":{"title":"Opening"}},{"start_time":"25"}]})");
        PlayerController controller;
        controller.m_ffprobeProgram = QStringLiteral(MAPL_PROCESS_HELPER);
        QSignalSpy ready(&controller, &PlayerController::mediaChaptersReady);
        QElapsedTimer elapsed;
        elapsed.start();
        controller.scanMediaChapters(fixture.input, 7);
        QVERIFY(elapsed.elapsed() < 150);
        QCOMPARE(ready.count(), 0);
        bool responsive = false;
        QTimer::singleShot(10, &controller, [&] { responsive = true; });
        QTRY_VERIFY(responsive);
        QCOMPARE(ready.count(), 0);
        QTRY_COMPARE(ready.count(), 1);
        QCOMPARE(ready.first()[0].toInt(), 7);
        const auto chapters = ready.first()[1].toList();
        QCOMPARE(chapters.size(), 2);
        QCOMPARE(chapters[0].toMap()["time"].toDouble(), 12.5);
        QCOMPARE(chapters[0].toMap()["title"].toString(), QString("Opening"));
        QCOMPARE(chapters[1].toMap()["title"].toString(), QString("Chapter 2"));
        QVERIFY(fixture.reaped());
    }
    void supersededChapters()
    {
        ProcessFixture slow(10000), fast;
        PlayerController controller;
        controller.m_ffprobeProgram = QStringLiteral(MAPL_PROCESS_HELPER);
        QSignalSpy ready(&controller, &PlayerController::mediaChaptersReady);
        controller.scanMediaChapters(slow.input, 1);
        QTRY_VERIFY(slow.started());
        controller.scanMediaChapters(fast.input, 2);
        QTRY_COMPARE(ready.count(), 1);
        QCOMPARE(ready.first()[0].toInt(), 2);
        QVERIFY(slow.reaped());
        QTRY_VERIFY(controller.findChildren<BackgroundProcess *>().isEmpty());
    }
    void chapterFailures_data()
    {
        QTest::addColumn<QString>("failure");
        for (const auto &failure : {"timeout", "start", "exit", "invalid-json", "missing-media"})
            QTest::newRow(failure) << QString(failure);
    }
    void chapterFailures()
    {
        QFETCH(QString, failure);
        ProcessFixture fixture(failure == "timeout" ? 10000 : 20, failure == "exit" ? 1 : 0, "invalid");
        PlayerController controller;
        controller.m_ffprobeProgram = failure == "start" ? fixture.directory.filePath("missing-program") : QStringLiteral(MAPL_PROCESS_HELPER);
        controller.m_chapterTimeoutMs = failure == "timeout" ? 100 : 3000;
        QSignalSpy ready(&controller, &PlayerController::mediaChaptersReady);
        controller.scanMediaChapters(failure == "missing-media" ? "" : fixture.input, 5);
        QCOMPARE(ready.count(), 0);
        QTRY_COMPARE(ready.count(), 1);
        QVERIFY(ready.first()[1].toList().isEmpty());
        if (fixture.started())
            QVERIFY(fixture.reaped());
        QTRY_VERIFY(controller.findChildren<BackgroundProcess *>().isEmpty());
    }
    void asyncExtraction()
    {
        ProcessFixture fixture(250, 0, "1\n00:00:00,000 --> 00:00:01,000\nHello.\n");
        QString output;
        {
            PlayerController controller;
            controller.m_ffmpegProgram = QStringLiteral(MAPL_PROCESS_HELPER);
            QSignalSpy ready(&controller, &PlayerController::embeddedSubtitleReady);
            QElapsedTimer elapsed;
            elapsed.start();
            controller.extractEmbeddedSubtitle(fixture.input, 2, 9);
            QVERIFY(elapsed.elapsed() < 150);
            QCOMPARE(ready.count(), 0);
            QTRY_COMPARE(ready.count(), 1);
            QCOMPARE(ready.first()[0].toInt(), 9);
            output = QUrl(ready.first()[1].toString()).toLocalFile();
            QFile file(output);
            QVERIFY(file.open(QIODevice::ReadOnly));
            QVERIFY(file.readAll().contains("Hello."));
            QVERIFY(fixture.reaped());
        }
        QVERIFY(!QFile::exists(output));
    }
    void extractionFailures_data()
    {
        QTest::addColumn<QString>("failure");
        for (const auto &failure : {"timeout", "start", "exit", "invalid-index", "missing-media", "empty-output"})
            QTest::newRow(failure) << QString(failure);
    }
    void extractionFailures()
    {
        QFETCH(QString, failure);
        ProcessFixture fixture(failure == "timeout" ? 10000 : 20,
                               failure == "exit" ? 1 : 0, failure == "empty-output" ? "" : "subtitle");
        PlayerController controller;
        controller.m_ffmpegProgram = failure == "start" ? fixture.directory.filePath("missing-program") : QStringLiteral(MAPL_PROCESS_HELPER);
        controller.m_subtitleTimeoutMs = failure == "timeout" ? 100 : 3000;
        QSignalSpy error(&controller, &PlayerController::embeddedSubtitleError);
        QSignalSpy ready(&controller, &PlayerController::embeddedSubtitleReady);
        controller.extractEmbeddedSubtitle(failure == "missing-media" ? "" : fixture.input,
                                           failure == "invalid-index" ? -1 : 0, 4);
        QCOMPARE(error.count(), 0);
        QTRY_COMPARE(error.count(), 1);
        QCOMPARE(ready.count(), 0);
        if (fixture.started()) {
            QVERIFY(fixture.reaped());
            QVERIFY(!QFile::exists(fixture.outputPath()));
        }
        QVERIFY(QDir(controller.m_subtitleDirectory.path()).entryList(QDir::Files).isEmpty());
    }
    void cancelAndSupersedeExtraction()
    {
        ProcessFixture slow(10000), fast(20, 0, "subtitles");
        PlayerController controller;
        controller.m_ffmpegProgram = QStringLiteral(MAPL_PROCESS_HELPER);
        QSignalSpy ready(&controller, &PlayerController::embeddedSubtitleReady);
        QSignalSpy error(&controller, &PlayerController::embeddedSubtitleError);
        controller.extractEmbeddedSubtitle(slow.input, 0, 1);
        QTRY_VERIFY(slow.started());
        controller.cancelSubtitleExtraction();
        controller.cancelSubtitleExtraction();
        controller.extractEmbeddedSubtitle(fast.input, 1, 2);
        QTRY_COMPARE(ready.count(), 1);
        QCOMPARE(ready.first()[0].toInt(), 2);
        QCOMPARE(error.count(), 0);
        QVERIFY(slow.reaped());
        QVERIFY(!QFile::exists(slow.outputPath()));
    }
    void cancelBeforeProcessesStart()
    {
        ProcessFixture fixture(10000);
        PlayerController controller;
        controller.m_ffmpegProgram = controller.m_ffprobeProgram = QStringLiteral(MAPL_PROCESS_HELPER);
        QSignalSpy chapters(&controller, &PlayerController::mediaChaptersReady);
        QSignalSpy subtitles(&controller, &PlayerController::embeddedSubtitleReady);
        QSignalSpy errors(&controller, &PlayerController::embeddedSubtitleError);
        controller.scanMediaChapters(fixture.input, 1);
        controller.extractEmbeddedSubtitle(fixture.input, 0, 1);
        controller.cancelMediaJobs();
        QTRY_VERIFY(controller.findChildren<BackgroundProcess *>().isEmpty());
        QCOMPARE(chapters.count(), 0);
        QCOMPARE(subtitles.count(), 0);
        QCOMPARE(errors.count(), 0);
        QVERIFY(QDir(controller.m_subtitleDirectory.path()).entryList(QDir::Files).isEmpty());
    }
    void shutdownBeforeProcessesStart()
    {
        ProcessFixture fixture(10000);
        QElapsedTimer timer;
        timer.start();
        {
            PlayerController controller;
            controller.m_ffmpegProgram = controller.m_ffprobeProgram = QStringLiteral(MAPL_PROCESS_HELPER);
            controller.scanMediaChapters(fixture.input, 1);
            controller.extractEmbeddedSubtitle(fixture.input, 0, 1);
        }
        QVERIFY(timer.elapsed() < 2000);
        if (fixture.started())
            QVERIFY(fixture.reaped());
    }
    void shutdownProcesses()
    {
        ProcessFixture chapters(10000), subtitles(10000);
        auto controller = std::make_unique<PlayerController>();
        controller->m_ffmpegProgram = controller->m_ffprobeProgram = QStringLiteral(MAPL_PROCESS_HELPER);
        controller->scanMediaChapters(chapters.input, 1);
        controller->extractEmbeddedSubtitle(subtitles.input, 0, 1);
        QTRY_VERIFY(chapters.started() && subtitles.started());
        controller.reset();
        QVERIFY(chapters.reaped());
        QVERIFY(subtitles.reaped());
        QVERIFY(!QFile::exists(subtitles.outputPath()));
    }
    void realFfmpegJobs()
    {
        const auto ffmpeg = QStandardPaths::findExecutable("ffmpeg");
        if (ffmpeg.isEmpty() || QStandardPaths::findExecutable("ffprobe").isEmpty())
            QSKIP("Install ffmpeg/ffprobe to run the real-media integration check");
        QTemporaryDir fixture;
        QFile subtitles(fixture.filePath("captions.srt"));
        QVERIFY(subtitles.open(QIODevice::WriteOnly));
        subtitles.write("1\n00:00:00,250 --> 00:00:01,000\nHello. World.\n");
        subtitles.close();
        QFile metadata(fixture.filePath("chapters.ffmeta"));
        QVERIFY(metadata.open(QIODevice::WriteOnly));
        metadata.write(";FFMETADATA1\n[CHAPTER]\nTIMEBASE=1/1000\nSTART=250\nEND=1000\ntitle=Intro\n");
        metadata.close();
        const auto media = fixture.filePath("movie.mkv");
        QProcess createMedia;
        createMedia.start(ffmpeg, {"-v", "error", "-nostdin", "-f", "lavfi", "-i", "color=s=16x16:r=1:d=1",
                                  "-i", subtitles.fileName(), "-f", "ffmetadata", "-i", metadata.fileName(),
                                  "-map", "0:v", "-map", "1:s", "-map_chapters", "2", "-c:v", "ffv1",
                                  "-threads", "1", "-c:s", "srt", media});
        QVERIFY(createMedia.waitForFinished(5000));
        QCOMPARE(createMedia.exitCode(), 0);
        PlayerController controller;
        QSignalSpy chapters(&controller, &PlayerController::mediaChaptersReady);
        QSignalSpy extracted(&controller, &PlayerController::embeddedSubtitleReady);
        QSignalSpy error(&controller, &PlayerController::embeddedSubtitleError);
        const auto url = QUrl::fromLocalFile(media).toString();
        controller.scanMediaChapters(url, 1);
        controller.extractEmbeddedSubtitle(url, 0, 2);
        QTRY_COMPARE(chapters.count(), 1);
        QTRY_COMPARE(extracted.count(), 1);
        QCOMPARE(error.count(), 0);
        const auto chapter = chapters.first()[1].toList().first().toMap();
        QCOMPARE(chapter.value("title").toString(), QString("Intro"));
        QCOMPARE(chapter.value("time").toDouble(), 0.25);
        QFile result(QUrl(extracted.first()[1].toString()).toLocalFile());
        QVERIFY(result.open(QIODevice::ReadOnly));
        QVERIFY(result.readAll().contains("Hello. World."));
    }
    void supportedFormats_data()
    {
        QTest::addColumn<QString>("extension");
        const QStringList extensions = {"mp4", "mkv", "avi", "mov", "webm", "flv", "m4v",
            "ts", "ogv", "wmv", "3gp", "mpg", "mpeg", "mp3", "flac", "wav", "ogg", "m4a",
            "aac", "opus", "wma", "aiff", "wv", "ape", "OPUS", "WMV"};
        for (const auto &extension : extensions)
            QTest::newRow(qPrintable(extension)) << extension;
    }
    void supportedFormats()
    {
        QFETCH(QString, extension);
        QTemporaryDir dir;
        QVERIFY(dir.isValid());
        const QString selected = dir.filePath("selected." + extension);
        QFile file(selected);
        QVERIFY(file.open(QIODevice::WriteOnly));
        file.close();
        QFile neighbor(dir.filePath("neighbor.mp4"));
        QVERIFY(neighbor.open(QIODevice::WriteOnly));
        neighbor.close();
        PlayerController controller;
        const QString url = QUrl::fromLocalFile(selected).toString();
        const auto tracks = controller.getFilesInFolder(url);
        QCOMPARE(tracks.size(), 2);
        bool found = false;
        for (const auto &track : tracks)
            found |= track.toMap().value("url").toString() == url;
        QVERIFY2(found, "The explicitly opened format must be included in folder playback");
    }
    void excludesNonMediaEntries()
    {
        QTemporaryDir dir;
        QVERIFY(dir.isValid());
        for (const auto &name : {"movie.mp4", "movie.srt", "notes.txt", "cover.png"}) {
            QFile file(dir.filePath(name));
            QVERIFY(file.open(QIODevice::WriteOnly));
        }
        QVERIFY(QDir(dir.path()).mkdir("directory.mp4"));
        PlayerController controller;
        QCOMPARE(controller.getFilesInFolder(QUrl::fromLocalFile(dir.filePath("movie.mp4")).toString()).size(), 1);
    }
    void preservesEncodedNames()
    {
        QTemporaryDir dir;
        const QString path = dir.filePath("Movie #100% with spaces.opus");
        QFile file(path);
        QVERIFY(file.open(QIODevice::WriteOnly));
        file.close();
        PlayerController controller;
        const QString url = QUrl::fromLocalFile(path).toString();
        const auto tracks = controller.getFilesInFolder(url);
        QCOMPARE(tracks.size(), 1);
        QCOMPARE(tracks.first().toMap().value("url").toString(), url);
        QCOMPARE(controller.getCleanFileName(url), QString("Movie #100% with spaces.opus"));
    }
    void nonLocalFolderIsEmpty()
    {
        PlayerController controller;
        QVERIFY(controller.getFilesInFolder("https://example.invalid/movie.mp4").isEmpty());
    }
};
QTEST_GUILESS_MAIN(PlayerControllerTest)
#include "tst_playercontroller.moc"
