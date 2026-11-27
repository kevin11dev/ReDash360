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
#include <QDBusVirtualObject>
#include <QDBusArgument>
#include <QDBusInterface>
#include <QDBusMessage>
#include <QDBusReply>
#endif

namespace {

constexpr char ScriptName[] = "redash360-fill-screen";

// The names a window's program goes by: what Linux calls it (15 letters at
// most) and the name of its file ("firefox", "recomplauncher"), in lower case.
// An app's window often has an ID of its own ("com.recomplauncher.app"), so
// this is how it's still found.
QStringList processNames(qint64 pid)
{
    QStringList names;
    QFile comm(QString("/proc/%1/comm").arg(pid));
    if (comm.open(QIODevice::ReadOnly))
        names << QString::fromUtf8(comm.readAll().trimmed()).toLower();
    const QString exe = QFileInfo(QString("/proc/%1/exe").arg(pid)).symLinkTarget();
    if (!exe.isEmpty())
        names << QFileInfo(exe).fileName().toLower();
    return names;
}

bool anyOf(const QStringList &names, const QStringList &these)
{
    for (const QString &name : these)
        if (!name.isEmpty() && names.contains(name))
            return true;
    return false;
}

#ifdef HAVE_QTDBUS
// Where the KWin script tells the dashboard which window is in front: a call
// to front("1234", "its title") on /FrontWindow
class FrontWindow : public QDBusVirtualObject
{
public:
    qint64 pid = 0;
    QString title;
    int changes = 0;

    QString introspect(const QString &) const override { return {}; }
    bool handleMessage(const QDBusMessage &message, const QDBusConnection &connection) override
    {
        if (message.member() != "front" || message.arguments().isEmpty())
            return false;
        pid = message.arguments().constFirst().toString().toLongLong();
        title = message.arguments().value(1).toString();
        ++changes;
        connection.send(message.createReply());
        return true;
    }
};

FrontWindow *frontWindow()
{
    static FrontWindow *window = new FrontWindow;   // for as long as the dashboard runs
    return window;
}
#endif

#ifdef HAVE_QTDBUS
// KWin: its window search (the one KRunner uses) lists every window when
// asked for "", as "0_{id}", and getWindowInfo() tells what each one is
// (uuid, pid, desktopFile, resourceClass...). Not the dashboard's own.
QList<QVariantMap> plasmaWindows()
{
    QDBusInterface runner("org.kde.KWin", "/WindowsRunner", "org.kde.krunner1");
    QDBusInterface kwin("org.kde.KWin", "/KWin", "org.kde.KWin");
    if (!runner.isValid() || !kwin.isValid())
        return {};
    runner.setTimeout(1000);
    kwin.setTimeout(1000);

    const QDBusMessage reply = runner.call("Match", QString());
    if (reply.type() != QDBusMessage::ReplyMessage || reply.arguments().isEmpty())
        return {};
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

    QList<QVariantMap> infos;
    const qint64 dashboard = QCoreApplication::applicationPid();
    for (const QString &window : std::as_const(windows)) {
        const QDBusReply<QVariantMap> info = kwin.call("getWindowInfo", window.mid(2));
        if (info.isValid() && info.value().value("pid").toLongLong() != dashboard)
            infos << info.value();
    }
    return infos;
}

// What Run() does with a window: 0 brings it to the front, 1 closes it (as
// if you'd clicked its X)
void runOnPlasma(const QVariantMap &window, int action)
{
    QDBusInterface runner("org.kde.KWin", "/WindowsRunner", "org.kde.krunner1");
    runner.call("Run", QString("%1_%2").arg(action).arg(window.value("uuid").toString()), QString());
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

// Hyprland: hyprctl clients -j lists the windows, with their class, pid and
// address; dispatch runs Lua (Hyprland 0.55+) or, for older ones, a dispatcher
bool dispatchOnHyprland(const QString &lua, const QStringList &old)
{
    return hyprctl({ "dispatch", lua }) == "ok" || hyprctl(QStringList{ "dispatch" } + old) == "ok";
}

} // namespace

QString AppWindows::kwinScript(qint64 dashboardPid, const QString &bus)
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

// Which window is in front, for the dashboard: an app there that reads the
// controller itself gets it, instead of the controller working the mouse
const dashboardBus = "%2";
function tellFront() {
    const w = workspace.activeWindow;
    if (dashboardBus)
        callDBus(dashboardBus, "/FrontWindow", "io.github.kevin11dev.ReDash360", "front",
                 w ? String(w.pid) : "0", w ? String(w.caption) : "");
}
workspace.windowActivated.connect(tellFront);
tellFront();
)JS").arg(dashboardPid).arg(bus);
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
    QDBusConnection bus = QDBusConnection::sessionBus();
    bus.registerVirtualObject("/FrontWindow", frontWindow());
    file.write(kwinScript(QCoreApplication::applicationPid(), bus.baseService()).toUtf8());
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
    const QList<Window> open = windows();
    for (const Window &window : open) {
        if (anyOf(names, window.names)) {
            qInfo("Open apps: back to \"%s\"", qPrintable(window.title));
            return activate(window.id);
        }
    }
    if (!open.isEmpty()) {
        QStringList seen;
        for (const Window &window : open)
            seen << window.names.join('/');
        qInfo("Open apps: no window for %s among %s", qPrintable(names.join('/')), qPrintable(seen.join(", ")));
    }
    return false;
}

qint64 AppWindows::frontApp()
{
    const QString desktop = qEnvironmentVariable("XDG_CURRENT_DESKTOP");
#ifdef HAVE_QTDBUS
    if (desktop.contains("KDE"))
        return frontWindow()->pid;
#endif
    if (desktop.contains("Hyprland"))       // {"pid": 1234, "class": ..., ...}
        return QJsonDocument::fromJson(hyprctl({ "activewindow", "-j" }).toUtf8()).object().value("pid").toInteger();
    return 0;
}

int AppWindows::frontChanges()
{
#ifdef HAVE_QTDBUS
    return frontWindow()->changes;
#else
    return 0;
#endif
}

QString AppWindows::frontTitle()
{
    const QString desktop = qEnvironmentVariable("XDG_CURRENT_DESKTOP");
#ifdef HAVE_QTDBUS
    if (desktop.contains("KDE"))
        return frontWindow()->title;
#endif
    if (desktop.contains("Hyprland"))       // {"pid": 1234, "title": ..., ...}
        return QJsonDocument::fromJson(hyprctl({ "activewindow", "-j" }).toUtf8()).object().value("title").toString();
    return {};
}

bool AppWindows::close(qint64 pid)
{
    bool found = false;
    for (const Window &window : windows()) {
        if (pid > 0 && window.pid == pid)
            found |= closeWindow(window.id);
    }
    return found;
}

QList<AppWindows::Window> AppWindows::windows()
{
    QList<Window> list;
    const QString desktop = qEnvironmentVariable("XDG_CURRENT_DESKTOP");
#ifdef HAVE_QTDBUS
    if (desktop.contains("KDE")) {
        for (const QVariantMap &info : plasmaWindows()) {
            if (info.value("skipTaskbar").toBool())
                continue;                       // a tool window, not an app's own
            Window window;
            window.id = info.value("uuid").toString();
            window.pid = info.value("pid").toLongLong();
            window.title = info.value("caption").toString();
            window.names = QStringList{ info.value("desktopFile").toString().toLower(),
                                       info.value("resourceClass").toString().toLower(),
                                       info.value("resourceName").toString().toLower() }
                           + processNames(window.pid);
            window.names.removeAll(QString());
            window.names.removeDuplicates();
            list << window;
        }
    }
#endif
    if (desktop.contains("Hyprland")) {
        const qint64 dashboard = QCoreApplication::applicationPid();
        const QJsonArray clients = QJsonDocument::fromJson(hyprctl({ "clients", "-j" }).toUtf8()).array();
        for (const QJsonValue &value : clients) {
            const QJsonObject client = value.toObject();
            if (client.value("pid").toInteger() == dashboard || client.value("mapped") == false || client.value("hidden") == true)
                continue;
            Window window;
            window.id = client.value("address").toString();
            window.pid = client.value("pid").toInteger();
            window.title = client.value("title").toString();
            window.names = QStringList{ client.value("class").toString().toLower(),
                                       client.value("initialClass").toString().toLower() }
                           + processNames(window.pid);
            window.names.removeAll(QString());
            window.names.removeDuplicates();
            list << window;
        }
    }
    return list;
}

bool AppWindows::activate(const QString &id)
{
    const QString desktop = qEnvironmentVariable("XDG_CURRENT_DESKTOP");
#ifdef HAVE_QTDBUS
    if (desktop.contains("KDE")) {
        runOnPlasma({ { "uuid", id } }, 0);
        return true;
    }
#endif
    if (desktop.contains("Hyprland"))
        return dispatchOnHyprland(QString("hl.dsp.focus({ window = \"address:%1\" })").arg(id), { "focuswindow", "address:" + id });
    return false;
}

bool AppWindows::closeWindow(const QString &id)
{
    const QString desktop = qEnvironmentVariable("XDG_CURRENT_DESKTOP");
#ifdef HAVE_QTDBUS
    if (desktop.contains("KDE")) {
        runOnPlasma({ { "uuid", id } }, 1);
        return true;
    }
#endif
    if (desktop.contains("Hyprland"))
        return dispatchOnHyprland(QString("hl.dsp.window.close({ window = \"address:%1\" })").arg(id), { "closewindow", "address:" + id });
    return false;
}