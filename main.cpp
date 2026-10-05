#include <QGuiApplication>
#include <QIcon>
#include <QQmlApplicationEngine>
#include <QWindow>

#include "applibrary.h"
#include "gamepad.h"

#ifdef HAVE_LAYER_SHELL
#include <LayerShellQt/Window>
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
        layer->setKeyboardInteractivity(Window::KeyboardInteractivityExclusive);   // take the keyboard while open
        layer->setScope("redash360-guide");
        qInfo("Guide overlay: using the Wayland overlay layer");
        return;
    }
#endif
    Q_UNUSED(overlay)
    qInfo("Guide overlay: using an always-on-top window");
}

} // namespace

int main(int argc, char *argv[])
{
    QGuiApplication app(argc, argv);

    // Used by QSettings to name the config file: ~/.config/ReDash360/ReDash360.conf
    app.setOrganizationName("ReDash360");
    app.setApplicationName("ReDash360");

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
    Gamepad gamepad;
    gamepad.setWindow(mainWindow);
    gamepad.setOverlay(overlay);

    return QGuiApplication::exec();
}