#include "BackgroundProcess.h"

BackgroundProcess::BackgroundProcess(QObject *parent) : QObject(parent)
{
    m_timeout.setSingleShot(true);
    m_process.setStandardErrorFile(QProcess::nullDevice());
    connect(&m_process, &QProcess::started, this, [this] {
        if (m_cancelled)
            m_process.kill();
    });
    connect(&m_timeout, &QTimer::timeout, this, &BackgroundProcess::cancel);
    connect(&m_process, &QProcess::finished, this, [this](int code, QProcess::ExitStatus status) {
        finish(code == 0 && status == QProcess::NormalExit && !m_cancelled);
    });
    connect(&m_process, &QProcess::errorOccurred, this, [this](QProcess::ProcessError error) {
        if (error == QProcess::FailedToStart)
            finish(false);
    });
}

BackgroundProcess::~BackgroundProcess()
{
    m_process.disconnect(this);
    if (m_process.state() != QProcess::NotRunning) {
        m_process.kill();
        m_process.waitForFinished(); // Shutdown only; normal jobs never wait on the UI thread.
    }
}

void BackgroundProcess::start(const QString &program, const QStringList &arguments, int timeoutMs)
{
    m_timeout.start(timeoutMs);
    m_process.start(program, arguments);
}

void BackgroundProcess::cancel()
{
    m_cancelled = true;
    m_timeout.stop();
    if (m_process.state() != QProcess::NotRunning)
        m_process.kill();
}

void BackgroundProcess::finish(bool success)
{
    if (m_finished)
        return;
    m_finished = true;
    m_timeout.stop();
    emit completed(success, m_process.readAllStandardOutput());
    deleteLater();
}
