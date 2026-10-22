#include <QtTest>
#include <QSettings>
#include <QMediaMetaData>
#include <QStandardPaths>
#include <QProcess>
#include "PlaybackOptions.h"
#include "MediaFixture.h"

class PlaybackOptionsTest : public QObject
{
    Q_OBJECT
    QTemporaryDir settings;
    MediaFixture fixture;
private slots:
    void initTestCase() {
        QSettings::setPath(QSettings::NativeFormat, QSettings::UserScope, settings.path());
        QSettings::setPath(QSettings::IniFormat, QSettings::UserScope, settings.path());
    }
    void init() { QSettings("MAPL", "MAPLPlayerNative").clear(); }
    void playbackRateIsValidatedAndPersisted() {
        QMediaPlayer player;
        PlaybackOptions options;
        options.setPlayer(&player);
        options.setRate(1.5);
        QCOMPARE(player.playbackRate(), 1.5);
        QCOMPARE(options.rate(), 1.5);
        for (const double rate : {-1.0, 0.0, 0.1, 3.1, qQNaN(), qInf()})
            options.setRate(rate);
        QCOMPARE(options.rate(), 1.5);
        PlaybackOptions reopened;
        QCOMPARE(reopened.rate(), 1.5);
    }
    void signedDelayMovesTheActualAudioTimelineAndRestoresNormalOutput() {
        QMediaPlayer player;
        QAudioOutput output;
        output.setMuted(true);
        player.setAudioOutput(&output);
        PlaybackOptions options;
        options.setPlayer(&player);
        options.setAudioOutput(&output);
        QSignalSpy errors(&options, &PlaybackOptions::adjustmentError);
        player.setSource(fixture.url());
        QTRY_VERIFY(options.canAdjustDelay());
        player.pause();
        player.setPosition(10000);
        options.setAudioDelayMs(500);
        QVERIFY(options.m_audio);
        QVERIFY(player.audioOutput() != &output);
        QVERIFY(player.audioOutput());
        QVERIFY(player.audioOutput()->isMuted());
        QTRY_VERIFY(options.m_audio && options.m_audio->isSeekable());
        options.synchronize();
        QTRY_COMPARE(options.m_audio ? options.m_audio->position() : -1, 9500);
        options.setAudioDelayMs(-500);
        QTRY_COMPARE(options.m_audio ? options.m_audio->position() : -1, 10500);
        options.setRate(2);
        QTRY_COMPARE(options.m_audio ? options.m_audio->position() : -1, 11000);
        QCOMPARE(options.m_audio->playbackRate(), 2);
        player.play();
        QTRY_VERIFY(player.position() > 10100);
        QTRY_COMPARE(options.m_audio ? options.m_audio->playbackState() : QMediaPlayer::StoppedState, QMediaPlayer::PlayingState);
        player.pause();
        QTRY_COMPARE(options.m_audio ? options.m_audio->playbackState() : QMediaPlayer::StoppedState, QMediaPlayer::PausedState);
        QVERIFY(options.m_output);
        QVERIFY(options.m_output->isMuted());
        output.setVolume(0.25);
        QCOMPARE(options.m_output->volume(), 0.25f);
        options.resetAudioDelay();
        QCOMPARE(options.audioDelayMs(), 0);
        QVERIFY(!options.m_audio);
        QCOMPARE(player.audioOutput(), &output);
        QCOMPARE(player.playbackRate(), 2);
        QCOMPARE(errors.count(), 0);
    }
    void delayResetsOnSourceChangeAndBoundsAreEnforced() {
        QMediaPlayer player;
        QAudioOutput output;
        output.setMuted(true);
        player.setAudioOutput(&output);
        PlaybackOptions options;
        options.setPlayer(&player);
        options.setAudioOutput(&output);
        options.setAudioDelayMs(500);
        QCOMPARE(options.audioDelayMs(), 0);
        player.setSource(fixture.url());
        QTRY_VERIFY(options.canAdjustDelay());
        options.setRate(1.25);
        options.setAudioDelayMs(9000);
        QCOMPARE(options.audioDelayMs(), 2000);
        options.setAudioDelayMs(-9000);
        QCOMPARE(options.audioDelayMs(), -2000);
        player.setSource({});
        QCOMPARE(options.audioDelayMs(), 0);
        QVERIFY(!options.m_audio);
        QCOMPARE(player.audioOutput(), &output);
        QCOMPARE(options.rate(), 1.25);
    }
    void multilingualTracksCanBeSelected() {
        const auto ffmpeg = QStandardPaths::findExecutable("ffmpeg");
        if (ffmpeg.isEmpty()) QSKIP("ffmpeg is needed for multilingual media fixtures");
        const auto path = fixture.directory.filePath("multilingual.mkv");
        QProcess create;
        create.start(ffmpeg, {"-v", "error", "-y", "-f", "lavfi", "-i", "sine=frequency=440:sample_rate=8000:duration=30",
                             "-f", "lavfi", "-i", "sine=frequency=880:sample_rate=8000:duration=30",
                             "-map", "0:a", "-map", "1:a", "-c:a", "pcm_s16le",
                             "-metadata:s:a:0", "language=eng", "-metadata:s:a:0", "title=Main",
                             "-metadata:s:a:1", "language=spa", "-metadata:s:a:1", "title=Commentary", path});
        QVERIFY(create.waitForFinished(5000));
        QCOMPARE(create.exitCode(), 0);
        QMediaPlayer player;
        PlaybackOptions options;
        options.setPlayer(&player);
        player.setSource(QUrl::fromLocalFile(path));
        QTRY_COMPARE(player.audioTracks().size(), 2);
        const auto tracks = options.audioTracks();
        QCOMPARE(tracks.size(), 3);
        QVERIFY(tracks[1].toMap().value("label").toString().contains("English"));
        QVERIFY(tracks[2].toMap().value("label").toString().contains("Spanish"));
        QVERIFY(tracks[2].toMap().value("label").toString().contains("Commentary"));
        options.selectAudioTrack(1);
        QCOMPARE(options.activeAudioTrack(), 1);
        options.selectAudioTrack(9);
        QCOMPARE(options.activeAudioTrack(), 1);
        options.selectAudioTrack(-1);
        QCOMPARE(options.activeAudioTrack(), -1);
    }
    void destroyingDelayedPlaybackRestoresOutput() {
        QMediaPlayer player;
        QAudioOutput output;
        output.setMuted(true);
        player.setAudioOutput(&output);
        player.setSource(fixture.url());
        QTRY_VERIFY(player.isSeekable());
        {
            PlaybackOptions options;
            options.setPlayer(&player);
            options.setAudioOutput(&output);
            options.setAudioDelayMs(250);
            QVERIFY(options.m_audio);
        }
        QCOMPARE(player.audioOutput(), &output);
    }
};
QTEST_GUILESS_MAIN(PlaybackOptionsTest)
#include "tst_playbackoptions.moc"
