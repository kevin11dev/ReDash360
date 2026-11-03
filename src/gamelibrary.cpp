#include "gamelibrary.h"

#include <QDir>
#include <QDirIterator>
#include <QFile>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QRegularExpression>
#include <QUrl>

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
        {"hero", game.hero}
    };
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

    std::sort(games.begin(), games.end(), [](const Game &a, const Game &b) {
        return a.name.compare(b.name, Qt::CaseInsensitive) < 0;
    });

    beginResetModel();      // tell views the whole list is about to change
    m_games = games;
    endResetModel();
    emit countChanged();
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