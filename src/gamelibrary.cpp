#include "gamelibrary.h"
#include "roms.h"

#include <QDir>
#include <QDirIterator>
#include <QFile>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QRegularExpression>
#include <QUrl>
#include <QFileInfo>
#include <QSettings>
#include <QHash>
#include <QSet>

namespace {

// Steam "games" that are really tools; hide them
bool isSteamTool(const QString &name)
{
    return name.startsWith("Proton")
    || name.startsWith("Steam Linux Runtime")
        || name.startsWith("Steamworks Common")
        || name.startsWith("Steam Runtime");
}

QString readFile(const QString &path)
{
    QFile file(path);
    if (!file.open(QIODevice::ReadOnly | QIODevice::Text))
        return {};
    return QString::fromUtf8(file.readAll());
}

// First match of `"key"   "value"` in a Steam .vdf/.acf file
QString vdfValue(const QString &text, const QString &key)
{
    const QRegularExpression re("\"" + key + "\"\\s+\"([^\"]*)\"");
    return re.match(text).captured(1);
}

// Parse a JSON file; returns an empty document if it's missing or broken
QJsonDocument readJson(const QString &path)
{
    QFile file(path);
    if (!file.open(QIODevice::ReadOnly))
        return {};
    return QJsonDocument::fromJson(file.readAll());
}

QVariantMap toMap(const Game &game){
    return{
        {"name", game.name},
        {"source", game.source},
        {"command", game.command},
        {"cover", game.cover},
        {"banner", game.banner},
        {"hero", game.hero},
        {"system", game.system}
    };
}

// Where Settings > Preferences keeps the extra folders: [library] in ReDash360.conf
QString folderKey(const QString &kind)
{
    return kind == "roms" ? "library/romFolders" : "library/gameFolders";
}

QStringList savedFolders(const QString &kind)
{
    return QSettings().value(folderKey(kind)).toStringList();
}

// A path as one argument for Launcher.run(), quotes and all
QString quoted(QString text)
{
    text.replace("\"", "\"\"\"");
    return "\"" + text + "\"";
}

// "Celeste-1.4.0.0-x86_64" / "hollow_knight" -> "Celeste" / "hollow knight"
QString gameName(QString name)
{
    static const QRegularExpression trailing("[-_ ]*(v?\\d+(\\.\\d+)+|x86_64|x86|amd64|linux|appimage)$",
                                             QRegularExpression::CaseInsensitiveOption);
    for (int i = 0; i < 4; ++i)
        name.remove(trailing);
    name.replace('_', ' ');
    return name.simplified();
}

// "~/Games/x.exe" or "$HOME/Games/x.exe" -> "/home/you/Games/x.exe", the way
// Faugus reads its paths (variables that aren't set stay as they are)
QString expandPath(QString path)
{
    if (path == "~" || path.startsWith("~/"))
        path.replace(0, 1, QDir::homePath());
    static const QRegularExpression variable("\\$(\\w+)|\\$\\{(\\w+)\\}");
    int from = 0;
    QRegularExpressionMatch match;
    while ((match = variable.match(path, from)).hasMatch()) {
        const QString name = match.captured(1).isEmpty() ? match.captured(2) : match.captured(1);
        from = match.capturedEnd();
        if (!qEnvironmentVariableIsSet(qPrintable(name)))
            continue;
        const QString value = qEnvironmentVariable(qPrintable(name));
        path.replace(match.capturedStart(), match.capturedLength(), value);
        from = match.capturedStart() + value.size();
    }
    return path;
}

// Each game's command -> the folder it has to be started in, from the last refresh()
QHash<QString, QString> &startFolders()
{
    static QHash<QString, QString> folders;
    return folders;
}

// The commands that run a game themselves, from the last refresh()
QSet<QString> &directCommands()
{
    static QSet<QString> commands;
    return commands;
}

} // namespace

GameLibrary::GameLibrary(QObject *parent)
    : QAbstractListModel(parent)
{
    refresh();
}

int GameLibrary::rowCount(const QModelIndex &parent) const
{
    return parent.isValid() ? 0 : m_games.size();
}

QVariant GameLibrary::data(const QModelIndex &index, int role) const
{
    if (!index.isValid() || index.row() >= m_games.size())
        return {};

    const Game &game = m_games.at(index.row());
    switch (role) {
    case NameRole:    return game.name;
    case SourceRole:  return game.source;
    case CommandRole: return game.command;
    case CoverRole:   return game.cover;
    case BannerRole:  return game.banner;
    }
    return {};
}

QHash<int, QByteArray> GameLibrary::roleNames() const
{
    // These are the names you use in QML delegates: model.name, model.cover, ...
    return {
        { NameRole, "name" },
        { SourceRole, "source" },
        { CommandRole, "command" },
        { CoverRole, "cover" },
        { BannerRole, "banner" },
        };
}

QVariantList GameLibrary::all() const
{
    QVariantList list;
    for (const Game &game : m_games)
        list << toMap(game);
    return list;
}

QVariantMap GameLibrary::find(const QString &command) const
{
    for (const Game &game : m_games) {
        if (game.command == command)
            return toMap(game);
    }
    return {};
}

void GameLibrary::refresh()
{
    QList<Game> games = scanSteam();
    games += scanHeroic();
    games += scanFaugus();
    games += scanFolders(savedFolders("games"));
    games += scanRoms(savedFolders("roms"));

    std::sort(games.begin(), games.end(), [](const Game &a, const Game &b) {
        return a.name.compare(b.name, Qt::CaseInsensitive) < 0;
    });

    startFolders().clear();
    directCommands().clear();
    for (const Game &game : std::as_const(games)) {
        if (!game.folder.isEmpty())
            startFolders().insert(game.command, game.folder);
        if (game.direct)
            directCommands().insert(game.command);
    }

    beginResetModel();      // tell views the whole list is about to change
    m_games = games;
    endResetModel();
    emit countChanged();
}

QString GameLibrary::startFolder(const QString &command)
{
    return startFolders().value(command);
}

bool GameLibrary::isDirect(const QString &command)
{
    return directCommands().contains(command);
}

QStringList GameLibrary::gameFolders() const
{
    return savedFolders("games");
}

QStringList GameLibrary::romFolders() const
{
    return savedFolders("roms");
}

void GameLibrary::addFolder(const QString &kind, const QString &path)
{
    // A path, or a file:// URL from a folder list in QML
    QString folder = path.startsWith("file:") ? QUrl(path).toLocalFile() : path;
    folder = QDir::cleanPath(folder);
    QStringList folders = savedFolders(kind);
    if (folder.isEmpty() || folders.contains(folder))
        return;
    folders << folder;
    QSettings().setValue(folderKey(kind), folders);
    emit foldersChanged();
    refresh();
}

void GameLibrary::removeFolder(const QString &kind, const QString &path)
{
    QStringList folders = savedFolders(kind);
    if (!folders.removeAll(path))
        return;
    QSettings().setValue(folderKey(kind), folders);
    emit foldersChanged();
    refresh();
}

// Games in folders you chose, that no launcher knows about: an AppImage, or a
// folder with a Linux game in it (GOG's start.sh, itch.io's .x86_64, a program
// named like the folder). Each starts in its own folder, as games expect.
// Windows games belong in Faugus or Heroic, which run them with Proton.
QList<Game> GameLibrary::scanFolders(const QStringList &folders)
{
    QList<Game> games;
    QStringList seen;
    const auto add = [&](const QString &name, const QString &program, const QString &workingDir, const QString &cover) {
        if (seen.contains(program))
            return;
        seen << program;
        Game game;
        game.name = gameName(name);
        game.source = "Linux";
        game.direct = true;
        // env -C: start it from its own folder; a script runs through sh even if it isn't executable
        game.command = "env -C " + quoted(workingDir) + " "
                       + (program.endsWith(".sh") ? "sh " : "") + quoted(program);
        game.cover = cover;
        if (!game.name.isEmpty())
            games << game;
    };
    const auto picture = [](const QDir &dir) {
        for (const QString &file : { "cover.png", "cover.jpg", "folder.jpg", "folder.png", "support/icon.png", "icon.png" }) {
            if (dir.exists(file))
                return QUrl::fromLocalFile(dir.filePath(file)).toString();
        }
        return QString();
    };

    for (const QString &folder : folders) {
        const QDir dir(folder);
        if (!dir.exists())
            continue;

        for (const QFileInfo &file : dir.entryInfoList({ "*.AppImage", "*.appimage" }, QDir::Files))
            add(file.completeBaseName(), file.absoluteFilePath(), file.absolutePath(), "");

        for (const QFileInfo &sub : dir.entryInfoList(QDir::Dirs | QDir::NoDotAndDotDot, QDir::Name)) {
            const QDir game(sub.absoluteFilePath());
            QString program;
            if (game.exists("start.sh"))                                        // GOG
                program = game.filePath("start.sh");
            for (const QString &pattern : { QString("*.AppImage"), QString("*.x86_64") }) {
                if (program.isEmpty()) {
                    const QStringList found = game.entryList({ pattern }, QDir::Files, QDir::Name);
                    if (!found.isEmpty())
                        program = game.filePath(found.first());
                }
            }
            if (program.isEmpty()) {                                            // a program named like the folder
                for (const QFileInfo &file : game.entryInfoList(QDir::Files | QDir::Executable)) {
                    if (file.completeBaseName().compare(sub.fileName(), Qt::CaseInsensitive) == 0
                        && file.suffix().isEmpty()) {
                        program = file.absoluteFilePath();
                        break;
                    }
                }
            }
            if (program.isEmpty()) {                                            // its only launch script
                const QStringList scripts = game.entryList({ "*.sh" }, QDir::Files);
                if (scripts.size() == 1)
                    program = game.filePath(scripts.first());
            }
            if (!program.isEmpty())
                add(sub.fileName(), program, game.absolutePath(), picture(game));
        }
    }
    return games;
}

QList<Game> GameLibrary::scanSteam()
{
    // Normal install, the ~/.steam symlink, and the Flatpak version
    const QString home = QDir::homePath();
    const QStringList roots = {
        home + "/.local/share/Steam",
        home + "/.steam/steam",
        home + "/.var/app/com.valvesoftware.Steam/.local/share/Steam",
    };

    QList<Game> games;
    QStringList seenIds;

    for (const QString &root : roots) {
        if (!QDir(root + "/steamapps").exists())
            continue;

        // Every Steam library folder (other drives too), plus the main one
        QStringList libraries = { root };
        const QString folders = readFile(root + "/steamapps/libraryfolders.vdf");
        static const QRegularExpression pathRe("\"path\"\\s+\"([^\"]+)\"");
        for (auto it = pathRe.globalMatch(folders); it.hasNext();)
            libraries << it.next().captured(1);

        for (const QString &library : std::as_const(libraries)) {
            QDir steamapps(library + "/steamapps");
            const QStringList manifests = steamapps.entryList({ "appmanifest_*.acf" }, QDir::Files);

            for (const QString &manifest : manifests) {
                const QString text = readFile(steamapps.filePath(manifest));
                const QString id = vdfValue(text, "appid");
                const QString name = vdfValue(text, "name");
                if (id.isEmpty() || name.isEmpty() || isSteamTool(name) || seenIds.contains(id))
                    continue;
                seenIds << id;

                Game game;
                game.name = name;
                game.source = "Steam";
                game.command = "steam steam://rungameid/" + id;

                // Steam's own cached box art (tall 600x900 cover), if it has one...
                QDirIterator art(root + "/appcache/librarycache/" + id,
                                 { "library_600x900*.jpg" }, QDir::Files,
                                 QDirIterator::Subdirectories);
                if (art.hasNext())
                    game.cover = QUrl::fromLocalFile(art.next()).toString();
                else    // ...otherwise download it from Steam's image server
                    game.cover = "https://cdn.cloudflare.steamstatic.com/steam/apps/"
                                 + id + "/library_600x900.jpg";

                // Wide store banner (header.jpg) for wide tiles, cached or from Steam
                QDirIterator header(root + "/appcache/librarycache/" + id,
                                    { "header.jpg" }, QDir::Files,
                                    QDirIterator::Subdirectories);
                if (header.hasNext())
                    game.banner = QUrl::fromLocalFile(header.next()).toString();
                else
                    game.banner = "https://cdn.cloudflare.steamstatic.com/steam/apps/"
                                  + id + "/header.jpg";

                // Hero art: the wide picture at the top of the game's library
                // page, without the logo. Fits the Open Tray tile best.
                QDirIterator hero(root + "/appcache/librarycache/" + id,
                                  { "library_hero.jpg" }, QDir::Files,
                                  QDirIterator::Subdirectories);
                if (hero.hasNext())
                    game.hero = QUrl::fromLocalFile(hero.next()).toString();
                else
                    game.hero = "https://cdn.cloudflare.steamstatic.com/steam/apps/"
                                + id + "/library_hero.jpg";

                games << game;
            }
        }
    }
    return games;
}

QList<Game> GameLibrary::scanHeroic()
{
    // Normal install and the Flatpak version
    const QString home = QDir::homePath();
    const QStringList roots = {
        home + "/.config/heroic",
        home + "/.var/app/com.heroicgameslauncher.hgl/config/heroic",
    };

    // Heroic keeps one cached library per store: file name + the key holding the list
    struct Store { QString file; QString key; };
    const QList<Store> stores = {
        { "/store_cache/legendary_library.json", "library" },   // Epic
        { "/store_cache/gog_library.json", "games" },           // GOG
        { "/store_cache/nile_library.json", "library" },        // Amazon
        { "/sideload_apps/library.json", "games" },             // added by hand
    };

    QList<Game> games;
    for (const QString &root : roots) {
        for (const Store &store : stores) {
            const QJsonArray list = readJson(root + store.file).object().value(store.key).toArray();

            for (const QJsonValue &value : list) {
                const QJsonObject info = value.toObject();
                if (!info.value("is_installed").toBool())
                    continue;
                if (info.value("install").toObject().value("is_dlc").toBool())
                    continue;

                const QString appName = info.value("app_name").toString();
                const QString runner = info.value("runner").toString();

                Game game;
                game.name = info.value("title").toString();
                game.source = "Heroic";
                // gui=false: start the game without showing Heroic's own window
                game.command = "xdg-open heroic://launch?appName="
                               + QString::fromUtf8(QUrl::toPercentEncoding(appName))
                               + "&runner=" + runner + "&gui=false";
                game.cover = info.value("art_square").toString().replace("{ext}", "jpg");
                game.banner = info.value("art_cover").toString().replace("{ext}", "jpg");

                if (!game.name.isEmpty() && !appName.isEmpty())
                    games << game;
            }
        }
    }
    return games;
}

QList<Game> GameLibrary::scanFaugus()
{
    // Current location, the older one, and the Flatpak version
    const QString home = QDir::homePath();
    struct Install { QString dataDir; QString launch; };
    const QList<Install> installs = {
        { home + "/.local/share/faugus-launcher", "faugus-launcher" },
        { home + "/.config/faugus-launcher", "faugus-launcher" },
        { home + "/.var/app/io.github.Faugus.faugus-launcher/data/faugus-launcher",
         "flatpak run io.github.Faugus.faugus-launcher" },
        };

    QList<Game> games;
    QStringList seenIds;
    for (const Install &install : installs) {
        const QJsonArray list = readJson(install.dataDir + "/games.json").array();

        for (const QJsonValue &value : list) {
            const QJsonObject info = value.toObject();
            const QString id = info.value("gameid").toString();
            // Skip hidden games, and Steam games Faugus only links to (the Steam scan has them)
            if (id.isEmpty() || seenIds.contains(id) || info.value("hidden").toBool()
                || info.value("runner").toString() == "Steam")
                continue;
            seenIds << id;

            Game game;
            game.name = info.value("title").toString();
            if (game.name.isEmpty())
                game.name = id;
            game.source = "Faugus";
            game.command = install.launch + " --game " + id;

            const QString exe = expandPath(info.value("path").toString());
            if (!exe.isEmpty() && QFileInfo(exe).absoluteDir().exists())
                game.folder = QFileInfo(exe).absolutePath();

            const QString cover = install.dataDir + "/covers/" + id + ".png";
            if (QFile::exists(cover))
                game.cover = QUrl::fromLocalFile(cover).toString();

            const QString banner = install.dataDir + "/banners/" + id + ".png";
            if (QFile::exists(banner))
                game.banner = QUrl::fromLocalFile(banner).toString();

            games << game;
        }
    }
    return games;
}