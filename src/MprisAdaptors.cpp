#include "MprisAdaptors.h"
#include <algorithm>
#include <cmath>

MprisPlayerAdaptor::MprisPlayerAdaptor(MprisService *service) : QDBusAbstractAdaptor(service), m_service(service)
{
    connect(service, &MprisService::seeked, this, &MprisPlayerAdaptor::Seeked);
}

void MprisPlayerAdaptor::setRate(double value)
{
    if (value == 0)
        Pause();
    else if (std::isfinite(value) && value >= minimumRate() && value <= maximumRate())
        emit m_service->rateRequested(value);
}

double MprisPlayerAdaptor::volume() const
{
    auto *output = m_service->audioOutput();
    return output && !output->isMuted() ? output->volume() : 0;
}

void MprisPlayerAdaptor::setVolume(double value)
{
    if (std::isfinite(value))
        emit m_service->volumeRequested(std::clamp(value, 0.0, 1.0));
}

void MprisPlayerAdaptor::OpenUri(const QString &uri, const QDBusMessage &message)
{
    if (!m_service->acceptsUri(uri)) {
        message.setDelayedReply(true);
        m_service->bus().send(message.createErrorReply("org.freedesktop.DBus.Error.InvalidArgs", "MAPL accepts existing local audio and video files."));
        return;
    }
    emit m_service->openUriRequested(uri);
}
