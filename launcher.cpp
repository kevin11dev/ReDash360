#include "launcher.h"

#include <QProcess>

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