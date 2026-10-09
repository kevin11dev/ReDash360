#include "achievements.h"

#include <QDateTime>
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QHash>
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

// A name or description: one text per language, or just one text
QString english(const QVariant &value)
{
    const QVariantMap languages = value.toMap();
    return languages.isEmpty() ? value.toString() : languages.value("english").toString();
}

// Your installed Steam games: one steamapps/appmanifest_<game>.acf each, in
// Steam's own folder and every other library listed in libraryfolders.vdf
QSet<QString> installedGames(const QString &steamRoot)
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
    QSet<QString> games;
    for (const QString &library : std::as_const(libraries)) {
        const QStringList manifests = QDir(library + "/steamapps").entryList({ "appmanifest_*.acf" }, QDir::Files);
        for (const QString &manifest : manifests) {
            const QRegularExpressionMatch match = manifestName.match(manifest);
            if (match.hasMatch())
                games.insert(match.captured(1));
        }
    }
    return games;
}

struct Unlock
{
    qint64 time;
    QString folder;                             // the appcache/stats folder it came from
    QString appId;
    QString stat;                               // which stat holds the achievement...
    QString bit;                                // ...and which bit of it
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
    QSet<QString> seenFolders;
    for (const QString &root : roots) {
        const QString folder = QFileInfo(root + "/appcache/stats").canonicalFilePath();
        if (folder.isEmpty() || seenFolders.contains(folder))
            continue;                           // missing, or the same folder via a symlink
        seenFolders.insert(folder);

        // Only games you have installed, so the count doesn't jump around when
        // Steam caches files for games you've just looked at
        const QSet<QString> installed = installedGames(root);

        const QStringList files = QDir(folder).entryList({ "UserGameStats_*.bin" }, QDir::Files);
        for (const QString &fileName : files) {
            const QRegularExpressionMatch match = statsName.match(fileName);
            if (!match.hasMatch())
                continue;
            const QString appId = match.captured(1);
            if (!installed.contains(appId))
                continue;
            const QVariantMap cache = readFile(folder + "/" + fileName).value("cache").toMap();
            for (auto stat = cache.cbegin(); stat != cache.cend(); ++stat) {
                const QVariantMap times = stat.value().toMap().value("AchievementTimes").toMap();
                for (auto bit = times.cbegin(); bit != times.cend(); ++bit)
                    unlocks.append({ bit.value().toLongLong(), folder, appId, stat.key(), bit.key() });
            }
        }
    }

    std::sort(unlocks.begin(), unlocks.end(), [](const Unlock &a, const Unlock &b) {
        return a.time > b.time;                 // newest first
    });

    // UserGameStatsSchema_<game>.bin: every achievement's name, description
    // and icon, under <game> -> stats -> <stat> -> bits -> <bit> -> display
    QHash<QString, QVariantMap> schemas;
    QVariantList recent;
    for (const Unlock &unlock : std::as_const(unlocks)) {
        if (recent.size() == RecentCount)
            break;
        if (!schemas.contains(unlock.appId)) {
            const QVariantMap file = readFile(unlock.folder + "/UserGameStatsSchema_" + unlock.appId + ".bin");
            schemas.insert(unlock.appId, file.value(unlock.appId).toMap());
        }
        const QVariantMap schema = schemas.value(unlock.appId);
        const QVariantMap display = schema.value("stats").toMap().value(unlock.stat).toMap()
                                        .value("bits").toMap().value(unlock.bit).toMap()
                                        .value("display").toMap();
        if (display.isEmpty())
            continue;                           // not in the schema: skip it

        const QString icon = display.value("icon").toString();
        recent << QVariantMap{
            { "name", english(display.value("name")) },
            { "description", english(display.value("desc")) },
            { "icon", icon.isEmpty() ? QString()
                                    : "https://cdn.cloudflare.steamstatic.com/steamcommunity/public/images/apps/"
                                          + unlock.appId + "/" + icon },
            { "appId", unlock.appId },
            { "time", QDateTime::fromSecsSinceEpoch(unlock.time) },
            };
    }

    m_recent = recent;
    m_total = unlocks.size();
    emit changed();
}