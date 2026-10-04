#include "launcher.h"

#include <QProcess>
#include <QSettings>

Launcher::Launcher(QObject *parent)
    : QObject(parent)
{
    // Load what was played last time (stored in ~/.config/ReDash360/ReDash360.conf)
    QSettings settings;
    m_lastName = settings.value("lastPlayed/name").toString();
    m_lastCommand = settings.value("lastPlayed/command").toString();
}

bool Launcher::run(const QString &command)
{
    // "eject -T" -> program "eject", arguments ["-T"]
    QStringList arguments = QProcess::splitCommand(command);
    if (arguments.isEmpty())
        return false;
    const QString program = arguments.takeFirst();

    // Detached: the program keeps running on its own, even after ReDash360 quits
    const bool started = QProcess::startDetached(program, arguments);
    if (!started)
        qWarning("Launcher: could not start \"%s\"", qPrintable(command));
    return started;
}

bool Launcher::play(const QString &name, const QString &command)
{
    if (!run(command))
        return false;

    if (name != m_lastName || command != m_lastCommand) {
        m_lastName = name;
        m_lastCommand = command;

        QSettings settings;
        settings.setValue("lastPlayed/name", name);
        settings.setValue("lastPlayed/command", command);

        emit lastPlayedChanged();   // tells QML bindings to update
    }
    return true;
}