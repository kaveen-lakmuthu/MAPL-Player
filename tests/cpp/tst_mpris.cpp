#include <QtTest>
#include <QDBusArgument>
#include <QDBusVariant>
#include <QDBusConnectionInterface>
#include <QDBusPendingCallWatcher>
#include <QEventLoop>
#include "MprisService.h"
#include "MediaFixture.h"

class BusObserver : public QObject {
    Q_OBJECT
public:
    QList<QVariantMap> changed;
    QList<qint64> seeks;
public slots:
    void propertiesChanged(const QString &interface, const QVariantMap &values, const QStringList &) {
        if (interface == "org.mpris.MediaPlayer2.Player") changed.append(values);
    }
    void seeked(qint64 position) { seeks.append(position); }
};

class MprisTest : public QObject
{
    Q_OBJECT
    QDBusConnection client{QString()};
    MediaFixture fixture;
    QDBusMessage call(const MprisService &service, const QString &interface, const QString &method, const QList<QVariant> &args = {}) {
        auto message = QDBusMessage::createMethodCall(service.serviceName(), "/org/mpris/MediaPlayer2", interface, method);
        message.setArguments(args);
        QDBusPendingCallWatcher watcher(client.asyncCall(message, 3000));
        QEventLoop loop;
        connect(&watcher, &QDBusPendingCallWatcher::finished, &loop, &QEventLoop::quit);
        QTimer::singleShot(3500, &loop, &QEventLoop::quit);
        if (!watcher.isFinished()) loop.exec();
        return watcher.isFinished() ? watcher.reply() : QDBusMessage::createError(QDBusError::Timeout, "D-Bus call timed out");
    }
    QVariantMap properties(const MprisService &service, const QString &interface = "org.mpris.MediaPlayer2.Player") {
        auto reply = call(service, "org.freedesktop.DBus.Properties", "GetAll", {interface});
        if (reply.type() == QDBusMessage::ErrorMessage) return {};
        return qdbus_cast<QVariantMap>(reply.arguments().first());
    }
    void configure(MprisService &service, QMediaPlayer &player, QAudioOutput &output) {
        output.setMuted(true);
        player.setAudioOutput(&output);
        service.setPlayer(&player);
        service.setAudioOutput(&output);
        service.setPlaylistCount(3);
        service.setTrackIndex(1);
        service.setTrackTitle("Audio #100%");
        service.setTrackUrl(fixture.url());
        service.setTrackRevision(1);
        player.setSource(fixture.url());
    }
private slots:
    void initTestCase() {
        client = QDBusConnection::connectToBus(QDBusConnection::SessionBus, "mapl-test-client");
        QVERIFY(client.isConnected());
    }
    void cleanupTestCase() { QDBusConnection::disconnectFromBus("mapl-test-client"); }
    void interfacesAndTypedMetadata() {
        QMediaPlayer player; QAudioOutput output; MprisService service;
        configure(service, player, output);
        QTRY_VERIFY(player.isSeekable());
        QVERIFY(service.start());
        auto root = properties(service, "org.mpris.MediaPlayer2");
        QCOMPARE(root.value("Identity").toString(), QString("MAPL Player"));
        QCOMPARE(root.value("DesktopEntry").toString(), QString("mapl-player"));
        QCOMPARE(root.value("SupportedUriSchemes").toStringList(), QStringList{"file"});
        auto values = properties(service);
        QCOMPARE(values.value("PlaybackStatus").toString(), QString("Stopped"));
        QCOMPARE(values.value("MinimumRate").toDouble(), 0.25);
        QCOMPARE(values.value("MaximumRate").toDouble(), 3);
        QVERIFY(values.value("CanSeek").toBool());
        QVERIFY(values.value("CanGoNext").toBool());
        auto metadata = qdbus_cast<QVariantMap>(values.value("Metadata"));
        QCOMPARE(metadata.value("mpris:length").toLongLong(), 60000000);
        QCOMPARE(metadata.value("mpris:trackid").value<QDBusObjectPath>().path(), service.trackId().path());
        QCOMPARE(metadata.value("xesam:url").toString(), fixture.url().toString());
        const auto xml = call(service, "org.freedesktop.DBus.Introspectable", "Introspect").arguments().first().toString();
        QVERIFY(xml.contains("org.mpris.MediaPlayer2.Player"));
        QVERIFY(xml.contains("Seeked"));
    }
    void transportCommandsAndWritableProperties() {
        QMediaPlayer player; QAudioOutput output; MprisService service;
        configure(service, player, output);
        QTRY_VERIFY(player.isSeekable());
        connect(&service, &MprisService::playRequested, &player, &QMediaPlayer::play);
        connect(&service, &MprisService::pauseRequested, &player, &QMediaPlayer::pause);
        connect(&service, &MprisService::stopRequested, &player, &QMediaPlayer::stop);
        connect(&service, &MprisService::rateRequested, &player, &QMediaPlayer::setPlaybackRate);
        connect(&service, &MprisService::volumeRequested, &output, [&output](double value) { output.setMuted(false); output.setVolume(value); });
        QSignalSpy next(&service, &MprisService::nextRequested), previous(&service, &MprisService::previousRequested);
        QSignalSpy quit(&service, &MprisService::quitRequested);
        QVERIFY(service.start());
        const QString api = "org.mpris.MediaPlayer2.Player";
        QCOMPARE(call(service, api, "Play").type(), QDBusMessage::ReplyMessage);
        QTRY_COMPARE(player.playbackState(), QMediaPlayer::PlayingState);
        call(service, api, "Pause");
        QTRY_COMPARE(player.playbackState(), QMediaPlayer::PausedState);
        call(service, api, "Next"); call(service, api, "Previous");
        QCOMPARE(next.count(), 1); QCOMPARE(previous.count(), 1);
        service.setTrackIndex(2);
        call(service, api, "Next");
        QCOMPARE(next.count(), 1);
        service.setLooping(true);
        call(service, api, "Next");
        QCOMPARE(next.count(), 2);
        service.setTrackIndex(1);
        auto setRate = call(service, "org.freedesktop.DBus.Properties", "Set", {api, "Rate", QVariant::fromValue(QDBusVariant(1.5))});
        QCOMPARE(setRate.type(), QDBusMessage::ReplyMessage);
        QCOMPARE(player.playbackRate(), 1.5);
        call(service, "org.freedesktop.DBus.Properties", "Set", {api, "Rate", QVariant::fromValue(QDBusVariant(-1.0))});
        QCOMPARE(player.playbackRate(), 1.5);
        call(service, api, "Play");
        call(service, "org.freedesktop.DBus.Properties", "Set", {api, "Rate", QVariant::fromValue(QDBusVariant(0.0))});
        QTRY_COMPARE(player.playbackState(), QMediaPlayer::PausedState);
        QCOMPARE(player.playbackRate(), 1.5);
        call(service, "org.freedesktop.DBus.Properties", "Set", {api, "Volume", QVariant::fromValue(QDBusVariant(0.35))});
        QCOMPARE(qRound(output.volume() * 100), 35);
        call(service, api, "Stop");
        QTRY_COMPARE(player.playbackState(), QMediaPlayer::StoppedState);
        call(service, "org.mpris.MediaPlayer2", "Quit");
        QCOMPARE(quit.count(), 1);
    }
    void seekUsesMicrosecondsAndRejectsStaleTrackIds() {
        QMediaPlayer player; QAudioOutput output; MprisService service;
        configure(service, player, output);
        QTRY_VERIFY(player.isSeekable());
        QVERIFY(service.start());
        BusObserver observer;
        QVERIFY(client.connect(service.serviceName(), "/org/mpris/MediaPlayer2", "org.mpris.MediaPlayer2.Player", "Seeked", &observer, SLOT(seeked(qint64))));
        const QString api = "org.mpris.MediaPlayer2.Player";
        const auto id = service.trackId();
        QCOMPARE(call(service, api, "SetPosition", {QVariant::fromValue(id), QVariant::fromValue<qlonglong>(12000000)}).type(), QDBusMessage::ReplyMessage);
        QCOMPARE(player.position(), 12000);
        QTRY_VERIFY(!observer.seeks.isEmpty());
        QCOMPARE(observer.seeks.last(), 12000000);
        call(service, api, "Seek", {QVariant::fromValue<qlonglong>(-2000000)});
        QCOMPARE(player.position(), 10000);
        service.setTrackRevision(2);
        call(service, api, "SetPosition", {QVariant::fromValue(id), QVariant::fromValue<qlonglong>(20000000)});
        QCOMPARE(player.position(), 10000);
        call(service, api, "SetPosition", {QVariant::fromValue(service.trackId()), QVariant::fromValue<qlonglong>(-1)});
        QCOMPARE(player.position(), 10000);
    }
    void changesArePublishedWithoutPositionSpam() {
        QMediaPlayer player; QAudioOutput output; MprisService service;
        configure(service, player, output);
        QVERIFY(service.start());
        BusObserver observer;
        QVERIFY(client.connect(service.serviceName(), "/org/mpris/MediaPlayer2", "org.freedesktop.DBus.Properties", "PropertiesChanged", &observer, SLOT(propertiesChanged(QString,QVariantMap,QStringList))));
        service.setTrackTitle("Changed title");
        service.publish();
        QTRY_VERIFY(!observer.changed.isEmpty());
        bool metadata = false;
        for (const auto &values : observer.changed) {
            metadata |= values.contains("Metadata");
            QVERIFY(!values.contains("Position"));
        }
        QVERIFY(metadata);
    }
    void localOpenUriAndMultipleInstances() {
        MprisService first, second;
        QVERIFY(first.start()); QVERIFY(second.start());
        QVERIFY(first.serviceName() != second.serviceName());
        QVERIFY(second.serviceName().startsWith("org.mpris.MediaPlayer2.mapl_player.instance"));
        QSignalSpy opened(&first, &MprisService::openUriRequested);
        QCOMPARE(call(first, "org.mpris.MediaPlayer2.Player", "OpenUri", {fixture.url().toString()}).type(), QDBusMessage::ReplyMessage);
        QCOMPARE(opened.count(), 1);
        QCOMPARE(call(first, "org.mpris.MediaPlayer2.Player", "OpenUri", {"https://example.invalid/movie.mp4"}).type(), QDBusMessage::ErrorMessage);
        QCOMPARE(opened.count(), 1);
        const auto name = second.serviceName();
        second.stop();
        QVERIFY(!client.interface()->isServiceRegistered(name).value());
    }
};
QTEST_GUILESS_MAIN(MprisTest)
#include "tst_mpris.moc"
