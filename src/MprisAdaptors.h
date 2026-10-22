#ifndef MPRISADAPTORS_H
#define MPRISADAPTORS_H
#include <QDBusAbstractAdaptor>
#include <QDBusMessage>
#include "MprisService.h"

class MprisRootAdaptor : public QDBusAbstractAdaptor
{
    Q_OBJECT
    Q_CLASSINFO("D-Bus Interface", "org.mpris.MediaPlayer2")
    Q_PROPERTY(bool CanQuit READ canQuit)
    Q_PROPERTY(bool CanRaise READ canRaise)
    Q_PROPERTY(bool HasTrackList READ hasTrackList)
    Q_PROPERTY(QString Identity READ identity)
    Q_PROPERTY(QString DesktopEntry READ desktopEntry)
    Q_PROPERTY(QStringList SupportedUriSchemes READ supportedUriSchemes)
    Q_PROPERTY(QStringList SupportedMimeTypes READ supportedMimeTypes)
public:
    explicit MprisRootAdaptor(MprisService *service) : QDBusAbstractAdaptor(service), m_service(service) {}
    bool canQuit() const { return true; }
    bool canRaise() const { return m_service->window() != nullptr; }
    bool hasTrackList() const { return false; }
    QString identity() const { return "MAPL Player"; }
    QString desktopEntry() const { return "mapl-player"; }
    QStringList supportedUriSchemes() const { return {"file"}; }
    QStringList supportedMimeTypes() const { return m_service->supportedMimeTypes(); }
public slots:
    void Raise() {
        if (auto *window = m_service->window()) {
            if (window->visibility() == QWindow::Minimized) window->showNormal();
            window->show(); window->raise(); window->requestActivate();
        }
    }
    void Quit() { emit m_service->quitRequested(); }
private:
    MprisService *m_service;
};

class MprisPlayerAdaptor : public QDBusAbstractAdaptor
{
    Q_OBJECT
    Q_CLASSINFO("D-Bus Interface", "org.mpris.MediaPlayer2.Player")
    Q_PROPERTY(QString PlaybackStatus READ playbackStatus)
    Q_PROPERTY(double Rate READ rate WRITE setRate)
    Q_PROPERTY(QVariantMap Metadata READ metadata)
    Q_PROPERTY(double Volume READ volume WRITE setVolume)
    Q_PROPERTY(qlonglong Position READ position)
    Q_PROPERTY(double MinimumRate READ minimumRate)
    Q_PROPERTY(double MaximumRate READ maximumRate)
    Q_PROPERTY(bool CanGoNext READ canGoNext)
    Q_PROPERTY(bool CanGoPrevious READ canGoPrevious)
    Q_PROPERTY(bool CanPlay READ canPlay)
    Q_PROPERTY(bool CanPause READ canPause)
    Q_PROPERTY(bool CanSeek READ canSeek)
    Q_PROPERTY(bool CanControl READ canControl)
public:
    explicit MprisPlayerAdaptor(MprisService *service);
    QString playbackStatus() const { return m_service->playbackStatus(); }
    double rate() const { return m_service->player() ? m_service->player()->playbackRate() : 1; }
    void setRate(double rate);
    QVariantMap metadata() const { return m_service->metadata(); }
    double volume() const;
    void setVolume(double volume);
    qlonglong position() const { return m_service->player() ? m_service->player()->position() * 1000 : 0; }
    double minimumRate() const { return 0.25; }
    double maximumRate() const { return 3; }
    bool canGoNext() const { return m_service->canNext(); }
    bool canGoPrevious() const { return m_service->canPrevious(); }
    bool canPlay() const { return m_service->canPlay(); }
    bool canPause() const { return m_service->canPlay(); }
    bool canSeek() const { return m_service->canSeek(); }
    bool canControl() const { return true; }
public slots:
    void Next() { if (canGoNext()) emit m_service->nextRequested(); }
    void Previous() { if (canGoPrevious()) emit m_service->previousRequested(); }
    void Pause() { if (canPause() && playbackStatus() == "Playing") emit m_service->pauseRequested(); }
    void PlayPause() { if (canPlay()) emit m_service->toggleRequested(); }
    void Stop() { if (canPause()) emit m_service->stopRequested(); }
    void Play() { if (canPlay() && playbackStatus() != "Playing") emit m_service->playRequested(); }
    void Seek(qlonglong offset) { m_service->seekRelativeUs(offset); }
    void SetPosition(const QDBusObjectPath &trackId, qlonglong position) { m_service->setPositionUs(trackId, position); }
    void OpenUri(const QString &uri, const QDBusMessage &message);
signals:
    void Seeked(qlonglong position);
private:
    MprisService *m_service;
};
#endif
