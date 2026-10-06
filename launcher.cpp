#include "launcher.h"

#include <QCoreApplication>
#include <QJsonDocument>
#include <QJsonObject>
#include <QProcess>
#include <QSettings>
#include <QTimer>

#ifdef Q_OS_UNIX
#include <signal.h>
#endif

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

void Launcher::rememberGame()
{
    m_gamePid = 0;
    m_gameTitle.clear();

    // Hyprland can tell us which window is in front and which program owns it:
    // hyprctl activewindow -j  ->  {"title": "...", "pid": 12345, ...}
    QProcess hyprctl;
    hyprctl.start("hyprctl", { "activewindow", "-j" });
    if (hyprctl.waitForFinished(1000)) {
        const QJsonObject window = QJsonDocument::fromJson(hyprctl.readAllStandardOutput()).object();
        const qint64 pid = window.value("pid").toInteger();
        if (pid > 0 && pid != QCoreApplication::applicationPid()) {     // not ReDash360 itself
            m_gamePid = pid;
            m_gameTitle = window.value("title").toString();
        }
    }
    emit gameChanged();
}

void Launcher::closeGame()
{
#ifdef Q_OS_UNIX
    if (m_gamePid > 0) {
        const pid_t pid = pid_t(m_gamePid);
        ::kill(pid, SIGTERM);                                   // ask it to quit
        QTimer::singleShot(3000, this, [pid] {                  // still running 3 s later? force it
            if (::kill(pid, 0) == 0)
                ::kill(pid, SIGKILL);
        });
    }
#endif
    m_gamePid = 0;
    m_gameTitle.clear();
    emit gameChanged();
}