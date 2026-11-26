#include "appwindows.h"

#include <QCoreApplication>
#include <QFile>
#include <QFileInfo>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QProcess>
#include <QStandardPaths>

#ifdef HAVE_QTDBUS
#include <QDBusArgument>
#include <QDBusInterface>
#include <QDBusMessage>
#include <QDBusReply>
#endif

namespace {

constexpr char ScriptName[] = "redash360-fill-screen";

#ifdef HAVE_QTDBUS
// KWin: its window search (the one KRunner uses) lists every window when
// asked for "", as "0_{id}" ("0": bring it to the front, with Run()), and
// getWindowInfo() tells what each one is
bool raiseOnPlasma(const QStringList &names)
{
    QDBusInterface runner("org.kde.KWin", "/WindowsRunner", "org.kde.krunner1");
    QDBusInterface kwin("org.kde.KWin", "/KWin", "org.kde.KWin");
    if (!runner.isValid() || !kwin.isValid())
        return false;
    runner.setTimeout(1000);
    kwin.setTimeout(1000);

    const QDBusMessage reply = runner.call("Match", QString());
    if (reply.type() != QDBusMessage::ReplyMessage || reply.arguments().isEmpty())
        return false;
    QStringList windows;
    const QDBusArgument matches = reply.arguments().constFirst().value<QDBusArgument>();
    matches.beginArray();                       // each one: id, text, icon, category, relevance, properties
    while (!matches.atEnd()) {
        QString id, text, icon;
        int category = 0;
        double relevance = 0;
        QVariantMap properties;
        matches.beginStructure();
        matches >> id >> text >> icon >> category >> relevance >> properties;
        matches.endStructure();
        if (id.startsWith("0_") && !windows.contains(id))
            windows << id;
    }
    matches.endArray();

    const qint64 dashboard = QCoreApplication::applicationPid();
    for (const QString &window : std::as_const(windows)) {
        const QDBusReply<QVariantMap> info = kwin.call("getWindowInfo", window.mid(2));
        if (!info.isValid() || info.value().value("pid").toLongLong() == dashboard)
            continue;
        for (const char *key : { "desktopFile", "resourceClass", "resourceName" }) {
            if (names.contains(info.value().value(key).toString().toLower())) {
                runner.call("Run", window, QString());
                return true;
            }
        }
    }
    return false;
}
#endif

QString hyprctl(const QStringList &arguments)
{
    QProcess process;
    process.start("hyprctl", arguments);
    if (!process.waitForFinished(1000))
        return {};
    return QString::fromUtf8(process.readAllStandardOutput()).trimmed();
}

// Hyprland: hyprctl clients -j lists the windows, with their class and address
bool raiseOnHyprland(const QStringList &names)
{
    const qint64 dashboard = QCoreApplication::applicationPid();
    const QJsonArray windows = QJsonDocument::fromJson(hyprctl({ "clients", "-j" }).toUtf8()).array();
    for (const QJsonValue &value : windows) {
        const QJsonObject window = value.toObject();
        if (window.value("pid").toInteger() == dashboard
            || (!names.contains(window.value("class").toString().toLower())
                && !names.contains(window.value("initialClass").toString().toLower())))
            continue;
        // Lua configs (Hyprland 0.55+), then older ones
        const QString address = window.value("address").toString();
        return hyprctl({ "dispatch", QString("hl.dsp.focus({ window = \"address:%1\" })").arg(address) }) == "ok"
               || hyprctl({ "dispatch", "focuswindow", "address:" + address }) == "ok";
    }
    return false;
}

} // namespace

QString AppWindows::kwinScript(qint64 dashboardPid)
{
    // KWin's scripting: workspace.windowList(), windowAdded/windowRemoved,
    // and each window's normalWindow, transient, pid, noBorder, setMaximize()...
    return QStringLiteral(R"JS(
// ReDash360: while the dashboard is on screen, app windows fill the screen
// (maximized, no title bar). When it hides (Exit to Desktop) they go back.
const dashboard = %1;
const filled = [];              // [{window, hadNoBorder}], to put back later

function isDashboard(w) { return w.pid === dashboard && w.normalWindow; }
function dashboardShown() { return workspace.windowList().some(isDashboard); }

// An app's own window: not a dialog, pop-up or panel, not a fixed size, and
// not already fullscreen (a game)
function fillable(w) {
    return w.normalWindow && !w.transient && !w.skipTaskbar && w.maximizable
        && !w.fullScreen && w.pid !== dashboard;
}

function fill(w) {
    if (!fillable(w) || filled.some(f => f.window === w))
        return;
    filled.push({ window: w, hadNoBorder: w.noBorder });
    w.noBorder = true;
    w.setMaximize(true, true);
}

function fillAll() { workspace.windowList().forEach(fill); }

function restoreAll() {
    filled.splice(0).forEach(f => {
        f.window.setMaximize(false, false);
        f.window.noBorder = f.hadNoBorder;
    });
}

workspace.windowAdded.connect(w => {
    if (isDashboard(w))
        fillAll();                  // back from the desktop
    else if (dashboardShown())
        fill(w);                    // opened from the dashboard
});

workspace.windowRemoved.connect(w => {
    if (isDashboard(w)) {
        restoreAll();               // Exit to Desktop: normal windows again
        return;
    }
    const i = filled.findIndex(f => f.window === w);
    if (i >= 0)
        filled.splice(i, 1);
});

if (dashboardShown())
    fillAll();
)JS").arg(dashboardPid);
}

void AppWindows::fillScreen()
{
#ifdef HAVE_QTDBUS
    if (!qEnvironmentVariable("XDG_CURRENT_DESKTOP").contains("KDE"))
        return;                                 // only KWin takes these scripts

    // KWin loads scripts from a file, so it goes where only you can read it
    const QString path = QStandardPaths::writableLocation(QStandardPaths::RuntimeLocation)
                         + "/redash360-fill-screen.js";
    QFile file(path);
    if (!file.open(QIODevice::WriteOnly | QIODevice::Truncate)) {
        qWarning("Apps fill the screen: can't write %s", qPrintable(path));
        return;
    }
    file.write(kwinScript(QCoreApplication::applicationPid()).toUtf8());
    file.close();

    QDBusInterface scripting("org.kde.KWin", "/Scripting", "org.kde.kwin.Scripting");
    if (!scripting.isValid()) {
        qInfo("Apps fill the screen: KWin isn't answering, so leaving windows as they are");
        return;
    }
    scripting.call("unloadScript", QString(ScriptName));     // the last start's, if there is one
    const QDBusReply<int> id = scripting.call("loadScript", path, QString(ScriptName));
    if (!id.isValid() || id.value() < 0) {
        qWarning("Apps fill the screen: KWin didn't load the script (%s)", qPrintable(id.error().message()));
        return;
    }

    // Plasma 6 names a loaded script /Scripting/Script<id>, Plasma 5 /<id>
    for (const QString &object : { QString("/Scripting/Script%1").arg(id.value()), QString("/%1").arg(id.value()) }) {
        QDBusInterface script("org.kde.KWin", object, "org.kde.kwin.Script");
        if (script.isValid() && script.call("run").type() != QDBusMessage::ErrorMessage) {
            qInfo("Apps fill the screen: on");
            return;
        }
    }
    qWarning("Apps fill the screen: KWin loaded the script but didn't start it");
#endif
}

QStringList AppWindows::appNames(const QString &command, const QString &icon)
{
    QStringList names;
    auto add = [&names](const QString &name) {
        if (!name.isEmpty() && !names.contains(name.toLower()))
            names << name.toLower();
    };

    // Its icon is usually named after the app ("firefox"), unless it's a file
    if (!icon.startsWith('/'))
        for (const QString &name : icon.split(',', Qt::SkipEmptyParts))
            add(name.trimmed());

    // Its program, past "env NAME=value"; for a Flatpak, its ID
    QStringList words = QProcess::splitCommand(command);
    if (!words.isEmpty() && QFileInfo(words.first()).fileName() == "env") {
        words.removeFirst();
        while (!words.isEmpty() && words.first().contains('='))
            words.removeFirst();
    }
    if (words.isEmpty())
        return names;
    const QString program = QFileInfo(words.first()).fileName();
    if (program == "flatpak") {
        const qsizetype run = words.indexOf("run");
        for (qsizetype i = run + 1; run > 0 && i < words.size(); ++i) {
            if (!words.at(i).startsWith('-')) {
                add(words.at(i));               // the first thing after its options
                break;
            }
        }
    } else {
        static const QStringList starters = { "sh", "bash", "python", "python3", "java", "wine", "gamescope", "prime-run" };
        if (!starters.contains(program))
            add(program);
    }
    return names;
}

bool AppWindows::raise(const QStringList &names)
{
    if (names.isEmpty())
        return false;
    const QString desktop = qEnvironmentVariable("XDG_CURRENT_DESKTOP");
#ifdef HAVE_QTDBUS
    if (desktop.contains("KDE"))
        return raiseOnPlasma(names);
#endif
    if (desktop.contains("Hyprland"))
        return raiseOnHyprland(names);
    return false;
}