#include "battery.h"

#include <QDir>
#include <QFile>

#include <cmath>

namespace {

constexpr int IntervalMs = 5000;        // how often to look: plugging in shows within 5 seconds

QString readText(const QString &path)
{
    QFile file(path);
    if (!file.open(QIODevice::ReadOnly | QIODevice::Text))
        return {};
    return QString::fromUtf8(file.readAll()).trimmed();
}

// A number from a file, or -1 if it isn't there
double readNumber(const QString &path)
{
    bool ok = false;
    const double value = readText(path).toDouble(&ok);
    return ok ? value : -1;
}

}

Battery::Battery(QObject *parent)
    : QObject(parent)
{
    m_now = read("/sys/class/power_supply");
    m_timer.setInterval(IntervalMs);
    connect(&m_timer, &QTimer::timeout, this, &Battery::update);
    m_timer.start();
}

void Battery::update()
{
    const Reading now = read("/sys/class/power_supply");
    if (now.present == m_now.present && now.percent == m_now.percent && now.pluggedIn == m_now.pluggedIn)
        return;
    m_now = now;
    emit changed();
}

// Each power supply is a folder with a "type": "Battery" for a battery,
// "Mains" for the charger ("USB" for a USB-C one), and a "scope" of "Device"
// for one in something you've plugged in (a controller, a mouse), which
// isn't this PC's own. A laptop with two batteries adds them up.
Battery::Reading Battery::read(const QString &folder)
{
    Reading reading;
    int batteries = 0;
    double now = 0, full = 0;                  // energy (or charge), all batteries together
    int capacities = 0, capacitySum = 0;       // their percentages, when that's all they give
    bool charging = false, onCharger = false;

    const QStringList supplies = QDir(folder).entryList(QDir::Dirs | QDir::NoDotAndDotDot);
    for (const QString &name : supplies) {
        const QString dir = folder + "/" + name + "/";
        const QString type = readText(dir + "type");
        if (readText(dir + "scope").compare("Device", Qt::CaseInsensitive) == 0)
            continue;                           // a controller's or a mouse's

        if (type == "Mains" || type == "USB") {
            if (readText(dir + "online") == "1")
                onCharger = true;
            continue;
        }
        if (type != "Battery" || readText(dir + "present") == "0")
            continue;                           // something else, or an empty battery bay

        ++batteries;
        const QString status = readText(dir + "status");
        if (status == "Charging" || status == "Full" || status == "Not charging")
            charging = true;                    // "Not charging": plugged in, held below full

        // Energy (µWh) or charge (µAh), whichever it gives, for an exact
        // total; otherwise its own percentage
        double batteryNow = readNumber(dir + "energy_now"), batteryFull = readNumber(dir + "energy_full");
        if (batteryNow < 0 || batteryFull <= 0) {
            batteryNow = readNumber(dir + "charge_now");
            batteryFull = readNumber(dir + "charge_full");
        }
        if (batteryNow >= 0 && batteryFull > 0) {
            now += batteryNow;
            full += batteryFull;
        }
        const double capacity = readNumber(dir + "capacity");
        if (capacity >= 0) {
            capacitySum += int(capacity);
            ++capacities;
        }
    }

    if (batteries == 0)
        return reading;
    // One battery: its own percentage, the same as the rest of the desktop
    // shows. Two: their energy together.
    if (batteries == 1 && capacities == 1)
        reading.percent = capacitySum;
    else if (full > 0)
        reading.percent = int(std::lround(100 * now / full));
    else if (capacities > 0)
        reading.percent = capacitySum / capacities;
    reading.present = true;
    reading.percent = qBound(0, reading.percent, 100);
    reading.pluggedIn = onCharger || charging;
    return reading;
}