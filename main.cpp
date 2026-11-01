#include <QDir>
#include <QGuiApplication>
#include <QIcon>
#include <QLocalServer>
#include <QLocalSocket>
#include <QLockFile>
#include <QQmlApplicationEngine>
#include <QStandardPaths>
#include <QThread>
#include <QWindow>

#include "applibrary.h"
#include "gamepad.h"

#ifdef HAVE_LAYER_SHELL
#include <LayerShellQt/Window>
#endif

#ifdef Q_OS_WIN
#ifndef WIN32_LEAN_AND_MEAN
#define WIN32_LEAN_AND_MEAN
#endif
#include <windows.h>
#endif

namespace {

// Make the Guide overlay window able to cover everything, fullscreen games
// included. On a Wayland desktop (KDE) that takes an "overlay layer" surface,
// the kind Plasma uses for notifications; elsewhere the always-on-top flag
// in GuideOverlay.qml does the job. Must happen before the window is first shown.
void setUpOverlay(QWindow *overlay)
{
#ifdef HAVE_LAYER_SHELL
    if (QGuiApplication::platformName() == "wayland") {
        using LayerShellQt::Window;
        Window *layer = Window::get(overlay);
        layer->setLayer(Window::LayerOverlay);

        Window::Anchors edges = Window::AnchorTop;          // stretch to all four screen edges
        edges |= Window::AnchorBottom;
        edges |= Window::AnchorLeft;
        edges |= Window::AnchorRight;
        layer->setAnchors(edges);

        layer->setExclusiveZone(-1);                        // cover panels too, don't push anything aside
        layer->setKeyboardInteractivity(Window::KeyboardInteractivityOnDemand);   // take the keyboard while open
        layer->setScope("redash360-guide");
        qInfo("Guide overlay: using the Wayland overlay layer");
        return;
    }
#endif
    Q_UNUSED(overlay)
    qInfo("Guide overlay: using an always-on-top window");
}

// Only one dashboard at a time. Starting it again (from the app menu, or by
// autostart in the ReDash360 session, where it's already running) brings the
// running one to the front instead, unless it's started with --replace (say
// from Qt Creator): then the running one quits and the new one takes over.
// The running one listens here for that.
QString instanceName()
{
#ifdef Q_OS_WIN
    return "ReDash360-" + qEnvironmentVariable("USERNAME");             // a named pipe
#else
    return QStandardPaths::writableLocation(QStandardPaths::RuntimeLocation) + "/redash360";
#endif
}

// Held by the running dashboard
QString instanceLock()
{
#ifdef Q_OS_WIN
    return QStandardPaths::writableLocation(QStandardPaths::TempLocation) + "/" + instanceName() + ".lock";
#else
    return instanceName() + ".lock";
#endif
}

// Tell the running dashboard to "show" itself or to "quit". It may only just
// have started, so keep trying for a few seconds.
bool tellRunningDashboard(const QByteArray &message)
{
#ifdef Q_OS_WIN
    AllowSetForegroundWindow(ASFW_ANY);                 // we were just started, so it may take the front from us
#endif
    for (int attempt = 0; attempt < 20; ++attempt) {
        QLocalSocket running;
        running.connectToServer(instanceName());
        if (running.waitForConnected(250)) {
            running.write(message + "\n");
            running.waitForBytesWritten(1000);
            running.disconnectFromServer();
            return true;
        }
        QThread::msleep(250);
    }
    return false;
}

// Come to the front whenever the dashboard is started again, or quit for one
// started with --replace
void listenForRestarts(QLocalServer *server, QWindow *mainWindow)
{
    QLocalServer::removeServer(instanceName());         // left behind if it ever crashed
    server->setSocketOptions(QLocalServer::UserAccessOption);
    if (!server->listen(instanceName()))
        qWarning("ReDash360: can't listen for being started again: %s", qPrintable(server->errorString()));

    QObject::connect(server, &QLocalServer::newConnection, server, [server, mainWindow]() {
        QLocalSocket *other = server->nextPendingConnection();
        QObject::connect(other, &QLocalSocket::disconnected, other, &QObject::deleteLater);
        QObject::connect(other, &QLocalSocket::readyRead, other, [other, mainWindow]() {
            if (!other->canReadLine())
                return;
            const QByteArray message = other->readLine().trimmed();
            if (message == "quit") {
                QCoreApplication::quit();
                return;
            }
            // "show" and on Wayland the token the other one was started with,
            // which lets this one take the focus
            const QByteArray token = message.mid(5);
            if (!token.isEmpty())
                qputenv("XDG_ACTIVATION_TOKEN", token);     // what the next requestActivate() uses
            if (mainWindow)
                QMetaObject::invokeMethod(mainWindow, "showDashboard");
        });
    });
}

} // namespace

int main(int argc, char *argv[])
{
    QGuiApplication app(argc, argv);

    // Used by QSettings to name the config file: ~/.config/ReDash360/ReDash360.conf
    app.setOrganizationName("ReDash360");
    app.setApplicationName("ReDash360");

    QLockFile instance(instanceLock());
    instance.setStaleLockTime(0);                       // held for as long as the dashboard runs
    if (!instance.tryLock()) {
        if (!app.arguments().contains("--replace")) {
            qInfo("ReDash360 is already running, so bringing it to the front (--replace replaces it)");
            if (!tellRunningDashboard("show " + qgetenv("XDG_ACTIVATION_TOKEN")))
                qWarning("ReDash360 is already running, but didn't answer");
            return 0;
        }
        if (!tellRunningDashboard("quit") || !instance.tryLock(5000)) {
            qWarning("ReDash360 is already running, and didn't quit");
            return 1;
        }
    }

    // The folders for your own backgrounds, gamerpics, avatars and sounds
    // (~/.local/share/ReDash360/...), so they're there to fill
    const QString data = QStandardPaths::writableLocation(QStandardPaths::GenericDataLocation) + "/ReDash360";
    for (const char *folder : { "backgrounds", "gamerpics", "avatars", "sounds" })
        QDir().mkpath(data + "/" + folder);

    Gamepad gamepad(nullptr);

    QQmlApplicationEngine engine;
    QObject::connect(
        &engine,
        &QQmlApplicationEngine::objectCreationFailed,
        &app,
        []() { QCoreApplication::exit(-1); },
        Qt::QueuedConnection);

    // App icons for QML ("image://appicon/firefox"); some apps keep theirs in /usr/share/pixmaps
    engine.addImageProvider("appicon", new AppIconProvider);
    QIcon::setFallbackSearchPaths(QIcon::fallbackSearchPaths() << "/usr/share/pixmaps");

    engine.loadFromModule("ReDash360", "Main");

    const auto roots = engine.rootObjects();
    QWindow *mainWindow = roots.isEmpty() ? nullptr : qobject_cast<QWindow *>(roots.first());
    QWindow *overlay = mainWindow
                           ? qobject_cast<QWindow *>(mainWindow->property("guideOverlay").value<QObject *>())
                           : nullptr;
    if (overlay)
        setUpOverlay(overlay);
    else
        qWarning("Guide overlay: window not found");

    // Controller buttons become key presses for the dashboard, or the Guide over a game
    gamepad.setWindow(mainWindow);
    gamepad.setOverlay(overlay);

    QLocalServer restarts;
    listenForRestarts(&restarts, mainWindow);

    return QGuiApplication::exec();
}