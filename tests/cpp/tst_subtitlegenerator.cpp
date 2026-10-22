#include <QtTest>
#include "SubtitleGenerator.h"
#include "ProcessFixture.h"

class SubtitleGeneratorTest : public QObject
{
    Q_OBJECT
private:
    void configure(SubtitleGenerator &generator) {
        generator.m_ffmpegProgram = QStringLiteral(MAPL_PROCESS_HELPER);
    }
private slots:
    void successAndFailures_data()
    {
        QTest::addColumn<QString>("model");
        QTest::addColumn<int>("exitCode");
        QTest::addColumn<int>("readyCount");
        QTest::newRow("success") << "success" << 0 << 1;
        QTest::newRow("inference-error") << "error" << 0 << 0;
        QTest::newRow("no-dialogue") << "empty" << 0 << 0;
        QTest::newRow("extraction-error") << "success" << 1 << 0;
    }
    void successAndFailures()
    {
        QFETCH(QString, model);
        QFETCH(int, exitCode);
        QFETCH(int, readyCount);
        ProcessFixture fixture(20, exitCode);
        SubtitleGenerator generator;
        configure(generator);
        QSignalSpy ready(&generator, &SubtitleGenerator::subtitlesReady);
        QSignalSpy error(&generator, &SubtitleGenerator::errorOccurred);
        QSignalSpy cancelled(&generator, &SubtitleGenerator::cancelled);
        generator.generateSubtitles(fixture.input, model, "English", false);
        QVERIFY(generator.isProcessing());
        QTRY_VERIFY(!generator.isProcessing());
        QCOMPARE(ready.count(), readyCount);
        QCOMPARE(error.count(), 1 - readyCount);
        QCOMPARE(cancelled.count(), 0);
        QVERIFY(fixture.reaped());
        QVERIFY(!QFile::exists(fixture.outputPath()));
        QVERIFY(!QFileInfo(fixture.outputPath()).dir().exists());
        QCOMPARE(generator.findChildren<QThread *>().size(), 0);
    }
    void cancelExtractionAndRetry()
    {
        ProcessFixture slow(10000);
        SubtitleGenerator generator;
        configure(generator);
        QSignalSpy ready(&generator, &SubtitleGenerator::subtitlesReady);
        QSignalSpy error(&generator, &SubtitleGenerator::errorOccurred);
        QSignalSpy cancelled(&generator, &SubtitleGenerator::cancelled);
        generator.generateSubtitles(slow.input, "success", "English", false);
        QTRY_VERIFY(slow.started());
        QVERIFY(QFile::exists(slow.outputPath()));
        generator.cancel();
        generator.cancel(); // Idempotent; the worker still owns the busy state.
        QVERIFY(generator.isProcessing());
        QVERIFY(generator.isCancelling());
        generator.generateSubtitles(slow.input, "success", "English", false);
        QTRY_VERIFY(!generator.isProcessing());
        QCOMPARE(cancelled.count(), 1);
        QCOMPARE(ready.count(), 0);
        QCOMPARE(error.count(), 0);
        QVERIFY(!generator.isCancelling());
        QVERIFY(slow.reaped());
        QVERIFY(!QFileInfo(slow.outputPath()).dir().exists());
        ProcessFixture fast;
        generator.generateSubtitles(fast.input, "success", "English", false);
        QTRY_COMPARE(ready.count(), 1);
        QCOMPARE(cancelled.count(), 1);
        QCOMPARE(error.count(), 0);
    }
    void cancelInference()
    {
        ProcessFixture fixture;
        SubtitleGenerator generator;
        configure(generator);
        QSignalSpy progress(&generator, &SubtitleGenerator::progressChanged);
        QSignalSpy ready(&generator, &SubtitleGenerator::subtitlesReady);
        QSignalSpy error(&generator, &SubtitleGenerator::errorOccurred);
        QSignalSpy cancelled(&generator, &SubtitleGenerator::cancelled);
        generator.generateSubtitles(fixture.input, "block", "English", false);
        QTRY_VERIFY(progress.count() >= 2);
        QCOMPARE(progress.last().first().toInt(), 42);
        generator.cancel();
        QTRY_COMPARE(cancelled.count(), 1);
        QVERIFY(!generator.isProcessing());
        QCOMPARE(ready.count(), 0);
        QCOMPARE(error.count(), 0);
        QVERIFY(!QFileInfo(fixture.outputPath()).dir().exists());
    }
    void cancellationWinsQueuedSuccess()
    {
        ProcessFixture fixture;
        SubtitleGenerator generator;
        configure(generator);
        QSignalSpy ready(&generator, &SubtitleGenerator::subtitlesReady);
        QSignalSpy cancelled(&generator, &SubtitleGenerator::cancelled);
        generator.generateSubtitles(fixture.input, "success", "English", false);
        // Let the worker finish while its GUI completion handler remains queued.
        QVERIFY(generator.m_thread->wait(3000));
        generator.cancel();
        QTRY_COMPARE(cancelled.count(), 1);
        QCOMPARE(ready.count(), 0);
    }
    void shutdown_data()
    {
        QTest::addColumn<bool>("inference");
        QTest::newRow("extraction") << false;
        QTest::newRow("inference") << true;
    }
    void shutdown()
    {
        QFETCH(bool, inference);
        ProcessFixture fixture(inference ? 20 : 10000);
        auto generator = std::make_unique<SubtitleGenerator>();
        configure(*generator);
        QSignalSpy progress(generator.get(), &SubtitleGenerator::progressChanged);
        generator->generateSubtitles(fixture.input, inference ? "block" : "success", "English", false);
        QTRY_VERIFY(fixture.started());
        if (inference)
            QTRY_VERIFY(progress.count() >= 2);
        QElapsedTimer timer;
        timer.start();
        generator.reset();
        QVERIFY(timer.elapsed() < 2000);
        QVERIFY(fixture.reaped());
        QVERIFY(!QFileInfo(fixture.outputPath()).dir().exists());
    }
    void immediateShutdown()
    {
        ProcessFixture fixture;
        SubtitleGenerator generator;
        configure(generator);
        generator.generateSubtitles(fixture.input, "block", "English", false);
        // Destructor must work before the worker's started signal is delivered.
    }
    void missingFfmpeg()
    {
        ProcessFixture fixture;
        SubtitleGenerator generator;
        generator.m_ffmpegProgram = fixture.directory.filePath("missing-program");
        QSignalSpy error(&generator, &SubtitleGenerator::errorOccurred);
        generator.generateSubtitles(fixture.input, "success", "English", false);
        QTRY_COMPARE(error.count(), 1);
        QVERIFY(!generator.isProcessing());
    }
};
QTEST_GUILESS_MAIN(SubtitleGeneratorTest)
#include "tst_subtitlegenerator.moc"
