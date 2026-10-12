#ifndef NETWORK_H
#define NETWORK_H

class network
{
public:
    network();
};

#endif // NETWORK_H#pragma once

#include <QObject>
#include <QSet>
#include <QStringList>
#include <QVariantList>
#include <QVariantMap>
#include <QtQml/qqmlregistration.h>

#include <functional>

// Wi-Fi and wired networking for the Network screen, through NetworkManager's
// nmcli: the networks around you, connecting (with a password from the
// on-screen keyboard), disconnecting, forgetting a network and testing the
// connection. Every nmcli call runs in the background, so the dashboard never
// freezes while NetworkManager thinks.
class Network : public QObject
{
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON

    // Is nmcli installed? Without it the Network screen just says so
    Q_PROPERTY(bool available READ available CONSTANT)

    // What went wrong last time we asked NetworkManager for the networks
    // ("" when all is well, e.g. when NetworkManager isn't running)
    Q_PROPERTY(QString problem READ problem NOTIFY changed)

    // This PC's name, for the start of the connection chain
    Q_PROPERTY(QString hostName READ hostName CONSTANT)

    // Is there a Wi-Fi card, and is its radio on?
    Q_PROPERTY(bool hasWifi READ hasWifi NOTIFY changed)
    Q_PROPERTY(bool wifiEnabled READ wifiEnabled NOTIFY changed)

    // The Wi-Fi networks around you, one per name, the strongest first:
    // [{ssid, signal (0-100), security, secured, enterprise, active, known, rate}]
    Q_PROPERTY(QVariantList networks READ networks NOTIFY changed)

    // The network cable's socket, if there is one:
    // {device, state ("connected", "connecting", "disconnected" or "unplugged"), connection}
    Q_PROPERTY(QVariantMap wired READ wired NOTIFY changed)

    // Looking for networks right now
    Q_PROPERTY(bool scanning READ scanning NOTIFY scanningChanged)

    // The network we're connecting to right now ("" when we aren't)
    Q_PROPERTY(QString connecting READ connecting NOTIFY connectingChanged)

public:
    explicit Network(QObject *parent = nullptr);

    bool available() const { return !m_nmcli.isEmpty(); }
    QString problem() const { return m_problem; }
    QString hostName() const;
    bool hasWifi() const { return !m_wifiDevice.isEmpty(); }
    bool wifiEnabled() const { return m_wifiEnabled; }
    QVariantList networks() const { return m_networks; }
    QVariantMap wired() const { return m_wired; }
    bool scanning() const { return m_scanning; }
    QString connecting() const { return m_connecting; }

    // Read the networks again from what NetworkManager already knows (quick)
    Q_INVOKABLE void refresh();

    // Look for networks again (takes a few seconds)
    Q_INVOKABLE void scan();

    // Join a Wi-Fi network. No password for open networks and ones you've
    // joined before; hidden for one that doesn't show up in the list.
    // Ends with connectFinished()
    Q_INVOKABLE void connectTo(const QString &ssid, const QString &password = QString(),
                               bool hidden = false);

    // Use the network cable again after disconnecting it
    Q_INVOKABLE void connectWired();

    // "wifi" or "wired"
    Q_INVOKABLE void disconnectFrom(const QString &kind);

    // Forget a Wi-Fi network's password, so it doesn't join it by itself any more
    Q_INVOKABLE void forget(const QString &ssid);

    Q_INVOKABLE void setWifiEnabled(bool enabled);

    // Check the connection ("wifi" or "wired"). Ends with tested():
    // {connected, ip, gateway, dns, mac, speed, internet}, where internet is
    // NetworkManager's own check: "full", "portal", "limited", "none" or "unknown"
    Q_INVOKABLE void test(const QString &kind);

signals:
    void changed();
    void scanningChanged();
    void connectingChanged();
    void connectFinished(bool ok, const QString &ssid, const QString &error);
    void tested(const QVariantMap &result);
    void failed(const QString &error);          // disconnect, forget or Wi-Fi on/off didn't work

private:
    using Done = std::function<void(bool ok, const QString &output, const QString &error)>;
    void run(const QStringList &arguments, const Done &done);
    void read(bool rescan);

    QString m_nmcli;
    QString m_problem;
    QString m_wifiDevice;
    bool m_wifiEnabled = false;
    QVariantList m_networks;
    QVariantMap m_wired;
    QSet<QString> m_known;                      // Wi-Fi networks with a saved password
    bool m_scanning = false;
    bool m_reading = false;
    bool m_readAgain = false;                   // asked again while reading: read once more after
    bool m_rescanAgain = false;
    QString m_connecting;
};
