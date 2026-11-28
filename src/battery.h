#pragma once

#include <QObject>
#include <QTimer>
#include <QtQml/qqmlregistration.h>

// This PC's own battery (a laptop's), for the top corner of the dashboard and
// the Guide: how full it is and whether it's on the charger. Linux lists it in
// /sys/class/power_supply, looked at every few seconds. Controllers and mice
// list their batteries there too, and are left out.
class Battery : public QObject
{
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON

    // Has a battery at all (false on a desktop PC, and then nothing shows)
    Q_PROPERTY(bool present READ present NOTIFY changed)

    // How full it is, 0 to 100
    Q_PROPERTY(int percent READ percent NOTIFY changed)

    // On the charger: charging, or plugged in and full
    Q_PROPERTY(bool pluggedIn READ pluggedIn NOTIFY changed)

public:
    explicit Battery(QObject *parent = nullptr);

    bool present() const { return m_now.present; }
    int percent() const { return m_now.percent; }
    bool pluggedIn() const { return m_now.pluggedIn; }

    struct Reading {
        bool present = false;
        int percent = 0;
        bool pluggedIn = false;
    };

    // What the power supplies in this folder say (normally /sys/class/power_supply)
    static Reading read(const QString &folder);

signals:
    void changed();

private:
    void update();

    Reading m_now;
    QTimer m_timer;
};