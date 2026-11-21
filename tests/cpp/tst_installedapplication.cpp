#include <QtTest>
#include <QDBusConnection>
#include <QDBusMessage>
#include <QDBusVariant>
#include <QDBusArgument>
#include <QProcess>
#include <QProcessEnvironment>
#include "MediaFixture.h"

class InstalledApplicationTest : public QObject
{
    Q_OBJECT
private slots:
    void versionOptionPrintsBuildVersionAndExits()
    {
        QTemporaryDir directory;
        QVERIFY(directory.isValid());
        auto environment = QProcessEnvironment::systemEnvironment();
        environment.insert("QT_QPA_PLATFORM", "offscreen");
        environment.insert("XDG_CONFIG_HOME", directory.filePath("config"));
        environment.insert("XDG_CACHE_HOME", directory.filePath("cache"));
        environment.insert("XDG_DATA_HOME", directory.filePath("data"));
        QProcess process;
        process.setProcessEnvironment(environment);
        process.start(QString::fromUtf8(MAPL_APP_BINARY), {QStringLiteral("--version")});
        QVERIFY2(process.waitForStarted(3000), qPrintable(process.errorString()));
        QVERIFY(process.waitForFinished(3000));
        QCOMPARE(process.exitStatus(), QProcess::NormalExit);
        QCOMPARE(process.exitCode(), 0);
        QCOMPARE(QString::fromUtf8(process.readAllStandardOutput()).trimmed(),
                 QStringLiteral("MAPLPlayerNative " MAPL_APP_VERSION));
    }

    void relocatedExecutable_data()
    {
        QTest::addColumn<QString>("argumentKind");
        QTest::addColumn<bool>("systemStyle");
        QTest::newRow("application-menu") << QString() << false;
        QTest::newRow("open-with-path") << QString("path") << false;
        QTest::newRow("open-with-url") << QString("url") << false;
        QTest::newRow("desktop-theme") << QString() << true;
    }

    void relocatedExecutable()
    {
        QFETCH(QString, argumentKind);
        QFETCH(bool, systemStyle);
        QTemporaryDir installation;
        QVERIFY(installation.isValid());
        const QString executable = installation.filePath("mapl-player");
        QVERIFY(QFile::copy(QString::fromUtf8(MAPL_APP_BINARY), executable));
        QVERIFY(QFile::setPermissions(executable, QFileDevice::ReadOwner | QFileDevice::WriteOwner | QFileDevice::ExeOwner));
        MediaFixture media;
        QVERIFY(QFile::exists(media.path));

        auto environment = QProcessEnvironment::systemEnvironment();
        environment.insert("QT_QPA_PLATFORM", "offscreen");
        environment.insert("QT_QUICK_BACKEND", "software");
        if (systemStyle) environment.remove("QT_QUICK_CONTROLS_STYLE");
        else environment.insert("QT_QUICK_CONTROLS_STYLE", "Basic");
        environment.insert("QT_FORCE_STDERR_LOGGING", "1");
        environment.insert("XDG_CONFIG_HOME", installation.filePath("config"));
        environment.insert("XDG_CACHE_HOME", installation.filePath("cache"));
        environment.insert("XDG_DATA_HOME", installation.filePath("data"));
        environment.remove("QML_IMPORT_PATH");
        environment.remove("QML2_IMPORT_PATH");
        environment.remove("LD_LIBRARY_PATH");
        // QProcess also kills/reaps the child if an assertion returns early.
        QProcess process;
        process.setProcessEnvironment(environment);
        process.setWorkingDirectory(installation.path());
        process.setProcessChannelMode(QProcess::MergedChannels);
        QStringList arguments;
        if (argumentKind == "path") arguments << media.path;
        if (argumentKind == "url") arguments << media.url().toString(QUrl::FullyEncoded);
        process.start(executable, arguments);
        QVERIFY2(process.waitForStarted(3000), qPrintable(process.errorString()));

        const auto bus = QDBusConnection::sessionBus();
        QVERIFY(bus.isConnected());
        const auto call = [&bus](const QString &interface, const QString &method, const QList<QVariant> &arguments = {}) {
            auto message = QDBusMessage::createMethodCall("org.mpris.MediaPlayer2.mapl_player", "/org/mpris/MediaPlayer2", interface, method);
            message.setArguments(arguments);
            return bus.call(message, QDBus::Block, 1000);
        };
        const auto property = [&call](const QString &interface, const QString &name) {
            const auto reply = call("org.freedesktop.DBus.Properties", "Get", {interface, name});
            return reply.type() == QDBusMessage::ReplyMessage && !reply.arguments().isEmpty()
                ? reply.arguments().first().value<QDBusVariant>().variant() : QVariant();
        };

        QElapsedTimer timer;
        timer.start();
        bool ready = false;
        while (timer.elapsed() < 8000 && process.state() != QProcess::NotRunning) {
            ready = property("org.mpris.MediaPlayer2", "CanRaise").toBool();
            if (ready && !argumentKind.isEmpty()) {
                const auto metadata = qdbus_cast<QVariantMap>(property("org.mpris.MediaPlayer2.Player", "Metadata"));
                ready = QUrl(metadata.value("xesam:url").toString()) == media.url()
                    && metadata.value("mpris:length").toLongLong() > 0
                    && property("org.mpris.MediaPlayer2.Player", "PlaybackStatus").toString() == "Playing";
            }
            if (ready) break;
            QTest::qWait(50);
        }
        if (!ready) {
            process.kill();
            process.waitForFinished(3000);
            QFAIL(qPrintable(QString::fromUtf8(process.readAll())));
        }
        QCOMPARE(call("org.mpris.MediaPlayer2", "Quit").type(), QDBusMessage::ReplyMessage);
        QVERIFY(process.state() == QProcess::NotRunning || process.waitForFinished(5000));
        const QByteArray log = process.readAll();
        QVERIFY2(process.exitStatus() == QProcess::NormalExit && process.exitCode() == 0, log.constData());
        QVERIFY2(!log.contains("QQmlApplicationEngine failed"), log.constData());
        QVERIFY2(!log.contains("ReferenceError") && !log.contains("TypeError"), log.constData());
    }
};

QTEST_GUILESS_MAIN(InstalledApplicationTest)
#include "tst_installedapplication.moc"
