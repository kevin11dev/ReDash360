#include "audiosettings.h"

#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QProcess>
#include <QStandardPaths>

AudioSettings::AudioSettings(QObject *parent)
    : QObject(parent)
    , m_pactl(QStandardPaths::findExecutable("pactl"))
{
    m_refreshSoon.setSingleShot(true);
    m_refreshSoon.setInterval(150);
    connect(&m_refreshSoon, &QTimer::timeout, this, &AudioSettings::refresh);
    refresh();
}

AudioSettings::~AudioSettings()
{
    if (m_events) {
        m_events->kill();
        m_events->waitForFinished(500);
    }
}

// Run pactl, and hand what it printed to done
void AudioSettings::run(const QStringList &arguments, std::function<void(const QByteArray &)> done)
{
    if (m_pactl.isEmpty())
        return;
    auto *process = new QProcess(this);
    QProcessEnvironment environment = QProcessEnvironment::systemEnvironment();
    environment.insert("LC_ALL", "C");
    process->setProcessEnvironment(environment);
    connect(process, &QProcess::finished, this, [process, done](int exitCode) {
        if (done && exitCode == 0)
            done(process->readAllStandardOutput());
        process->deleteLater();
    });
    process->start(m_pactl, arguments);
}

// Which output is the default, then every output and its volume
void AudioSettings::refresh()
{
    run({ "-f", "json", "info" }, [this](const QByteArray &info) {
        const QString current = QJsonDocument::fromJson(info).object().value("default_sink_name").toString();
        run({ "-f", "json", "list", "sinks" }, [this, current](const QByteArray &sinks) {
            readOutputs(sinks, current);
        });
    });
}

void AudioSettings::readOutputs(const QByteArray &json, const QString &current)
{
    const QJsonArray sinks = QJsonDocument::fromJson(json).array();
    QVariantList outputs;
    for (const QJsonValue &value : sinks) {
        const QJsonObject sink = value.toObject();
        const QString name = sink.value("name").toString();

        // Unplugged: it has sockets, and nothing is in any of them
        const QJsonArray ports = sink.value("ports").toArray();
        bool unplugged = !ports.isEmpty();
        for (const QJsonValue &port : ports) {
            if (port.toObject().value("availability").toString() != "not available")
                unplugged = false;
        }

        outputs << QVariantMap {
            { "name", name },
            { "description", sink.value("description").toString() },
            { "unplugged", unplugged },
            { "current", name == current },
            };

        if (name == current) {
            // Each channel has its own volume ("55%"); show the average
            const QJsonObject channels = sink.value("volume").toObject();
            int total = 0;
            for (const QJsonValue &channel : channels)
                total += channel.toObject().value("value_percent").toString().chopped(1).toInt();
            m_volume = channels.isEmpty() ? 0 : qRound(double(total) / channels.size());
            m_muted = sink.value("mute").toBool();
        }
    }
    m_outputs = outputs;
    m_output = current;
    m_available = true;
    emit changed();
}

void AudioSettings::setVolume(int percent)
{
    percent = qBound(0, percent, 100);
    if (m_muted && percent > m_volume)
        setMuted(false);                        // turning it up turns the sound back on
    m_volume = percent;
    emit changed();
    run({ "set-sink-volume", "@DEFAULT_SINK@", QString::number(percent) + "%" });
}

void AudioSettings::setMuted(bool muted)
{
    m_muted = muted;
    emit changed();
    run({ "set-sink-mute", "@DEFAULT_SINK@", muted ? "1" : "0" });
}

void AudioSettings::setOutput(const QString &name)
{
    run({ "set-default-sink", name }, [this](const QByteArray &) { refresh(); });
}

void AudioSettings::setWatching(bool watching)
{
    if (watching == m_watching)
        return;
    m_watching = watching;
    emit watchingChanged();

    if (watching) {
        refresh();
        listen();
    } else if (m_events) {
        m_events->kill();
    }
}

// "pactl subscribe" prints a line for every change ("Event 'change' on sink #56")
void AudioSettings::listen()
{
    if (m_pactl.isEmpty() || !m_watching)
        return;
    if (!m_events) {
        m_events = new QProcess(this);
        connect(m_events, &QProcess::readyReadStandardOutput, this, [this] {
            const QByteArray lines = m_events->readAllStandardOutput();
            if (lines.contains("sink") || lines.contains("server"))
                m_refreshSoon.start();
        });
        connect(m_events, &QProcess::finished, this, [this] {
            if (m_watching)                     // the sound server restarted: listen again
                QTimer::singleShot(2000, this, &AudioSettings::listen);
        });
    }
    if (m_events->state() == QProcess::NotRunning)
        m_events->start(m_pactl, { "subscribe" });
}