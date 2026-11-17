#include <QtTest>
#include <memory>
#include <QStandardPaths>
#include <QTemporaryDir>
#include <QScopeGuard>
#include <QUrl>
#include <QVideoFrameFormat>
#ifdef Q_OS_UNIX
#include <csignal>
#include <sys/resource.h>
#endif
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
    void textExport_data()
    {
        QTest::addColumn<bool>("fileUrl");
        QTest::addColumn<bool>("overwrite");
        QTest::newRow("new-path") << false << false;
        QTest::newRow("new-url") << true << false;
        QTest::newRow("overwrite-path") << false << true;
        QTest::newRow("overwrite-url") << true << true;
    }
    void textExport()
    {
        QFETCH(bool, fileUrl);
        QFETCH(bool, overwrite);
        QTemporaryDir directory;
        QVERIFY(directory.isValid());
        const auto path = directory.filePath(QStringLiteral("Subtitles #50% සිංහල.srt"));
        if (overwrite) {
            QFile original(path);
            QVERIFY(original.open(QIODevice::WriteOnly));
            QCOMPARE(original.write("Previous subtitles"), 18);
        }
        const auto content = QStringLiteral("1\n00:00:01,000 --> 00:00:02,000\nසිංහල · 中文 · العربية\n\n");
        PlayerController controller;
        QVERIFY(controller.writeTextToFile(fileUrl ? QUrl::fromLocalFile(path).toString() : path, content));
        QFile output(path);
        QVERIFY(output.open(QIODevice::ReadOnly));
        QCOMPARE(output.readAll(), content.toUtf8());
        QCOMPARE(QDir(directory.path()).entryList(QDir::Files | QDir::Hidden).size(), 1);
    }
    void textExportRejectsInvalidDestinations()
    {
        QTemporaryDir directory;
        QVERIFY(directory.isValid());
        PlayerController controller;
        QVERIFY(!controller.writeTextToFile({}, "Subtitles"));
        QVERIFY(!controller.writeTextToFile(directory.path(), "Subtitles"));
        QVERIFY(!controller.writeTextToFile(directory.filePath("missing/export.srt"), "Subtitles"));
        QVERIFY(QDir(directory.path()).entryList(QDir::Files | QDir::Hidden).isEmpty());
    }
    void textExportNeverFallsBackToTruncatingExistingFile()
    {
        QTemporaryDir directory;
        QVERIFY(directory.isValid());
        const auto path = directory.filePath("existing.srt");
        const QByteArray previous = "Previous subtitles";
        {
            QFile original(path);
            QVERIFY(original.open(QIODevice::WriteOnly));
            QCOMPARE(original.write(previous), previous.size());
        }
        const auto permissions = QFile::permissions(directory.path());
        const auto restorePermissions = qScopeGuard([&] { QFile::setPermissions(directory.path(), permissions); });
        QVERIFY(QFile::setPermissions(directory.path(), QFile::ReadOwner | QFile::ExeOwner));
        QFile probe(directory.filePath("permission-probe"));
        if (probe.open(QIODevice::WriteOnly)) {
            probe.close();
            probe.remove();
            QSKIP("The current user can write to read-only directories");
        }
        PlayerController controller;
        QVERIFY(!controller.writeTextToFile(path, "Replacement subtitles"));
        QFile original(path);
        QVERIFY(original.open(QIODevice::ReadOnly));
        QCOMPARE(original.readAll(), previous);
    }
    void failedTextExportPreservesDestination_data()
    {
        QTest::addColumn<bool>("previous");
        QTest::addColumn<int>("contentSize");
        QTest::addColumn<int>("writeLimit");
        QTest::newRow("rejected-write-new") << false << 64 << 0;
        QTest::newRow("rejected-write-existing") << true << 64 << 0;
        QTest::newRow("partial-write-new") << false << 256 * 1024 << 4096;
        QTest::newRow("partial-write-existing") << true << 256 * 1024 << 4096;
    }
    void failedTextExportPreservesDestination()
    {
#ifdef Q_OS_UNIX
        QFETCH(bool, previous);
        QFETCH(int, contentSize);
        QFETCH(int, writeLimit);
        QTemporaryDir directory;
        QVERIFY(directory.isValid());
        const auto path = directory.filePath("export.srt");
        const QByteArray originalContent = "Previous subtitles";
        if (previous) {
            QFile original(path);
            QVERIFY(original.open(QIODevice::WriteOnly));
            QCOMPARE(original.write(originalContent), originalContent.size());
        }
        // A separate process limits writes without affecting the test runner.
        // A zero limit rejects writes; 4096 bytes allows only a partial export.
        QProcess child;
        child.start(QCoreApplication::applicationFilePath(), {"--export-with-write-limit", path,
                    QString::number(contentSize), QString::number(writeLimit)});
        QVERIFY(child.waitForStarted(3000));
        QVERIFY(child.waitForFinished(5000));
        QCOMPARE(child.exitStatus(), QProcess::NormalExit);
        QCOMPARE(child.exitCode(), 0); // The export must have reported failure.
        QFile original(path);
        if (previous) {
            QVERIFY(original.open(QIODevice::ReadOnly));
            QCOMPARE(original.readAll(), originalContent);
        } else {
            QVERIFY(!original.exists());
        }
        QCOMPARE(QDir(directory.path()).entryList(QDir::Files | QDir::Hidden).size(), previous ? 1 : 0);
#else
        QSKIP("File-size limits require Unix");
#endif
    }
    void xspfParsing_data()
    {
        QTest::addColumn<QString>("xml");
        QTest::addColumn<QString>("baseUrl");
        QTest::addColumn<QString>("expectedPath");
        QTest::addColumn<QString>("expectedTitle");
        const auto document = [](const QString &track) {
            return QStringLiteral("<playlist version=\"1\" xmlns=\"http://xspf.org/ns/0/\"><trackList><track>")
                + track + QStringLiteral("</track></trackList></playlist>");
        };
        QTest::newRow("named-entities") << document("<location>file:///music/A&amp;B.wav</location>"
            "<title>A &amp; B &lt;Live&gt; &quot;Mix&quot; &apos;OK&apos;</title>") << ""
            << "/music/A&B.wav" << "A & B <Live> \"Mix\" 'OK'";
        QTest::newRow("numeric-entities") << document("<location>file:///music/A&#38;B.wav</location>"
            "<title>&#x1F3B5; &#128512;</title>") << "" << "/music/A&B.wav" << QStringLiteral("🎵 😀");
        QTest::newRow("decode-xml-once") << document("<location>file:///music/A&amp;amp;B.wav</location>"
            "<title>A&amp;amp;B</title>") << "" << "/music/A&amp;B.wav" << "A&amp;B";
        QTest::newRow("preserve-uri-encoding") << document("<location>file:///music/A%26B%2526.wav</location>")
            << "" << "/music/A&B%26.wav" << "A&B%26.wav";
        QTest::newRow("cdata") << document("<location><![CDATA[file:///music/A&B.wav]]></location>"
            "<title><![CDATA[A & B <Live>]]></title>") << "" << "/music/A&B.wav" << "A & B <Live>";
        QTest::newRow("prefixed-namespace") << QStringLiteral("<x:playlist xmlns:x=\"http://xspf.org/ns/0/\">"
            "<x:trackList><x:track id=\"1\"><x:location>file:///music/A&amp;B.wav</x:location>"
            "<x:title>Prefixed</x:title></x:track></x:trackList></x:playlist>")
            << "" << "/music/A&B.wav" << "Prefixed";
        QTest::newRow("legacy-no-namespace") << QStringLiteral("<playlist><trackList><track>"
            "<location>file:///music/A&amp;B.wav</location></track></trackList></playlist>")
            << "" << "/music/A&B.wav" << "A&B.wav";
        QTest::newRow("relative-location") << document("<location>../media/A&amp;B.wav</location>")
            << "file:///lists/collection/Mix.xspf" << "/lists/media/A&B.wav" << "A&B.wav";
        QTest::newRow("xml-base") << QStringLiteral("<playlist xmlns=\"http://xspf.org/ns/0/\" xml:base=\"file:///music/\">"
            "<trackList xml:base=\"albums/\"><track xml:base=\"live/\"><location xml:base=\"../other/\">"
            "A&amp;B.wav</location></track></trackList></playlist>")
            << "" << "/music/albums/other/A&B.wav" << "A&B.wav";
        QTest::newRow("unicode-fallback-title") << document(QStringLiteral("<location>file:///music/සිංහල%20%23100%25.wav</location>"))
            << "" << QStringLiteral("/music/සිංහල #100%.wav") << QStringLiteral("සිංහල #100%.wav");
    }
    void xspfParsing()
    {
        QFETCH(QString, xml);
        QFETCH(QString, baseUrl);
        QFETCH(QString, expectedPath);
        QFETCH(QString, expectedTitle);
        PlayerController controller;
        const auto parsed = controller.parseXspf(xml, baseUrl);
        QVERIFY2(parsed.value("error").toString().isEmpty(), qPrintable(parsed.value("error").toString()));
        const auto tracks = parsed.value("tracks").toList();
        QCOMPARE(tracks.size(), 1);
        const auto track = tracks.first().toMap();
        QCOMPARE(QUrl(track.value("url").toString()).toLocalFile(), expectedPath);
        QCOMPARE(track.value("title").toString(), expectedTitle);
    }
    void xspfRejectsMalformedDocuments_data()
    {
        QTest::addColumn<QString>("xml");
        QTest::newRow("truncated") << "<playlist><trackList><track><location>file:///a.wav</location></track></trackList>";
        QTest::newRow("bare-ampersand") << "<playlist><trackList><track><location>file:///A&B.wav</location></track></trackList></playlist>";
        QTest::newRow("unknown-entity") << "<playlist><trackList><track><location>file:///A&unknown;B.wav</location></track></trackList></playlist>";
        QTest::newRow("trailing-content") << "<playlist><trackList><track><location>file:///a.wav</location></track></trackList></playlist><extra/>";
        QTest::newRow("wrong-root") << "<document><trackList><track><location>file:///a.wav</location></track></trackList></document>";
        QTest::newRow("foreign-namespace") << "<playlist xmlns=\"urn:other\"><trackList><track><location>file:///a.wav</location></track></trackList></playlist>";
    }
    void xspfRejectsMalformedDocuments()
    {
        QFETCH(QString, xml);
        PlayerController controller;
        const auto parsed = controller.parseXspf(xml);
        QVERIFY(!parsed.value("error").toString().isEmpty());
        QVERIFY2(parsed.value("tracks").toList().isEmpty(), "A valid prefix must not publish a partial playlist");
    }
    void xspfPreservesQueueOrderAndIgnoresExtensions()
    {
        PlayerController controller;
        const auto parsed = controller.parseXspf(QStringLiteral(
            "<playlist xmlns=\"http://xspf.org/ns/0/\" xmlns:other=\"urn:other\">"
            "<extension><track><location>file:///fake.wav</location></track></extension><trackList>"
            "<other:track><other:location>file:///foreign.wav</other:location></other:track>"
            "<track><title>No location</title></track><track><location>  </location></track>"
            "<track id=\"1\"><location/><location>file:///repeat.wav</location><location>file:///alternative.wav</location><title>First</title></track>"
            "<track><location>file:///repeat.wav</location><title>Second</title></track>"
            "</trackList></playlist>"));
        QVERIFY(parsed.value("error").toString().isEmpty());
        const auto tracks = parsed.value("tracks").toList();
        QCOMPARE(tracks.size(), 2);
        QCOMPARE(tracks[0].toMap().value("url").toString(), QString("file:///repeat.wav"));
        QCOMPARE(tracks[1].toMap().value("url").toString(), QString("file:///repeat.wav"));
        QCOMPARE(tracks[0].toMap().value("title").toString(), QString("First"));
        QCOMPARE(tracks[1].toMap().value("title").toString(), QString("Second"));
    }
    void subtitleFilenameMatching_data()
    {
        QTest::addColumn<QString>("mediaName");
        QTest::addColumn<QString>("subtitleName");
        QTest::addColumn<QString>("expectedLabel"); // Empty means no match.
        QTest::newRow("exact-srt") << "Episode1.mp4" << "Episode1.srt" << "Default";
        QTest::newRow("exact-vtt") << "Episode1.mp4" << "Episode1.vtt" << "Default";
        QTest::newRow("language-srt") << "Episode1.mp4" << "Episode1.en.srt" << "en";
        QTest::newRow("language-vtt") << "Episode1.mp4" << "Episode1.fr.vtt" << "fr";
        QTest::newRow("language-and-kind") << "Episode1.mp4" << "Episode1.en.forced.srt" << "en.forced";
        QTest::newRow("empty-qualifier") << "Episode1.mp4" << "Episode1..srt" << "";
        QTest::newRow("next-episode") << "Episode1.mp4" << "Episode10.srt" << "";
        QTest::newRow("next-episode-language") << "Episode1.mp4" << "Episode11.en.vtt" << "";
        QTest::newRow("longer-title") << "Episode1.mp4" << "Episode1Extra.srt" << "";
        QTest::newRow("space-continuation") << "Episode1.mp4" << "Episode1 0.srt" << "";
        QTest::newRow("dotted-title") << "Show.S01E01.mkv" << "Show.S01E01.en.srt" << "en";
        QTest::newRow("dotted-next-episode") << "Show.S01E01.mkv" << "Show.S01E010.srt" << "";
        QTest::newRow("bracketed-title") << "Show [2026].mp4" << "Show [2026].en.srt" << "en";
        QTest::newRow("literal-wildcard") << "Show*.mp4" << "Show*.en.vtt" << "en";
        QTest::newRow("wildcard-decoy") << "Show*.mp4" << "ShowExtra.en.srt" << "";
        QTest::newRow("case-insensitive") << "Episode1.mp4" << "EPISODE1.EN.SRT" << "EN";
        QTest::newRow("encoded-name") << QStringLiteral("Episode #1% සිංහල.mp4")
            << QStringLiteral("Episode #1% සිංහල.en.vtt") << "en";
        QTest::newRow("unsupported-format") << "Episode1.mp4" << "Episode1.ass" << "";
    }
    void subtitleFilenameMatching()
    {
        QFETCH(QString, mediaName);
        QFETCH(QString, subtitleName);
        QFETCH(QString, expectedLabel);
        QTemporaryDir directory;
        QVERIFY(directory.isValid());
        const auto path = directory.filePath(subtitleName);
        QFile subtitle(path);
        QVERIFY(subtitle.open(QIODevice::WriteOnly));
        subtitle.close();
        PlayerController controller;
        const auto matches = controller.findSubtitleFiles(QUrl::fromLocalFile(directory.filePath(mediaName)).toString());
        QCOMPARE(matches.size(), expectedLabel.isEmpty() ? 0 : 1);
        if (!expectedLabel.isEmpty()) {
            const auto match = matches.first().toMap();
            QCOMPARE(match.value("url").toString(), QUrl::fromLocalFile(path).toString());
            QCOMPARE(match.value("label").toString(), expectedLabel);
        }
    }
    void subtitleMatchesExcludeOtherEpisodesInTheSameFolder()
    {
        QTemporaryDir directory;
        QVERIFY(directory.isValid());
        for (const auto *name : {"Episode1.srt", "Episode1.en.forced.srt", "Episode1.fr.vtt",
                                 "Episode10.srt", "Episode11.en.vtt", "Episode1Extra.srt"}) {
            QFile subtitle(directory.filePath(name));
            QVERIFY(subtitle.open(QIODevice::WriteOnly));
        }
        PlayerController controller;
        const auto matches = controller.findSubtitleFiles(QUrl::fromLocalFile(directory.filePath("Episode1.mp4")).toString());
        QCOMPARE(matches.size(), 3);
        QMap<QString, QString> actual;
        for (const auto &match : matches) {
            const auto row = match.toMap();
            actual.insert(controller.getCleanFileName(row.value("url").toString()), row.value("label").toString());
        }
        const QMap<QString, QString> expected = {{"Episode1.srt", "Default"},
            {"Episode1.en.forced.srt", "en.forced"}, {"Episode1.fr.vtt", "fr"}};
        QCOMPARE(actual, expected);
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
int main(int argc, char **argv)
{
    QCoreApplication application(argc, argv);
#ifdef Q_OS_UNIX
    const auto arguments = application.arguments();
    if (arguments.value(1) == "--export-with-write-limit") {
        rlimit limit;
        if (getrlimit(RLIMIT_FSIZE, &limit) != 0)
            return 2;
        limit.rlim_cur = arguments.value(4).toULongLong();
        if (setrlimit(RLIMIT_FSIZE, &limit) != 0 || std::signal(SIGXFSZ, SIG_IGN) == SIG_ERR)
            return 2;
        PlayerController controller;
        return controller.writeTextToFile(arguments.value(2), QString(arguments.value(3).toInt(), QLatin1Char('x'))) ? 1 : 0;
    }
#endif
    PlayerControllerTest test;
    return QTest::qExec(&test, argc, argv);
}
#include "tst_playercontroller.moc"
