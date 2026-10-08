#include "launcher.h"

#include <QCoreApplication>
#include <QFile>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QProcess>
#include <QSettings>
#include <QTimer>

#ifdef Q_OS_UNIX
#include <signal.h>
#endif

namespace {

constexpr int MaxRecents = 12;

// Was this program started by a game launcher? Steam starts every game through
// its "reaper" helper, and Heroic, Faugus (umu-run) and Lutris start theirs
// too. Discord, Firefox and Steam's own window aren't, so they're left alone.
// Works by walking up the parents in /proc (Linux only).
bool isGame(qint64 pid)
{
    static const QStringList launchers = { "reaper", "heroic", "faugus-launcher", "umu-run", "lutris" };

    qint64 current = pid;
    for (int depth = 0; depth < 32 && current > 1; ++depth) {
        // /proc/<pid>/stat looks like: 1234 (name) S 1200 ...   (1200 = parent)
        QFile stat(QString("/proc/%1/stat").arg(current));
        if (!stat.open(QIODevice::ReadOnly))
            return false;
        const QString line = QString::fromUtf8(stat.readAll());
        const int open = line.indexOf('(');
        const int close = line.lastIndexOf(')');
        const QString name = line.mid(open + 1, close - open - 1);

        if (current != pid && launchers.contains(name))
            return true;
        current = line.mid(close + 2).section(' ', 1, 1).toLongLong();
    }
    return false;
}

#ifdef Q_OS_UNIX
// Run hyprctl and return what it prints ("" if Hyprland isn't running)
QString hyprctl(const QStringList &arguments)
{
    QProcess process;
    process.start("hyprctl", arguments);
    if (!process.waitForFinished(1000))
        return {};
    return QString::fromUtf8(process.readAllStandardOutput()).trimmed();
}

// Hyprland's VRR setting (misc:vrr): 0 = off, 1 to 3 = on in some way
int vrrSetting()
{
    const QByteArray json = hyprctl({ "getoption", "misc:vrr", "-j" }).toUtf8();
    return QJsonDocument::fromJson(json).object().value("int").toInt();
}

void setVrrSetting(int value)
{
    // Lua configs (Hyprland 0.55+) change options with eval, older configs with keyword
    const QString lua = QString("hl.config({ misc = { vrr = %1 } })").arg(value);
    if (hyprctl({ "eval", lua }) != "ok")
        hyprctl({ "keyword", "misc:vrr", QString::number(value) });
}
#endif

} // namespace

Launcher::Launcher(QObject *parent)
    : QObject(parent)
{
    // Load what was played last time (stored in ~/.config/ReDash360/ReDash360.conf)
    QSettings settings;
    m_lastName = settings.value("lastPlayed/name").toString();
    m_lastCommand = settings.value("lastPlayed/command").toString();
    m_recents = QJsonDocument::fromJson(settings.value("recents/list").toByteArray()).array().toVariantList();
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
    addRecent("game", name, command, QString());
    return true;
}


bool Launcher::openApp(const QString &name, const QString &command, const QString &icon)
{
    if (!run(command))
        return false;
    addRecent("app", name, command, icon);
    return true;
}

void Launcher::addRecent(const QString &kind, const QString &name, const QString &command, const QString &icon)
{
    // Already in the list? Then it moves to the front instead of being there twice
    for (int i = 0; i < m_recents.size(); ++i) {
        if (m_recents.at(i).toMap().value("command").toString() == command) {
            m_recents.removeAt(i);
            break;
        }
    }

    m_recents.prepend(QVariantMap{
        { "kind", kind },
        { "name", name },
        { "command", command },
        { "icon", icon },
        });
    while (m_recents.size() > MaxRecents)
        m_recents.removeLast();

    saveRecents();
}

void Launcher::removeRecent(int index)
{
    if (index < 0 || index >= m_recents.size())
        return;
    m_recents.removeAt(index);
    saveRecents();
}

void Launcher::saveRecents()
{
    const QJsonDocument json(QJsonArray::fromVariantList(m_recents));
    QSettings settings;
    settings.setValue("recents/list", QString::fromUtf8(json.toJson(QJsonDocument::Compact)));
    emit recentsChanged();
}

void Launcher::eject(){
    m_lastName.clear();
    m_lastCommand.clear();

    QSettings settings;
    settings.remove("lastPlayed");

    emit lastPlayedChanged();
}

Launcher::~Launcher()
{
    resumeGame();       // never leave a game frozen when ReDash360 quits
}

void Launcher::rememberGame()
{
    resumeGame();
    m_gamePid = 0;
    m_gameTitle.clear();

    // Hyprland can tell us which window is in front and which program owns it:
    // hyprctl activewindow -j  ->  {"title": "...", "pid": 12345, ...}
    QProcess hyprctl;
    hyprctl.start("hyprctl", { "activewindow", "-j" });
    if (hyprctl.waitForFinished(1000)) {
        const QJsonObject window = QJsonDocument::fromJson(hyprctl.readAllStandardOutput()).object();
        const qint64 pid = window.value("pid").toInteger();
        const QString title = window.value("title").toString();
        if (pid > 0 && pid != QCoreApplication::applicationPid() && isGame(pid)) {
            m_gamePid = pid;
            m_gameTitle = title;
        } else if (pid > 0) {
            qInfo("Guide overlay: \"%s\" isn't a game, leaving it running", qPrintable(title));
        }
    }
    emit gameChanged();
}

void Launcher::closeGame()
{
    resumeGame();
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

void Launcher::pauseGame()
{
#ifdef Q_OS_UNIX
    if (m_gamePid <= 0 || m_gamePaused)
        return;

    // With VRR on, a fullscreen game decides when the screen updates, so once
    // it's frozen Hyprland stops showing the Guide. VRR goes off while it's open.
    m_savedVrr = vrrSetting();
    if (m_savedVrr > 0)
        setVrrSetting(0);

    // SIGSTOP freezes the whole game, like pausing it: it can't see your
    // button presses or keep playing. SIGCONT lets it carry on.
    m_gamePaused = ::kill(pid_t(m_gamePid), SIGSTOP) == 0;
#endif
}

void Launcher::resumeGame()
{
#ifdef Q_OS_UNIX
    if (m_gamePaused)
        ::kill(pid_t(m_gamePid), SIGCONT);

    if (m_savedVrr > 0) {
        setVrrSetting(m_savedVrr);      // VRR back to how you had it
        m_savedVrr = 0;
    }
#endif
    m_gamePaused = false;
}