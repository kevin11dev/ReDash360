#include "appwindows.h"

#include <QCoreApplication>
#include <QFile>
#include <QStandardPaths>

#ifdef HAVE_QTDBUS
#include <QDBusInterface>
#include <QDBusReply>
#endif

namespace {

constexpr char ScriptName[] = "redash360-fill-screen";

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