#include "achievements.h"

#include <QDateTime>
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QRegularExpression>
#include <QSet>
#include <QtEndian>

#include <algorithm>

namespace {

constexpr int RecentCount = 9;

// Steam saves these files in its binary "KeyValues" format: a tree of named
// values. Each entry is one type byte, a name ending in a 0 byte, then the value:
//   0 = a group of more entries, 1 = text, 2 = 32-bit number,
//   3 = decimal number, 7 = 64-bit number; byte 8 ends the current group
QVariantMap readKeyValues(const QByteArray &data, int &pos)
{
    QVariantMap map;
    while (pos < data.size()) {
        const char type = data.at(pos++);
        if (type == 8)
            break;                              // end of this group

        const int nameEnd = data.indexOf('\0', pos);
        if (nameEnd < 0)
            break;
        const QString name = QString::fromUtf8(data.mid(pos, nameEnd - pos));
        pos = nameEnd + 1;

        if (type == 0) {
            map.insert(name, readKeyValues(data, pos));
        } else if (type == 1) {
            const int end = data.indexOf('\0', pos);
            if (end < 0)
                break;
            map.insert(name, QString::fromUtf8(data.mid(pos, end - pos)));
            pos = end + 1;
        } else if (type == 2 || type == 3 || type == 4 || type == 6) {
            if (pos + 4 > data.size())
                break;
            if (type == 2)                      // the only 4-byte kind we need
                map.insert(name, qFromLittleEndian<qint32>(data.constData() + pos));
            pos += 4;
        } else if (type == 7 || type == 10) {
            if (pos + 8 > data.size())
                break;
            map.insert(name, qFromLittleEndian<quint64>(data.constData() + pos));
            pos += 8;
        } else {
            break;                              // something we don't understand: stop here
        }
    }
    return map;
}

QVariantMap readFile(const QString &path)
{
    QFile file(path);
    if (!file.open(QIODevice::ReadOnly))
        return {};
    int pos = 0;
    return readKeyValues(file.readAll(), pos);
}

// UserGameStatsSchema_<game>.bin, next to the stats files: every achievement's
// name, description and icons, under <game> -> stats -> <stat> -> bits -> <bit>
QVariantMap readSchema(const QString &folder, const QString &appId)
{
    return readFile(folder + "/UserGameStatsSchema_" + appId + ".bin").value(appId).toMap();
}

// A name or description: one text per language, or just one text
QString english(const QVariant &value)
{
    const QVariantMap languages = value.toMap();
    return languages.isEmpty() ? value.toString() : languages.value("english").toString();
}

QString iconUrl(const QString &appId, const QString &file)
{
    if (file.isEmpty())
        return {};
    return "https://cdn.cloudflare.steamstatic.com/steamcommunity/public/images/apps/"
           + appId + "/" + file;
}

// Your installed Steam games, id -> name: one steamapps/appmanifest_<game>.acf
// each, in Steam's own folder and every other library in libraryfolders.vdf
QHash<QString, QString> installedGames(const QString &steamRoot)
{
    QStringList libraries = { steamRoot };
    QFile folders(steamRoot + "/steamapps/libraryfolders.vdf");
    if (folders.open(QIODevice::ReadOnly)) {
        static const QRegularExpression path("\"path\"\\s+\"([^\"]+)\"");
        QRegularExpressionMatchIterator it = path.globalMatch(QString::fromUtf8(folders.readAll()));
        while (it.hasNext())
            libraries << it.next().captured(1);
    }

    static const QRegularExpression manifestName("^appmanifest_(\\d+)\\.acf$");
    static const QRegularExpression gameName("\"name\"\\s+\"([^\"]*)\"");
    QHash<QString, QString> games;
    for (const QString &library : std::as_const(libraries)) {
        const QDir steamapps(library + "/steamapps");
        const QStringList manifests = steamapps.entryList({ "appmanifest_*.acf" }, QDir::Files);
        for (const QString &manifest : manifests) {
            const QRegularExpressionMatch match = manifestName.match(manifest);
            if (!match.hasMatch())
                continue;
            QFile file(steamapps.filePath(manifest));
            QString name;
            if (file.open(QIODevice::ReadOnly))
                name = gameName.match(QString::fromUtf8(file.readAll())).captured(1);
            games.insert(match.captured(1), name);
        }
    }
    return games;
}

struct Unlock
{
    qint64 time;
    QString appId;
    QString stat;                               // which stat holds the achievement...
    QString bit;                                // ...and which bit of it
};

struct Game
{
    QString name;
    QString folder;                             // its appcache/stats folder
    int unlocked = 0;
    qint64 last = 0;                            // newest unlock
};

} // namespace

Achievements::Achievements(QObject *parent)
    : QObject(parent)
{
    refresh();
}

void Achievements::refresh()
{
    // Normal install, the ~/.steam symlink, and the Flatpak version
    const QString home = QDir::homePath();
    const QStringList roots = {
        home + "/.local/share/Steam",
        home + "/.steam/steam",
        home + "/.var/app/com.valvesoftware.Steam/.local/share/Steam",
    };

    // UserGameStats_<your account>_<game>.bin: what you unlocked in that game,
    // with the time, under cache -> <stat> -> AchievementTimes -> <bit>
    static const QRegularExpression statsName("^UserGameStats_\\d+_(\\d+)\\.bin$");
    QList<Unlock> unlocks;
    QHash<QString, Game> games;
    m_statsFiles.clear();
    QSet<QString> seenFolders;
    for (const QString &root : roots) {
        const QString folder = QFileInfo(root + "/appcache/stats").canonicalFilePath();
        if (folder.isEmpty() || seenFolders.contains(folder))
            continue;                           // missing, or the same folder via a symlink
        seenFolders.insert(folder);

        // Only games you have installed, so the count doesn't jump around when
        // Steam caches files for games you've just looked at
        const QHash<QString, QString> installed = installedGames(root);

        const QStringList files = QDir(folder).entryList({ "UserGameStats_*.bin" }, QDir::Files);
        for (const QString &fileName : files) {
            const QRegularExpressionMatch match = statsName.match(fileName);
            if (!match.hasMatch())
                continue;
            const QString appId = match.captured(1);
            if (!installed.contains(appId))
                continue;

            Game &game = games[appId];
            game.name = installed.value(appId);
            game.folder = folder;
            m_statsFiles.insert(appId, folder + "/" + fileName);

            const QVariantMap cache = readFile(folder + "/" + fileName).value("cache").toMap();
            for (auto stat = cache.cbegin(); stat != cache.cend(); ++stat) {
                const QVariantMap times = stat.value().toMap().value("AchievementTimes").toMap();
                for (auto bit = times.cbegin(); bit != times.cend(); ++bit) {
                    const qint64 time = bit.value().toLongLong();
                    unlocks.append({ time, appId, stat.key(), bit.key() });
                    game.unlocked++;
                    game.last = std::max(game.last, time);
                }
            }
        }
    }

    std::sort(unlocks.begin(), unlocks.end(), [](const Unlock &a, const Unlock &b) {
        return a.time > b.time;                 // newest first
    });

    // Each game's list of achievements, for the names, icons and totals
    QHash<QString, QVariantMap> schemas;
    for (auto game = games.cbegin(); game != games.cend(); ++game)
        schemas.insert(game.key(), readSchema(game.value().folder, game.key()));

    // The newest 9
    QVariantList recent;
    for (const Unlock &unlock : std::as_const(unlocks)) {
        if (recent.size() == RecentCount)
            break;
        const QVariantMap display = schemas.value(unlock.appId).value("stats").toMap()
                                        .value(unlock.stat).toMap().value("bits").toMap()
                                        .value(unlock.bit).toMap().value("display").toMap();
        if (display.isEmpty())
            continue;                           // not in the schema: skip it

        recent << QVariantMap{
            { "name", english(display.value("name")) },
            { "description", english(display.value("desc")) },
            { "icon", iconUrl(unlock.appId, display.value("icon").toString()) },
            { "appId", unlock.appId },
            { "time", QDateTime::fromSecsSinceEpoch(unlock.time) },
            };
    }

    // Every game that has achievements, with how many you've got
    QList<QVariantMap> list;
    for (auto game = games.cbegin(); game != games.cend(); ++game) {
        const QVariantMap schema = schemas.value(game.key());
        int total = 0;
        const QVariantMap stats = schema.value("stats").toMap();
        for (const QVariant &stat : stats)
            total += stat.toMap().value("bits").toMap().size();
        if (total == 0)
            continue;

        QString name = game.value().name;
        if (name.isEmpty())
            name = schema.value("gamename").toString();
        list << QVariantMap{
            { "appId", game.key() },
            { "name", name },
            { "unlocked", game.value().unlocked },
            { "total", total },
            { "last", game.value().last ? QDateTime::fromSecsSinceEpoch(game.value().last) : QVariant() },
            };
    }
    std::sort(list.begin(), list.end(), [](const QVariantMap &a, const QVariantMap &b) {
        const qint64 ta = a.value("last").toDateTime().toSecsSinceEpoch();
        const qint64 tb = b.value("last").toDateTime().toSecsSinceEpoch();
        if (ta != tb)
            return ta > tb;                     // newest first...
        return a.value("name").toString().compare(b.value("name").toString(), Qt::CaseInsensitive) < 0;
    });                                         // ...then games with none, A to Z

    m_recent = recent;
    m_total = unlocks.size();
    m_games.clear();
    for (const QVariantMap &game : std::as_const(list))
        m_games << game;
    emit changed();
}

QVariantList Achievements::forGame(const QString &appId) const
{
    const QString statsFile = m_statsFiles.value(appId);
    if (statsFile.isEmpty())
        return {};

    const QVariantMap cache = readFile(statsFile).value("cache").toMap();
    const QVariantMap stats = readSchema(QFileInfo(statsFile).path(), appId).value("stats").toMap();

    struct Entry { QVariantMap map; qint64 time; int order; };
    QList<Entry> entries;
    for (auto stat = stats.cbegin(); stat != stats.cend(); ++stat) {
        const QVariantMap times = cache.value(stat.key()).toMap().value("AchievementTimes").toMap();
        const QVariantMap bits = stat.value().toMap().value("bits").toMap();
        for (auto bit = bits.cbegin(); bit != bits.cend(); ++bit) {
            const QVariantMap display = bit.value().toMap().value("display").toMap();
            const bool unlocked = times.contains(bit.key());
            const qint64 time = times.value(bit.key()).toLongLong();
            entries.append({ QVariantMap{
                                { "name", english(display.value("name")) },
                                { "description", english(display.value("desc")) },
                                { "icon", iconUrl(appId, display.value(unlocked ? "icon" : "icon_gray").toString()) },
                                { "unlocked", unlocked },
                                { "time", unlocked ? QDateTime::fromSecsSinceEpoch(time) : QVariant() },
                                { "hidden", display.value("hidden").toInt() == 1 },
                                },
                            unlocked ? time : 0,
                            stat.key().toInt() * 1000 + bit.key().toInt() });
        }
    }

    // Unlocked ones newest first, then the locked ones in the game's own order
    std::sort(entries.begin(), entries.end(), [](const Entry &a, const Entry &b) {
        if (a.time != b.time)
            return a.time > b.time;
        return a.order < b.order;
    });

    QVariantList result;
    for (const Entry &entry : std::as_const(entries))
        result << entry.map;
    return result;
}