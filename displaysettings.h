#pragma once

#include <QObject>
#include <QVariantList>
#include <QVariantMap>
#include <QtQml/qqmlregistration.h>

#include <functional>

// Display & Sound: the screen's resolution, refresh rate, scale, HDR and
// adaptive sync, through KDE Plasma's kscreen-doctor.
class DisplaySettings : public QObject
{
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON

    // false without KDE Plasma's kscreen-doctor, or until it has answered
    Q_PROPERTY(bool available READ available NOTIFY changed)

    // The screen the dashboard is on, by its connector ("DP-1", "HDMI-A-1")
    Q_PROPERTY(QString output READ output NOTIFY changed)

    // Its settings now: {modeId, width, height, refresh, scale, hdr, vrr}
    //   refresh: Hz; scale: 1.25 for 125%
    //   hdr: "on", "off", or "" when the screen can't do HDR
    //   vrr (adaptive sync): "never", "automatic", "always", or "" when it can't
    Q_PROPERTY(QVariantMap current READ current NOTIFY changed)

    // Every mode the screen can use: [{id, width, height, refresh}],
    // biggest and fastest first
    Q_PROPERTY(QVariantList modes READ modes NOTIFY changed)

public:
    explicit DisplaySettings(QObject *parent = nullptr);

    bool available() const { return m_available; }
    QString output() const { return m_output; }
    QVariantMap current() const { return m_current; }
    QVariantList modes() const { return m_modes; }

    // Look again; screenName is the name of the screen the dashboard is on
    // (QML's Screen.name), which Plasma names the same way
    Q_INVOKABLE void refresh(const QString &screenName);

    Q_INVOKABLE void setMode(const QString &id);
    Q_INVOKABLE void setScale(double scale);
    Q_INVOKABLE void setHdr(bool on);
    Q_INVOKABLE void setVrr(const QString &policy);

signals:
    void changed();

private:
    void run(const QStringList &arguments, std::function<void(const QByteArray &)> done);
    void apply(const QString &setting);
    bool readOutputs(const QByteArray &json);
    void readExtras(const QByteArray &text);

    QString m_doctor;
    QString m_screenName;
    bool m_available = false;
    QString m_output;
    QVariantMap m_current;
    QVariantList m_modes;
};