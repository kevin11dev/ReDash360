#include "launcher.h"
#include "appwindows.h"
#include "gamelibrary.h"
#include <signal.h>

#include <QCoreApplication>
#include <QDir>
#include <QFile>
#include <QSaveFile>
#include <QSet>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QProcess>
#include <QSettings>
#include <QTimer>

#ifdef Q_OS_UNIX
#endif

namespace {

constexpr int MaxRecents = 12;

// What ReDash360 puts in the environment of a game it starts itself: REDASH360_GAME=1
constexpr char GameVariable[] = "REDASH360_GAME";

// Did ReDash360 start this process as a game itself (a ROM's emulator, a game
// from Game Folders)? Then it has the marker, and so does everything it starts,
// in a Flatpak's sandbox too.
bool startedAsGame(qint64 pid)
{
    QFile environment(QString("/proc/%1/environ").arg(pid));
    if (!environment.open(QIODevice::ReadOnly))
        return false;
    return environment.readAll().split('\0').contains(QByteArray(GameVariable) + "=1");
}

// Was this program started by a game launcher? Steam starts every game through
// its "reaper" helper, and Heroic, Faugus (umu-run) and Lutris start theirs
// too. Discord, Firefox and Steam's own window aren't, so they're left alone.
// Works by walking up the parents in /proc (Linux only).
bool isGame(qint64 pid)
{
    static const QStringList launchers = { "reaper", "heroic", "faugus-launcher", "umu-run", "lutris" };

    qint64 current = pid;
    for (int depth = 0; depth < 32 && current > 1; ++depth) {
        if (startedAsGame(current))
            return true;
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

#ifdef Q_OS_LINUX
// ---- Steam -----------------------------------------------------------------

// Is this command Steam? (/usr/bin/steam, or the Flatpak)
bool isSteam(const QString &program, const QStringList &arguments)
{
    const QString name = QFileInfo(program).fileName();
    return name == "steam" || name == "steam-native" || name == "steam-runtime"
           || (name == "flatpak" && arguments.contains("com.valvesoftware.Steam"));
}

bool steamRunning()
{
    const QDir proc("/proc");
    for (const QString &entry : proc.entryList(QDir::Dirs | QDir::NoDotAndDotDot)) {
        // "1234 (steam) S ...": its name, then its state (Z: it has finished)
        QFile stat(proc.filePath(entry + "/stat"));
        if (!stat.open(QIODevice::ReadOnly))
            continue;
        const QByteArray line = stat.readAll();
        const qsizetype open = line.indexOf('(');
        const qsizetype close = line.lastIndexOf(')');
        if (open < 0 || close < open || close + 2 >= line.size())
            continue;
        const QByteArray name = line.mid(open + 1, close - open - 1);
        if ((name == "steam" || name == "steam.sh") && line.at(close + 2) != 'Z')
            return true;
    }
    return false;
}

// In Steam's text settings (a .vdf: "name" "value", and "name" { ... } for a
// section), set a key straight inside the outermost section, or add it at the
// end of it. The rest stays exactly as it was. False if it isn't a file like that.
bool setTopKey(QByteArray &vdf, const QByteArray &key, const QByteArray &value)
{
    struct Token { qsizetype start; qsizetype end; char kind; };   // a "string", { or }
    QList<Token> tokens;
    for (qsizetype i = 0; i < vdf.size(); ++i) {
        const char c = vdf.at(i);
        if (c == '"') {
            qsizetype end = i + 1;
            while (end < vdf.size() && vdf.at(end) != '"')
                end += vdf.at(end) == '\\' ? 2 : 1;
            if (end >= vdf.size())
                return false;
            tokens.append({ i, end + 1, '"' });
            i = end;
        } else if (c == '{' || c == '}') {
            tokens.append({ i, i + 1, c });
        }
    }

    int depth = 0;
    bool isName = true;                             // a name comes first, then its value or section
    for (qsizetype t = 0; t < tokens.size(); ++t) {
        const Token &token = tokens.at(t);
        if (token.kind == '{') {
            ++depth;
            isName = true;
        } else if (token.kind == '}') {
            if (depth == 1) {                       // the end of the outermost section: add it here
                const QByteArray line = "\t\"" + key + "\"\t\t\"" + value + "\"\n";
                qsizetype at = token.start;
                while (at > 0 && (vdf.at(at - 1) == '\t' || vdf.at(at - 1) == ' '))
                    --at;
                if (at > 0 && vdf.at(at - 1) == '\n')
                    vdf.insert(at, line);           // on its own line, before the }
                else
                    vdf.insert(token.start, "\n" + line);
                return true;
            }
            --depth;
            isName = true;
        } else if (isName) {
            const QByteArray name = vdf.mid(token.start + 1, token.end - token.start - 2);
            if (depth == 1 && name == key && t + 1 < tokens.size() && tokens.at(t + 1).kind == '"') {
                const Token &old = tokens.at(t + 1);
                vdf.replace(old.start, old.end - old.start, '"' + value + '"');
                return true;
            }
            isName = false;
        } else {
            isName = true;                          // that was a value
        }
    }
    return false;
}

// Steam's "Guide Button Focuses Steam" (Steam > Settings > Controller): with
// it on, the Xbox button brings Steam to the front, and Steam and the Guide
// fight over it. Turned off once for each Steam account, so turning it back on
// in Steam sticks: Controller_CheckGuideButton in the account's
// localconfig.vdf. Only while Steam isn't running, as Steam writes its
// settings back when it quits.
void turnOffSteamGuideButton()
{
    const QString home = QDir::homePath();
    QSet<QString> files;                            // ~/.steam/steam is a link to the first one
    for (const QString &steam : { home + "/.local/share/Steam", home + "/.steam/steam",
                                 home + "/.var/app/com.valvesoftware.Steam/.local/share/Steam" }) {
        const QDir userdata(steam + "/userdata");
        for (const QString &account : userdata.entryList(QDir::Dirs | QDir::NoDotAndDotDot)) {
            const QFileInfo file(userdata.filePath(account + "/config/localconfig.vdf"));
            if (file.exists())
                files.insert(file.canonicalFilePath());
        }
    }

    QSettings settings;
    QStringList done = settings.value("steam/guideButtonOff").toStringList();
    for (const QString &path : std::as_const(files)) {
        if (done.contains(path))
            continue;
        QFile file(path);
        if (!file.open(QIODevice::ReadOnly))
            continue;
        QByteArray vdf = file.readAll();
        file.close();
        if (!setTopKey(vdf, "Controller_CheckGuideButton", "0")) {
            qWarning("Launcher: can't read Steam's settings in %s", qPrintable(path));
            continue;
        }
        QSaveFile save(path);
        if (save.open(QIODevice::WriteOnly) && save.write(vdf) == vdf.size() && save.commit()) {
            done << path;
            qInfo("Launcher: turned off Steam's \"Guide Button Focuses Steam\" in %s", qPrintable(path));
        }
    }
    settings.setValue("steam/guideButtonOff", done);
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
    #ifdef Q_OS_LINUX
        // Steam: its Xbox button setting first, while it isn't running yet. Then
        // Steam itself (not one of its games) opens in Big Picture, or switches
        // to it when it's open already.
        if (isSteam(program, arguments)) {
            const bool running = steamRunning();
            if (!running)
                turnOffSteamGuideButton();
            if (!command.contains("steam://"))
                arguments << (running ? "steam://open/bigpicture" : "-gamepadui");
        }
    #endif

    // Detached: the program keeps running on its own, even after ReDash360 quits.
    // A game that has to be started in its own folder (Faugus's) is started there.
    QProcess process;
    process.setProgram(program);
    process.setArguments(arguments);
    process.setWorkingDirectory(GameLibrary::startFolder(command));
    if (GameLibrary::isDirect(command)) {
        // A game ReDash360 starts itself gets the marker, so the Guide knows
        // it's a game: it pauses it, and Xbox Home quits it (see isGame())
        QProcessEnvironment environment = QProcessEnvironment::systemEnvironment();
        environment.insert(GameVariable, "1");
        process.setProcessEnvironment(environment);
    }
    const bool started = process.startDetached();
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
    // Open already? Then back to its window, not a second one of it. Not
    // Steam: starting it again is what switches it to Big Picture (see run())
    bool steam = false;
#ifdef Q_OS_LINUX
    QStringList words = QProcess::splitCommand(command);
    steam = !words.isEmpty() && isSteam(words.takeFirst(), words);
#endif
    if (steam || !AppWindows::raise(AppWindows::appNames(command, icon))) {
        if (!run(command))
            return false;
    }
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

bool Launcher::signOut()
{
#ifdef Q_OS_WIN
    return run("shutdown /l");
#else
    const QString desktop = qEnvironmentVariable("XDG_CURRENT_DESKTOP");
    if (desktop.contains("KDE"))
        return run("dbus-send --session --type=method_call --dest=org.kde.Shutdown /Shutdown org.kde.Shutdown.logout");
    if (desktop.contains("GNOME"))
        return run("gnome-session-quit --logout --no-prompt");
    if (desktop.contains("Hyprland")) {
        // When uwsm started Hyprland it ends the session, so everything stops
        // in order; otherwise Hyprland's own exit, in Lua for Lua configs
        // (Hyprland 0.55+) or by name for older ones
        if (QProcess::execute("uwsm", { "check", "is-active", "compositor-only" }) == 0)
            return run("uwsm stop");
        return hyprctl({ "dispatch", "hl.dsp.exit()" }) == "ok" || hyprctl({ "dispatch", "exit" }) == "ok";
    }
    return run("loginctl terminate-session " + qEnvironmentVariable("XDG_SESSION_ID", "self"));
#endif
}

void Launcher::exitToDesktop()
{
#ifdef Q_OS_WIN
    QCoreApplication::quit();
#else
    // The login screen names the session in DESKTOP_SESSION. In the Hyprland
    // one, your Hyprland desktop is already there. (Started again later,
    // Plasma's desktop sees it's already running and leaves it at that.)
    if (qEnvironmentVariable("DESKTOP_SESSION") == "redash360-plasma")
        run("plasmashell");
    emit desktopRequested();
#endif
}

bool Launcher::readsController(qint64 pid)
{
#ifdef Q_OS_LINUX
    // A controller, as a program has it open: /dev/input/js0, /dev/hidraw0
    // (how Steam and SDL read them), or an /dev/input/event0 that has an A
    // button (BTN_SOUTH, in the bit list Linux shows for each device)
    auto isController = [](const QString &file) {
        if (file.startsWith("/dev/input/js") || file.startsWith("/dev/hidraw"))
            return true;
        if (!file.startsWith("/dev/input/event"))
            return false;
        QFile keys("/sys/class/input/" + QFileInfo(file).fileName() + "/device/capabilities/key");
        if (!keys.open(QIODevice::ReadOnly))
            return false;
        constexpr int ButtonSouth = 0x130;
        constexpr int WordBits = QT_POINTER_SIZE * 8;
        const QStringList words = QString::fromLatin1(keys.readAll()).simplified().split(' ', Qt::SkipEmptyParts);
        const int word = int(words.size()) - 1 - ButtonSouth / WordBits;         // the lowest last
        return word >= 0 && (words.at(word).toULongLong(nullptr, 16) >> (ButtonSouth % WordBits)) & 1;
    };

    // The program, then the ones that started it (Steam's window is its
    // steamwebhelper, while Steam itself reads the controller), up to the
    // dashboard or the session
    const qint64 self = QCoreApplication::applicationPid();
    qint64 current = pid;
    for (int depth = 0; depth < 8 && current > 1 && current != self; ++depth) {
        const QDir fds(QString("/proc/%1/fd").arg(current));
        for (const QString &fd : fds.entryList(QDir::AllEntries | QDir::System | QDir::NoDotAndDotDot)) {
            if (isController(QFileInfo(fds.filePath(fd)).symLinkTarget()))
                return true;
        }
        QFile stat(QString("/proc/%1/stat").arg(current));    // "1234 (name) S 1200 ...": 1200 started it
        if (!stat.open(QIODevice::ReadOnly))
            break;
        const QString line = QString::fromUtf8(stat.readAll());
        if (line.mid(line.indexOf('(') + 1, line.lastIndexOf(')') - line.indexOf('(') - 1) == "systemd")
            break;
        current = line.mid(line.lastIndexOf(')') + 2).section(' ', 1, 1).toLongLong();
    }
#else
    Q_UNUSED(pid)
#endif
    return false;
}

bool Launcher::gameRunning()
{
#ifdef Q_OS_LINUX
    // Every program running is a folder in /proc, named by its number
    const qint64 self = QCoreApplication::applicationPid();
    const QDir proc("/proc");
    for (const QString &entry : proc.entryList(QDir::Dirs | QDir::NoDotAndDotDot)) {
        bool isNumber = false;
        const qint64 pid = entry.toLongLong(&isNumber);
        if (!isNumber || pid == self)
            continue;

        // Its name (up to 15 letters). Steam starts every game under its
        // "reaper"; Faugus starts games with umu-run, and so do Heroic and
        // Lutris with Proton.
        QFile comm(proc.filePath(entry + "/comm"));
        if (!comm.open(QIODevice::ReadOnly))
            continue;
        const QByteArray name = comm.readAll().trimmed();
        if (name == "reaper" || name == "umu-run")
            return true;

        // A Windows game in Wine or Proton goes by its Windows path
        // ("C:\Games\Game.exe"), the first thing in its command line
        QFile commandLine(proc.filePath(entry + "/cmdline"));
        if (commandLine.open(QIODevice::ReadOnly)
            && commandLine.read(4096).split('\0').value(0).toLower().endsWith(".exe"))
            return true;

        // A ROM's emulator or a Game Folders game: ReDash360 marked it
        if (startedAsGame(pid))
            return true;
    }
#endif
    return false;
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