#include <QtTest>
#include <QAudioBuffer>
#include <QDataStream>
#include <array>
#include <cmath>
#include <limits>
#include <algorithm>
#include <numbers>
#include "AudioLevelMeter.h"
#include "MediaFixture.h"

class AudioLevelMeterTest : public QObject
{
    Q_OBJECT
    MediaFixture fixture;
private slots:
    void measuresDecodedSamples_data() {
        QTest::addColumn<int>("sampleFormat");
        QTest::addColumn<QByteArray>("samples");
        const auto bytes = [](const auto &samples) {
            return QByteArray(reinterpret_cast<const char *>(samples.data()), sizeof(samples));
        };
        QTest::newRow("unsigned-8") << int(QAudioFormat::UInt8) << bytes(std::array<quint8, 4>{128, 192, 64, 128});
        QTest::newRow("signed-16") << int(QAudioFormat::Int16) << bytes(std::array<qint16, 4>{0, 16384, -16384, 0});
        QTest::newRow("signed-32") << int(QAudioFormat::Int32) << bytes(std::array<qint32, 4>{0, 1073741824, -1073741824, 0});
        QTest::newRow("float") << int(QAudioFormat::Float) << bytes(std::array<float, 4>{0, .5f, -.5f, 0});
    }
    void measuresDecodedSamples() {
        QFETCH(int, sampleFormat);
        QFETCH(QByteArray, samples);
        QMediaPlayer player;
        QAudioOutput output;
        player.setAudioOutput(&output);
        player.setSource(fixture.url()); // Silent audio keeps arithmetic tests inaudible.
        player.play();
        QTRY_COMPARE(player.playbackState(), QMediaPlayer::PlayingState);
        AudioLevelMeter meter;
        meter.setPlayer(&player);
        QAudioFormat format;
        format.setSampleRate(8000);
        format.setChannelCount(2);
        format.setSampleFormat(QAudioFormat::SampleFormat(sampleFormat));
        meter.processBuffer(QAudioBuffer(samples, format));
        QVERIFY(meter.available());
        QVERIFY(std::abs(meter.rms() - std::sqrt(.125)) < .0001);
        QVERIFY(std::abs(meter.peak() - .5) < .0001);
        output.setVolume(.25);
        QVERIFY(std::abs(meter.rms() - std::sqrt(.125) * .25) < .0001);
        output.setMuted(true);
        QCOMPARE(meter.rms(), 0);
        QCOMPARE(meter.peak(), 0);
        output.setMuted(false);
        output.setVolume(0);
        QCOMPARE(meter.rms(), 0);
        output.setVolume(1);
        meter.processBuffer(QAudioBuffer(QByteArray(format.bytesPerSample() * 4, sampleFormat == QAudioFormat::UInt8 ? char(128) : char(0)), format));
        QCOMPARE(meter.rms(), 0);
        QCOMPARE(meter.peak(), 0);
        player.pause();
        QCOMPARE(meter.rms(), 0);
        QCOMPARE(meter.peak(), 0);
        QVERIFY(!meter.available());
    }
    void silenceSurroundAndNonFiniteSamples() {
        QMediaPlayer player;
        QAudioOutput output;
        player.setAudioOutput(&output);
        player.setSource(fixture.url());
        player.play();
        QTRY_COMPARE(player.playbackState(), QMediaPlayer::PlayingState);
        AudioLevelMeter meter;
        meter.setPlayer(&player);
        QAudioFormat format;
        format.setSampleRate(8000);
        format.setChannelCount(6);
        format.setSampleFormat(QAudioFormat::Float);
        std::array<float, 6> samples{0, 0, .5, 0, 0, 0};
        meter.processBuffer(QAudioBuffer(QByteArray(reinterpret_cast<const char *>(samples.data()), sizeof(samples)), format));
        QVERIFY(std::abs(meter.rms() - .5 / std::sqrt(6)) < .0001);
        QCOMPARE(meter.peak(), .5);
        samples = {0, 0, 0, 0, std::numeric_limits<float>::quiet_NaN(), std::numeric_limits<float>::infinity()};
        meter.processBuffer(QAudioBuffer(QByteArray(reinterpret_cast<const char *>(samples.data()), sizeof(samples)), format));
        QVERIFY(meter.available());
        QCOMPARE(meter.rms(), 0);
        QCOMPARE(meter.peak(), 0);
        meter.processBuffer(QAudioBuffer());
        QVERIFY(!meter.available());
    }
    void frequencyBandsFollowAudio_data() {
        QTest::addColumn<int>("frequency");
        QTest::addColumn<int>("sampleRate");
        QTest::addColumn<int>("channels");
        QTest::addColumn<bool>("oppositePhase");
        QTest::newRow("bass") << 80 << 48000 << 1 << false;
        QTest::newRow("midrange") << 1000 << 48000 << 1 << false;
        QTest::newRow("treble") << 8000 << 48000 << 1 << false;
        QTest::newRow("opposite-phase-stereo") << 1000 << 48000 << 2 << true;
        QTest::newRow("surround-center") << 1000 << 48000 << 6 << false;
        QTest::newRow("speech-sample-rate") << 440 << 8000 << 1 << false;
    }
    void frequencyBandsFollowAudio() {
        QFETCH(int, frequency);
        QFETCH(int, sampleRate);
        QFETCH(int, channels);
        QFETCH(bool, oppositePhase);
        QMediaPlayer player;
        QAudioOutput output;
        player.setAudioOutput(&output);
        player.setSource(fixture.url());
        player.play();
        QTRY_COMPARE(player.playbackState(), QMediaPlayer::PlayingState);
        AudioLevelMeter meter;
        meter.setPlayer(&player);
        QAudioFormat format;
        format.setSampleRate(sampleRate);
        format.setChannelCount(channels);
        format.setSampleFormat(QAudioFormat::Float);
        // Feed separate decoder packets to exercise the rolling analysis window.
        for (int offset = 0; offset < 4096; offset += 512) {
            std::vector<float> samples(512 * channels, 0);
            for (int i = 0; i < 512; ++i) {
                const float value = .5 * std::sin(2 * std::numbers::pi * frequency * (offset + i) / sampleRate);
                samples[i * channels + (channels == 6 ? 2 : 0)] = value;
                if (oppositePhase)
                    samples[i * channels + 1] = -value;
            }
            meter.processBuffer(QAudioBuffer(QByteArray(reinterpret_cast<const char *>(samples.data()), samples.size() * sizeof(float)), format));
        }
        auto bands = meter.spectrum();
        QCOMPARE(bands.size(), 24);
        int strongest = 0;
        double power = 0;
        for (int i = 0; i < bands.size(); ++i) {
            const double amplitude = bands[i].toDouble();
            if (amplitude > bands[strongest].toDouble())
                strongest = i;
            power += amplitude * amplitude;
        }
        const int expectedBand = std::min(23, int(std::log(frequency / 40.0) / std::log(std::min(16000.0, sampleRate / 2.0) / 40) * 24));
        QVERIFY2(std::abs(strongest - expectedBand) <= 1, qPrintable(QString("Strongest band %1, expected near %2").arg(strongest).arg(expectedBand)));
        const double expectedPower = channels == 6 ? .125 / 6 : .125;
        QVERIFY(std::abs(power - expectedPower) < .002);
        output.setVolume(.25);
        auto quieter = meter.spectrum();
        QVERIFY(std::abs(quieter[strongest].toDouble() - bands[strongest].toDouble() * .25) < .00001);
        output.setMuted(true);
        for (const auto &band : meter.spectrum())
            QCOMPARE(band.toDouble(), 0);
        output.setMuted(false);
        output.setVolume(1);
        meter.processBuffer(QAudioBuffer(QByteArray(4096 * channels * sizeof(float), char(0)), format));
        for (const auto &band : meter.spectrum())
            QCOMPARE(band.toDouble(), 0);
        meter.clear();
        QCOMPARE(meter.m_sampleCount, 0);
    }
    void realDecoderAndLifecycle() {
#if QT_VERSION < QT_VERSION_CHECK(6, 8, 0)
        QSKIP("Decoded audio buffers require Qt 6.8 or newer; QML uses a steady status indicator.");
#else
        const QString path = fixture.directory.filePath("levels.wav");
        QFile file(path);
        QVERIFY(file.open(QIODevice::WriteOnly));
        QDataStream stream(&file);
        stream.setByteOrder(QDataStream::LittleEndian);
        constexpr int frames = 8000 * 3;
        stream.writeRawData("RIFF", 4);
        stream << quint32(36 + frames * 4);
        stream.writeRawData("WAVEfmt ", 8);
        stream << quint32(16) << quint16(1) << quint16(2) << quint32(8000)
               << quint32(32000) << quint16(4) << quint16(16);
        stream.writeRawData("data", 4);
        stream << quint32(frames * 4);
        for (int i = 0; i < frames; ++i) {
            const double wave = std::sin(2 * 3.141592653589793 * 440 * i / 8000);
            stream << qint16(wave * 16384) << qint16(wave * 8192);
        }
        file.close();
        QMediaPlayer player;
        QAudioOutput output;
        output.setMuted(true);
        player.setAudioOutput(&output);
        AudioLevelMeter meter;
        meter.setPlayer(&player);
        QCOMPARE(player.audioOutput(), &output);
        QVERIFY(player.audioBufferOutput());
        player.setSource(QUrl::fromLocalFile(path));
        player.play();
        QTRY_VERIFY(meter.available() && meter.m_peak > .45 && *std::max_element(meter.m_bands.begin(), meter.m_bands.end()) > .1);
        QVERIFY(std::abs(meter.m_rms - std::sqrt((.25 + .0625) / 4)) < .01);
        QCOMPARE(meter.rms(), 0); // Buffers are pre-volume; the public meter follows mute.
        player.pause();
        QVERIFY(!meter.available());
        meter.setEnabled(false);
        QVERIFY(!player.audioBufferOutput());
        QCOMPARE(player.audioOutput(), &output);
        meter.setEnabled(true);
        QVERIFY(player.audioBufferOutput());
        player.play();
        QTRY_VERIFY(meter.available());
        QVERIFY(QMetaObject::invokeMethod(&meter.m_staleTimer, "timeout"));
        QCOMPARE(meter.m_rms, 0);
        QCOMPARE(meter.m_peak, 0);
        for (const auto &band : meter.spectrum())
            QCOMPARE(band.toDouble(), 0);
        player.setSource(fixture.url());
        QVERIFY(!meter.available());
        QMediaPlayer replacement;
        meter.setPlayer(&replacement);
        QVERIFY(!player.audioBufferOutput());
        QVERIFY(replacement.audioBufferOutput());
        meter.setPlayer(nullptr);
        QVERIFY(!replacement.audioBufferOutput());
        QCOMPARE(meter.peak(), 0);
#endif
    }
};
QTEST_GUILESS_MAIN(AudioLevelMeterTest)
#include "tst_audiolevelmeter.moc"
