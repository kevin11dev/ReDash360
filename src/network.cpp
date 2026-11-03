#include "network.h"

#include <QHash>
#include <QProcess>
#include <QProcessEnvironment>
#include <QStandardPaths>
#include <QSysInfo>

#include <algorithm>

namespace {

// nmcli -t prints one line per thing with its fields split by ':', and writes
// a ':' or '\' that's part of a value as '\:' or '\\'
QStringList fields(const QString &line)
{
    QStringList result;
    QString current;
    for (int i = 0; i < line.size(); ++i) {
        const QChar c = line.at(i);
        if (c == QLatin1Char('\\') && i + 1 < line.size()) {
            current += line.at(++i);
        } else if (c == QLatin1Char(':')) {
            result << current;
            current.clear();
        } else {
            current += c;
        }
    }
    result << current;
    return result;
}

QStringList lines(const QString &output)
{
    return output.split(QLatin1Char('\n'), Qt::SkipEmptyParts);
}

// "connected (externally)" -> "connected", "unavailable" (no cable) -> "unplugged"
QString simpleState(const QString &state)
{
    if (state.startsWith(QLatin1String("connected")))
        return QStringLiteral("connected");
    if (state.startsWith(QLatin1String("connecting")))
        return QStringLiteral("connecting");
    if (state == QLatin1String("unavailable"))
        return QStringLiteral("unplugged");
    return QStringLiteral("disconnected");
}

// nmcli's error, in words for the Couldn't Connect card
QString friendlyError(const QString &ssid, const QString &error)
{
    const QString e = error.toLower();
    if (e.contains(QLatin1String("secrets were required")) || e.contains(QLatin1String("psk: property is invalid"))
        || e.contains(QLatin1String("supplicant")))
        return QStringLiteral("The password for %1 isn't right.").arg(ssid);
    if (e.contains(QLatin1String("no network with ssid")))
        return QStringLiteral("%1 couldn't be found. It might be out of range.").arg(ssid);
    if (e.contains(QLatin1String("not authorized")))
        return QStringLiteral("ReDash360 isn't allowed to change your network settings.");
    if (e.contains(QLatin1String("timeout")) || e.contains(QLatin1String("timed out")))
        return QStringLiteral("%1 didn't answer in time.").arg(ssid);

    QString words = error.trimmed();
    if (words.startsWith(QLatin1String("Error: ")))
        words = words.mid(7);
    return words.isEmpty() ? QStringLiteral("Something went wrong.") : words;
}

} // namespace

Network::Network(QObject *parent)
    : QObject(parent)
    , m_nmcli(QStandardPaths::findExecutable(QStringLiteral("nmcli")))
{
    if (m_nmcli.isEmpty())
        m_problem = QStringLiteral("Network settings need NetworkManager (nmcli).");
}

QString Network::hostName() const
{
    return QSysInfo::machineHostName();
}

void Network::run(const QStringList &arguments, const Done &done)
{
    if (m_nmcli.isEmpty()) {
        done(false, QString(), m_problem);
        return;
    }

    auto *process = new QProcess(this);
    QProcessEnvironment environment = QProcessEnvironment::systemEnvironment();
    environment.insert(QStringLiteral("LC_ALL"), QStringLiteral("C"));    // English words we can read
    process->setProcessEnvironment(environment);

    connect(process, &QProcess::finished, this, [process, done](int exitCode, QProcess::ExitStatus status) {
        const QString output = QString::fromUtf8(process->readAllStandardOutput());
        const QString error = QString::fromUtf8(process->readAllStandardError()).trimmed();
        done(status == QProcess::NormalExit && exitCode == 0, output, error);
        process->deleteLater();
    });
    connect(process, &QProcess::errorOccurred, this, [process, done](QProcess::ProcessError error) {
        if (error == QProcess::FailedToStart) {
            done(false, QString(), process->errorString());
            process->deleteLater();
        }
    });
    process->start(m_nmcli, arguments);
}

void Network::refresh()
{
    read(false);
}

void Network::scan()
{
    if (m_scanning)
        return;
    m_scanning = true;
    emit scanningChanged();
    read(true);
}

// Four questions for NetworkManager, one after the other: the devices, the
// Wi-Fi radio, the saved networks, then the networks around you
void Network::read(bool rescan)
{
    if (m_reading) {
        m_readAgain = true;
        m_rescanAgain = m_rescanAgain || rescan;
        return;
    }
    m_reading = true;

    const auto finish = [this, rescan] {
        m_reading = false;
        if (rescan && m_scanning) {
            m_scanning = false;
            emit scanningChanged();
        }
        emit changed();
        if (m_readAgain) {
            const bool again = m_rescanAgain;
            m_readAgain = m_rescanAgain = false;
            read(again);
        }
    };

    run({ "-t", "-f", "DEVICE,TYPE,STATE,CONNECTION", "device" },
        [this, rescan, finish](bool ok, const QString &output, const QString &error) {
            if (!ok) {
                m_problem = error.isEmpty() ? QStringLiteral("NetworkManager isn't answering.") : error;
                m_wifiDevice.clear();
                m_networks.clear();
                m_wired.clear();
                finish();
                return;
            }
            m_problem.clear();
            m_wifiDevice.clear();
            m_wired.clear();
            for (const QString &line : lines(output)) {
                const QStringList f = fields(line);
                if (f.size() < 4)
                    continue;
                if (f[1] == QLatin1String("wifi") && m_wifiDevice.isEmpty())
                    m_wifiDevice = f[0];
                else if (f[1] == QLatin1String("ethernet") && m_wired.isEmpty())
                    m_wired = { { "device", f[0] }, { "state", simpleState(f[2]) }, { "connection", f[3] } };
            }

            if (m_wifiDevice.isEmpty()) {
                m_networks.clear();
                finish();
                return;
            }

            run({ "-t", "-f", "WIFI", "radio" }, [this, rescan, finish](bool, const QString &output, const QString &) {
                m_wifiEnabled = output.trimmed() == QLatin1String("enabled");

                run({ "-t", "-f", "NAME,TYPE", "connection", "show" },
                    [this, rescan, finish](bool, const QString &output, const QString &) {
                        m_known.clear();
                        for (const QString &line : lines(output)) {
                            const QStringList f = fields(line);
                            if (f.size() >= 2 && f[1] == QLatin1String("802-11-wireless"))
                                m_known.insert(f[0]);
                        }

                        if (!m_wifiEnabled) {
                            m_networks.clear();
                            finish();
                            return;
                        }

                        run({ "-t", "-f", "IN-USE,SSID,SIGNAL,SECURITY,RATE", "device", "wifi", "list",
                             "--rescan", rescan ? "yes" : "no" },
                            [this, finish](bool ok, const QString &output, const QString &) {
                                if (!ok) {                  // e.g. "scanning not allowed" right after a scan
                                    finish();
                                    return;
                                }
                                // One entry per name (a big router has several), keeping the strongest
                                QHash<QString, QVariantMap> byName;
                                for (const QString &line : lines(output)) {
                                    const QStringList f = fields(line);
                                    if (f.size() < 5 || f[1].isEmpty())
                                        continue;           // hidden networks have no name
                                    const QString ssid = f[1];
                                    const int signal = f[2].toInt();
                                    const QString security = f[3] == QLatin1String("--") ? QString() : f[3];
                                    const bool inUse = f[0] == QLatin1String("*");

                                    QVariantMap &network = byName[ssid];
                                    if (network.isEmpty() || signal > network.value("signal").toInt()) {
                                        const bool wasActive = network.value("active").toBool();
                                        network = {
                                                    { "ssid", ssid },
                                                    { "signal", signal },
                                                    { "security", security },
                                                    { "secured", !security.isEmpty() },
                                                    { "enterprise", security.contains(QLatin1String("802.1X")) },
                                                    { "active", wasActive || inUse },
                                                    { "known", m_known.contains(ssid) },
                                                    { "rate", f[4] },
                                                    };
                                    } else if (inUse) {
                                        network["active"] = true;
                                    }
                                }

                                // The one you're on, then ones you've joined before, then the strongest
                                QVariantList list(byName.cbegin(), byName.cend());
                                std::sort(list.begin(), list.end(), [](const QVariant &a, const QVariant &b) {
                                    const QVariantMap x = a.toMap(), y = b.toMap();
                                    if (x["active"] != y["active"])
                                        return x["active"].toBool();
                                    if (x["known"] != y["known"])
                                        return x["known"].toBool();
                                    const int barsX = x["signal"].toInt() / 25, barsY = y["signal"].toInt() / 25;
                                    if (barsX != barsY)
                                        return barsX > barsY;
                                    return x["ssid"].toString().compare(y["ssid"].toString(), Qt::CaseInsensitive) < 0;
                                });
                                m_networks = list;
                                finish();
                            });
                    });
            });
        });
}

void Network::connectTo(const QString &ssid, const QString &password, bool hidden)
{
    m_connecting = ssid;
    emit connectingChanged();

    QStringList arguments = { "-w", "40", "device", "wifi", "connect", ssid };
    if (!password.isEmpty())
        arguments << "password" << password;
    if (hidden)
        arguments << "hidden" << "yes";
    if (!m_wifiDevice.isEmpty())
        arguments << "ifname" << m_wifiDevice;

    // A network we know keeps its saved password if joining it fails; a new
    // one (or a new password) doesn't
    const bool known = m_known.contains(ssid);
    const bool keep = known && password.isEmpty();

    const auto join = [this, ssid, arguments, keep] {
        run(arguments, [this, ssid, keep](bool ok, const QString &, const QString &error) {
            // A failed try still leaves a saved network behind (with the wrong
            // password), which would get in the way of the next try
            if (!ok && !keep)
                run({ "connection", "delete", "id", ssid }, [](bool, const QString &, const QString &) {});

            m_connecting.clear();
            emit connectingChanged();
            emit connectFinished(ok, ssid, ok ? QString() : friendlyError(ssid, error));
            refresh();
        });
    };

    // A new password for a network we know: forget the old one first
    if (known && !password.isEmpty())
        run({ "connection", "delete", "id", ssid }, [join](bool, const QString &, const QString &) { join(); });
    else
        join();
}

void Network::connectWired()
{
    const QString device = m_wired.value("device").toString();
    if (device.isEmpty())
        return;
    run({ "-w", "30", "device", "connect", device }, [this](bool ok, const QString &, const QString &error) {
        if (!ok)
            emit failed(friendlyError(QStringLiteral("The network cable"), error));
        refresh();
    });
}

void Network::disconnectFrom(const QString &kind)
{
    const QString device = kind == QLatin1String("wired") ? m_wired.value("device").toString() : m_wifiDevice;
    if (device.isEmpty())
        return;
    run({ "device", "disconnect", device }, [this](bool ok, const QString &, const QString &error) {
        if (!ok)
            emit failed(friendlyError(QString(), error));
        refresh();
    });
}

void Network::forget(const QString &ssid)
{
    run({ "connection", "delete", "id", ssid }, [this](bool ok, const QString &, const QString &error) {
        if (!ok)
            emit failed(friendlyError(QString(), error));
        refresh();
    });
}

void Network::setWifiEnabled(bool enabled)
{
    run({ "radio", "wifi", enabled ? "on" : "off" }, [this, enabled](bool ok, const QString &, const QString &error) {
        if (!ok)
            emit failed(friendlyError(QString(), error));
        if (enabled && ok)
            scan();                             // the networks show up a moment after the radio's on
        else
            refresh();
    });
}

void Network::test(const QString &kind)
{
    const QString device = kind == QLatin1String("wired") ? m_wired.value("device").toString() : m_wifiDevice;

    run({ "-t", "-f", "GENERAL.STATE,GENERAL.HWADDR,IP4.ADDRESS,IP4.GATEWAY,IP4.DNS,CAPABILITIES.SPEED",
         "device", "show", device },
        [this](bool, const QString &output, const QString &) {
            QVariantMap result;
            QStringList dns;
            for (const QString &line : lines(output)) {
                const QStringList f = fields(line);
                if (f.size() < 2)
                    continue;
                const QString name = f[0].section(QLatin1Char('['), 0, 0);     // "IP4.DNS[2]" -> "IP4.DNS"
                const QString value = f.mid(1).join(QLatin1Char(':'));
                if (name == QLatin1String("GENERAL.STATE"))
                    result["connected"] = value.contains(QLatin1String("(connected"));
                else if (name == QLatin1String("GENERAL.HWADDR"))
                    result["mac"] = value;
                else if (name == QLatin1String("IP4.ADDRESS") && !result.contains("ip"))
                    result["ip"] = value.section(QLatin1Char('/'), 0, 0);      // without the "/24"
                else if (name == QLatin1String("IP4.GATEWAY"))
                    result["gateway"] = value;
                else if (name == QLatin1String("IP4.DNS"))
                    dns << value;
                else if (name == QLatin1String("CAPABILITIES.SPEED") && value != QLatin1String("unknown"))
                    result["speed"] = value;
            }
            result["dns"] = dns.join(QStringLiteral(", "));
            if (result.value("ip").toString().isEmpty())
                result["connected"] = false;         // joined, but no address from the router

            run({ "networking", "connectivity", "check" }, [this, result](bool, const QString &output, const QString &) mutable {
                const QString state = output.trimmed();
                result["internet"] = state.isEmpty() ? QStringLiteral("unknown") : state;
                emit tested(result);
            });
        });
}