#include "gamelibrary.h"

#include <QDir>
#include <QDirIterator>
#include <QFile>
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
        };
}

void GameLibrary::refresh()
{
    QList<Game> games = scanSteam();
    // later: games += scanHeroic(); games += scanFaugus();

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
        const QRegularExpression pathRe("\"path\"\\s+\"([^\"]+)\"");
        for (auto it = pathRe.globalMatch(folders); it.hasNext();)
            libraries << it.next().captured(1);

        for (const QString &library : libraries) {
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

                games << game;
            }
        }
    }
    return games;
}