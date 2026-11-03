#pragma once

#include <QObject>
#include <QTimer>
#include <QVariantList>
#include <QtQml/qqmlregistration.h>

#include <functional>

class QProcess;

// Display & Sound: the PC's volume and where its sound plays, through pactl
// (which PipeWire and PulseAudio both answer).
class AudioSettings : public QObject
{
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON

    // false when there's nothing to ask (no pactl, or no sound server running)
    Q_PROPERTY(bool available READ available NOTIFY changed)

    // Every sound output: [{name, description, unplugged, current}]
    Q_PROPERTY(QVariantList outputs READ outputs NOTIFY changed)

    // The output sound plays through now, its volume (0-100) and whether it's muted
    Q_PROPERTY(QString output READ output NOTIFY changed)
    Q_PROPERTY(int volume READ volume NOTIFY changed)
    Q_PROPERTY(bool muted READ muted NOTIFY changed)

    // While true (Display & Sound is open), changes made elsewhere, like a
    // keyboard's volume keys, show up straight away
    Q_PROPERTY(bool watching READ watching WRITE setWatching NOTIFY watchingChanged)

public:
    explicit AudioSettings(QObject *parent = nullptr);
    ~AudioSettings() override;

    bool available() const { return m_available; }
    QVariantList outputs() const { return m_outputs; }
    QString output() const { return m_output; }
    int volume() const { return m_volume; }
    bool muted() const { return m_muted; }
    bool watching() const { return m_watching; }
    void setWatching(bool watching);

    Q_INVOKABLE void refresh();
    Q_INVOKABLE void setVolume(int percent);
    Q_INVOKABLE void setMuted(bool muted);
    Q_INVOKABLE void setOutput(const QString &name);

signals:
    void changed();
    void watchingChanged();

private:
    void run(const QStringList &arguments, std::function<void(const QByteArray &)> done = {});
    void readOutputs(const QByteArray &json, const QString &current);
    void listen();

    QString m_pactl;
    bool m_available = false;
    QVariantList m_outputs;
    QString m_output;
    int m_volume = 0;
    bool m_muted = false;
    bool m_watching = false;

    QProcess *m_events = nullptr;       // "pactl subscribe": tells us when anything changes
    QTimer m_refreshSoon;               // changes come in bursts; look once they settle
};