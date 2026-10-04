#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QWindow>

#include "gamepad.h"

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
    engine.loadFromModule("ReDash360", "Main");

    // Controller buttons become key presses for the main window
    Gamepad gamepad;
    if (!engine.rootObjects().isEmpty())
        gamepad.setWindow(qobject_cast<QWindow *>(engine.rootObjects().first()));

    return QGuiApplication::exec();
}