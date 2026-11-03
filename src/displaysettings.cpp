#include "displaysettings.h"

#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QProcess>
#include <QRegularExpression>
#include <QStandardPaths>

#include <algorithm>

DisplaySettings::DisplaySettings(QObject *parent)
    : QObject(parent)
    , m_doctor(QStandardPaths::findExecutable("kscreen-doctor"))
{
}

// Run kscreen-doctor, and hand what it printed to done (nothing if it failed)
void DisplaySettings::run(const QStringList &arguments, std::function<void(const QByteArray &)> done)
{
    if (m_doctor.isEmpty())
        return;
    auto *process = new QProcess(this);
    connect(process, &QProcess::finished, this, [process, done](int exitCode) {
        if (done)
            done(exitCode == 0 ? process->readAllStandardOutput() : QByteArray());
        process->deleteLater();
    });
    process->start(m_doctor, arguments);
}

// "kscreen-doctor -j" lists every screen and its modes; "-o" adds whether
// it can do HDR and adaptive sync
void DisplaySettings::refresh(const QString &screenName)
{
    m_screenName = screenName;
    run({ "-j" }, [this](const QByteArray &json) {
        if (!readOutputs(json)) {
            if (m_available) {
                m_available = false;
                emit changed();
            }
            return;
        }
        run({ "-o" }, [this](const QByteArray &text) {
            readExtras(text);
            m_available = true;
            emit changed();
        });
    });
}

bool DisplaySettings::readOutputs(const QByteArray &json)
{
    // The dashboard's screen; failing that the main one, or any that's on
    QJsonObject chosen;
    QJsonObject main;
    QJsonObject first;
    const QJsonArray outputs = QJsonDocument::fromJson(json).object().value("outputs").toArray();
    for (const QJsonValue &value : outputs) {
        const QJsonObject output = value.toObject();
        if (!output.value("enabled").toBool() || !output.value("connected").toBool())
            continue;
        if (output.value("name").toString() == m_screenName) {
            chosen = output;
            break;
        }
        if (first.isEmpty())
            first = output;
        if (main.isEmpty() && output.value("priority").toInt() == 1)
            main = output;
    }
    if (chosen.isEmpty())
        chosen = main.isEmpty() ? first : main;
    if (chosen.isEmpty())
        return false;

    const QString currentId = chosen.value("currentModeId").toVariant().toString();
    QVariantMap now;
    QVariantList modes;
    for (const QJsonValue &value : chosen.value("modes").toArray()) {
        const QJsonObject mode = value.toObject();
        const QJsonObject size = mode.value("size").toObject();
        const QVariantMap entry {
            { "id", mode.value("id").toVariant().toString() },
            { "width", size.value("width").toInt() },
            { "height", size.value("height").toInt() },
            { "refresh", mode.value("refreshRate").toDouble() },
            };
        modes << entry;
        if (entry.value("id") == currentId)
            now = entry;
    }
    std::sort(modes.begin(), modes.end(), [](const QVariant &a, const QVariant &b) {
        const QVariantMap x = a.toMap();
        const QVariantMap y = b.toMap();
        const int areaX = x["width"].toInt() * x["height"].toInt();
        const int areaY = y["width"].toInt() * y["height"].toInt();
        if (areaX != areaY)
            return areaX > areaY;
        if (x["width"] != y["width"])
            return x["width"].toInt() > y["width"].toInt();
        return x["refresh"].toDouble() > y["refresh"].toDouble();
    });

    m_output = chosen.value("name").toString();
    m_modes = modes;
    m_current = {
        { "modeId", currentId },
        { "width", now.value("width", 0) },
        { "height", now.value("height", 0) },
        { "refresh", now.value("refresh", 0.0) },
        { "scale", chosen.value("scale").toDouble(1.0) },
        { "hdr", QString() },
        { "vrr", QString() },
        };
    return true;
}

// "Output: 1 DP-1 enabled connected ... Vrr: Automatic ... HDR: disabled ..."
void DisplaySettings::readExtras(const QByteArray &text)
{
    static const QRegularExpression colours("\x1b\\[[0-9;]*m");
    static const QRegularExpression hdr("HDR:\\s*(\\w+)", QRegularExpression::CaseInsensitiveOption);
    static const QRegularExpression vrr("Vrr:\\s*(\\w+)", QRegularExpression::CaseInsensitiveOption);

    const QString plain = QString::fromUtf8(text).remove(colours);
    for (const QString &block : plain.split("Output:", Qt::SkipEmptyParts)) {
        const QStringList words = block.simplified().split(' ');
        if (words.size() < 2 || words[1] != m_output)
            continue;
        const QString hdrState = hdr.match(block).captured(1).toLower();
        const QString vrrPolicy = vrr.match(block).captured(1).toLower();
        m_current["hdr"] = hdrState == "enabled" ? "on" : hdrState == "disabled" ? "off" : "";
        m_current["vrr"] = (vrrPolicy == "never" || vrrPolicy == "automatic" || vrrPolicy == "always")
                               ? vrrPolicy : QString();
    }
}

// Change one setting of the dashboard's screen ("mode.5", "hdr.enable"),
// then look again
void DisplaySettings::apply(const QString &setting)
{
    if (m_output.isEmpty())
        return;
    run({ "output." + m_output + "." + setting }, [this](const QByteArray &) { refresh(m_screenName); });
}

void DisplaySettings::setMode(const QString &id)
{
    apply("mode." + id);
}

void DisplaySettings::setScale(double scale)
{
    apply("scale." + QString::number(scale));
}

void DisplaySettings::setHdr(bool on)
{
    apply(on ? "hdr.enable" : "hdr.disable");
}

void DisplaySettings::setVrr(const QString &policy)
{
    apply("vrrpolicy." + policy);
}