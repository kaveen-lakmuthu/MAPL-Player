#ifndef BACKGROUNDPROCESS_H
#define BACKGROUNDPROCESS_H

#include <QObject>
#include <QProcess>
#include <QTimer>

// An event-driven subprocess. Cancellation reaps the child before completion.
class BackgroundProcess : public QObject
{
    Q_OBJECT
public:
    explicit BackgroundProcess(QObject *parent = nullptr);
    ~BackgroundProcess() override;
    void start(const QString &program, const QStringList &arguments, int timeoutMs);
    void cancel();
signals:
    void completed(bool success, const QByteArray &output);
private:
    void finish(bool success);
    QProcess m_process;
    QTimer m_timeout;
    bool m_cancelled = false;
    bool m_finished = false;
};
#endif
