#include <QtQuickTest/quicktest.h>
#include <QApplication>
#include <QQmlContext>
#include <QQmlEngine>
#include <QSettings>
#include <QTemporaryDir>
#include <QUrl>
#include <QFile>
#include <QDataStream>
#include <QDir>
#include "ModelDownloader.h"
#include "PlayerController.h"
#include "PlaybackHistory.h"
#include "PlaybackOptions.h"
#include "AudioLevelMeter.h"
#include "MprisService.h"

// UI smoke tests do not run inference or download model weights.
class SubtitleGeneratorStub : public QObject
{
    Q_OBJECT
    Q_PROPERTY(QString activeModelPath READ activeModelPath NOTIFY isProcessingChanged)
    Q_PROPERTY(bool isProcessing READ isProcessing NOTIFY isProcessingChanged)
    Q_PROPERTY(bool isCancelling READ isCancelling NOTIFY isCancellingChanged)
public:
    explicit SubtitleGeneratorStub(QObject *parent = nullptr) : QObject(parent) {}
    QString activeModelPath() const { return processing ? modelPath : QString(); }
    bool isProcessing() const { return processing; }
    bool isCancelling() const { return false; }
    Q_INVOKABLE void generateSubtitles(const QString &, const QString &path, const QString &, bool) {
        modelPath = path;
        processing = true;
        emit isProcessingChanged();
    }
    Q_INVOKABLE void cancel() {
        processing = false;
        emit cancelled();
        emit isProcessingChanged();
    }
private:
    QString modelPath;
    bool processing = false;
signals:
    void cancelled();
    void isCancellingChanged();
    void isProcessingChanged();
    void progressChanged(int progress);
    void subtitlesReady(const QVariantList &chunks);
    void errorOccurred(const QString &errorMsg);
};

class TestSetup : public QObject
{
    Q_OBJECT
public slots:
    void applicationAvailable()
    {
        QCoreApplication::setOrganizationName("MAPL Tests");
        QCoreApplication::setOrganizationDomain("tests.mapl.local");
        QCoreApplication::setApplicationName("MAPLPlayerNativeTests");
        QCoreApplication::setApplicationVersion(QStringLiteral(MAPL_APP_VERSION));
        QSettings::setPath(QSettings::NativeFormat, QSettings::UserScope, settings.path());
        QSettings::setPath(QSettings::IniFormat, QSettings::UserScope, settings.path());
        qputenv("XDG_CACHE_HOME", settings.path().toUtf8());
        // A minute of silent PCM exercises the real Qt Multimedia seek/load path.
        QFile audio(settings.filePath("Resume #1.wav"));
        if (audio.open(QIODevice::WriteOnly)) {
            const QByteArray silence(60 * 8000 * 2, char(0));
            QDataStream stream(&audio);
            stream.setByteOrder(QDataStream::LittleEndian);
            stream.writeRawData("RIFF", 4);
            stream << quint32(36 + silence.size());
            stream.writeRawData("WAVEfmt ", 8);
            stream << quint32(16) << quint16(1) << quint16(1) << quint32(8000)
                   << quint32(16000) << quint16(2) << quint16(16);
            stream.writeRawData("data", 4);
            stream << quint32(silence.size());
            stream.writeRawData(silence.constData(), silence.size());
        }
        audio.close();
        QDir().mkpath(settings.filePath("folder-queue"));
        for (const auto *name : {"01 First.wav", "02 Middle.wav", "03 Last.wav"})
            QFile::copy(audio.fileName(), settings.filePath(QStringLiteral("folder-queue/") + name));
        qmlRegisterType<PlaybackOptions>("MAPLPlayerNative", 1, 0, "PlaybackOptions");
        qmlRegisterType<AudioLevelMeter>("MAPLPlayerNative", 1, 0, "AudioLevelMeter");
        qmlRegisterType<MprisService>("MAPLPlayerNative", 1, 0, "MprisService");
        qmlRegisterType<PlaybackHistory>("MAPLPlayerNative", 1, 0, "PlaybackHistory");
        qmlRegisterType<PlayerController>("MAPLPlayerNative", 1, 0, "PlayerController");
        qmlRegisterType<ModelDownloader>("MAPLPlayerNative", 1, 0, "ModelDownloader");
        qmlRegisterType<SubtitleGeneratorStub>("MAPLPlayerNative", 1, 0, "SubtitleGenerator");
    }
    void qmlEngineAvailable(QQmlEngine *engine)
    {
        engine->rootContext()->setContextProperty("TestPaths", QVariantMap{
            {"mainQml", QUrl::fromLocalFile(QStringLiteral(MAPL_SOURCE_DIR "/qml/main.qml"))},
            {"audioUrl", QUrl::fromLocalFile(settings.filePath("Resume #1.wav")).toString()},
            {"folderMediaUrl", QUrl::fromLocalFile(settings.filePath("folder-queue/01 First.wav")).toString()}
        });
    }
private:
    QTemporaryDir settings;
};

int main(int argc, char **argv)
{
    // Match the production application, including the widget-based file dialog
    // and keyboard shortcut integration supplied by desktop platform themes.
    QApplication application(argc, argv);
    QTEST_SET_MAIN_SOURCE_PATH
    TestSetup setup;
    return quick_test_main_with_setup(argc, argv, "mapl", QUICK_TEST_SOURCE_DIR, &setup);
}
#include "qml_setup.moc"
