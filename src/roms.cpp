#include "roms.h"

#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QRegularExpression>
#include <QSet>
#include <QStandardPaths>
#include <QUrl>
#include <QDateTime>
#include <QSaveFile>

namespace {

// An emulator made for one or a few consoles. args has {rom} where the game
// goes (RetroArch's also {core}); it may hold options before and after it.
struct Emulator
{
    QString key;
    QStringList programs;   // its command, as installed natively (any of these)
    QString flatpak;        // its Flathub ID ("" if it has none)
    QString args;
};

const QList<Emulator> &emulators()
{
    static const QList<Emulator> list = {
        { "retroarch", { "retroarch" }, "org.libretro.RetroArch", "-f -L {core} {rom}" },
        { "pcsx2", { "pcsx2-qt", "pcsx2" }, "net.pcsx2.PCSX2", "-nogui -fullscreen -- {rom}" },
        { "rpcs3", { "rpcs3" }, "net.rpcs3.RPCS3", "--no-gui {rom}" },
        { "ppsspp", { "PPSSPPSDL", "ppsspp", "PPSSPPQt" }, "org.ppsspp.PPSSPP", "--fullscreen {rom}" },
        { "xemu", { "xemu" }, "app.xemu.xemu", "-full-screen -dvd_path {rom}" },
        { "xenia", { "xenia_canary", "xenia-canary", "xenia" }, "", "--fullscreen {rom}" },
        { "dolphin", { "dolphin-emu" }, "org.DolphinEmu.dolphin-emu", "-b -e {rom}" },
        { "cemu", { "cemu", "Cemu" }, "info.cemu.Cemu", "-f -g {rom}" },
        { "melonds", { "melonDS" }, "net.kuribo64.melonDS", "-f {rom}" },
        { "mgba", { "mgba-qt", "mgba" }, "io.mgba.mGBA", "-f {rom}" },
        { "dosbox", { "dosbox" }, "io.github.dosbox-staging", "--fullscreen {rom}" },
        { "scummvm", { "scummvm" }, "org.scummvm.ScummVM", "-f --path={rom} --auto-detect" },
        };
    return list;
}

// A console: its folder names, the name on its games' banner, the files that
// are its games, its own emulators and RetroArch's cores for it (best first),
// and its folder in libretro's box art collection.
struct System
{
    QStringList folders;
    QString label;
    QStringList extensions;     // "dir": a game is a folder
    QStringList standalone;
    QStringList cores;
    QString thumbnails;
};

const QList<System> &systems()
{
    static const QStringList cart = { "zip", "7z" };    // cartridge games also come zipped
    static const QList<System> list = {
        { { "nes", "famicom" }, "NES", QStringList{ "nes", "fds", "unf", "unif" } + cart, {},
         { "mesen", "nestopia", "fceumm" }, "Nintendo - Nintendo Entertainment System" },
        { { "snes", "sfc", "superfamicom" }, "SNES", QStringList{ "sfc", "smc", "fig", "swc", "bs" } + cart, {},
         { "snes9x", "bsnes" }, "Nintendo - Super Nintendo Entertainment System" },
        { { "n64" }, "N64", QStringList{ "n64", "z64", "v64" } + cart, {},
         { "mupen64plus_next", "parallel_n64" }, "Nintendo - Nintendo 64" },
        { { "gb" }, "Game Boy", QStringList{ "gb" } + cart, { "mgba" },
         { "gambatte", "sameboy", "mgba" }, "Nintendo - Game Boy" },
        { { "gbc" }, "Game Boy Color", QStringList{ "gbc" } + cart, { "mgba" },
         { "gambatte", "sameboy", "mgba" }, "Nintendo - Game Boy Color" },
        { { "gba" }, "GBA", QStringList{ "gba" } + cart, { "mgba" },
         { "mgba", "vbam", "gpsp" }, "Nintendo - Game Boy Advance" },
        { { "nds" }, "DS", QStringList{ "nds" } + cart, { "melonds" },
         { "melondsds", "melonds", "desmume" }, "Nintendo - Nintendo DS" },
        { { "gc", "gamecube", "ngc" }, "GameCube", { "iso", "gcm", "gcz", "rvz", "ciso" }, { "dolphin" },
         { "dolphin" }, "Nintendo - GameCube" },
        { { "wii" }, "Wii", { "iso", "wbfs", "rvz", "gcz", "ciso", "wad" }, { "dolphin" },
         { "dolphin" }, "Nintendo - Wii" },
        { { "wiiu" }, "Wii U", { "wua", "wud", "wux", "rpx" }, { "cemu" }, {}, "" },
        { { "genesis", "megadrive" }, "Genesis", QStringList{ "md", "gen", "smd", "bin" } + cart, {},
         { "genesis_plus_gx", "picodrive" }, "Sega - Mega Drive - Genesis" },
        { { "mastersystem", "sms" }, "Master System", QStringList{ "sms" } + cart, {},
         { "genesis_plus_gx", "picodrive" }, "Sega - Master System - Mark III" },
        { { "gamegear", "gg" }, "Game Gear", QStringList{ "gg" } + cart, {},
         { "genesis_plus_gx" }, "Sega - Game Gear" },
        { { "segacd", "megacd" }, "Sega CD", { "chd", "cue", "m3u" }, {},
         { "genesis_plus_gx", "picodrive" }, "Sega - Mega-CD - Sega CD" },
        { { "saturn" }, "Saturn", { "chd", "cue", "m3u" }, {},
         { "mednafen_saturn", "yabasanshiro", "kronos" }, "Sega - Saturn" },
        { { "dreamcast", "dc" }, "Dreamcast", { "chd", "cdi", "gdi", "m3u" }, {},
         { "flycast" }, "Sega - Dreamcast" },
        { { "psx", "ps1", "playstation" }, "PlayStation", { "chd", "cue", "pbp", "m3u" }, {},
         { "swanstation", "mednafen_psx_hw", "mednafen_psx", "pcsx_rearmed" }, "Sony - PlayStation" },
        { { "ps2" }, "PS2", { "iso", "chd", "cso", "zso", "gz" }, { "pcsx2" },
         { "pcsx2" }, "Sony - PlayStation 2" },
        { { "ps3" }, "PS3", { "dir" }, { "rpcs3" }, {}, "Sony - PlayStation 3" },
        { { "psp" }, "PSP", { "iso", "cso", "pbp", "chd" }, { "ppsspp" },
         { "ppsspp" }, "Sony - PlayStation Portable" },
        { { "xbox" }, "Xbox", { "iso", "xiso" }, { "xemu" }, {}, "Microsoft - Xbox" },
        { { "xbox360" }, "Xbox 360", { "iso", "xex", "zar" }, { "xenia" }, {}, "Microsoft - Xbox 360" },
        { { "pcengine", "tg16", "turbografx16" }, "PC Engine", QStringList{ "pce" } + cart, {},
         { "mednafen_pce_fast", "mednafen_pce" }, "NEC - PC Engine - TurboGrafx 16" },
        { { "atari2600" }, "Atari 2600", QStringList{ "a26", "bin" } + cart, {},
         { "stella", "stella2014" }, "Atari - 2600" },
        { { "dos", "pc" }, "DOS", { "exe", "com", "bat" }, { "dosbox" }, { "dosbox_pure" }, "DOS" },
        { { "scummvm" }, "ScummVM", { "dir" }, { "scummvm" }, {}, "" },
        };
    return list;
}

// Where an emulator is installed, native first: each its path, or "flatpak:<ID>"
QStringList installs(const Emulator &emulator)
{
    QStringList found;
    for (const QString &program : emulator.programs) {
        const QString path = QStandardPaths::findExecutable(program);
        if (!path.isEmpty()) {
            found << path;
            break;
        }
    }
    if (!emulator.flatpak.isEmpty()) {
        for (const QString &install : { QDir::homePath() + "/.local/share/flatpak/app/" + emulator.flatpak,
                                       "/var/lib/flatpak/app/" + emulator.flatpak }) {
            if (QDir(install).exists()) {
                found << "flatpak:" + emulator.flatpak;
                break;
            }
        }
    }
    return found;
}

// A file name or path as one argument for Launcher.run(), quotes and all
QString quoted(QString text)
{
    text.replace("\"", "\"\"\"");
    return "\"" + text + "\"";
}

// RetroArch's core for one of these, in the folders that RetroArch (native or Flatpak) loads cores from
QString findCore(const QStringList &cores, bool flatpak)
{
    const QString home = QDir::homePath();
    const QStringList folders = flatpak
                                    ? QStringList{ home + "/.var/app/org.libretro.RetroArch/config/retroarch/cores" }
                                    : QStringList{ home + "/.config/retroarch/cores", "/usr/lib/libretro", "/usr/lib64/libretro",
                                                  "/usr/lib/x86_64-linux-gnu/libretro", "/usr/local/lib/libretro" };
    for (const QString &core : cores) {
        for (const QString &folder : folders) {
            const QString file = folder + "/" + core + "_libretro.so";
            if (QFile::exists(file))
                return file;
        }
    }
    return {};
}

// How to play one of this console's games: the command with {rom} still in it, or ""
QString commandFor(const System &system, const QString &romFolder)
{
    const auto byKey = [](const QString &key) {
        for (const Emulator &emulator : emulators()) {
            if (emulator.key == key)
                return emulator;
        }
        return Emulator{};
    };
    const auto start = [&](const QString &where) {
        if (!where.startsWith("flatpak:"))
            return quoted(where);
        // A Flatpak can't see every folder: let it into the one with the games
        return "flatpak run --filesystem=" + quoted(romFolder) + " " + where.mid(8);
    };

    for (const QString &key : system.standalone) {
        const Emulator emulator = byKey(key);
        const QStringList where = installs(emulator);
        if (!where.isEmpty())
            return start(where.first()) + " " + emulator.args;
    }
    if (!system.cores.isEmpty()) {
        const Emulator retroarch = byKey("retroarch");
        for (const QString &where : installs(retroarch)) {      // the first RetroArch that has a core for it
            const QString core = findCore(system.cores, where.startsWith("flatpak:"));
            if (!core.isEmpty())
                return start(where) + " " + QString(retroarch.args).replace("{core}", quoted(core));
        }
    }
    return {};
}

// "Super Mario World (USA) [!]" -> "Super Mario World"
QString displayName(const QString &baseName)
{
    static const QRegularExpression tags("\\s*[\\(\\[][^\\)\\]]*[\\)\\]]");
    QString name = baseName;
    name.remove(tags);
    name.replace('_', ' ');
    name = name.simplified();
    return name.isEmpty() ? baseName : name;
}

// ---- libretro's box art ----------------------------------------------------
// Its covers are named like the No-Intro and Redump sets: "Pokemon - Emerald
// Version (USA, Europe)". A ROM named a bit differently ("Pokemon Emerald")
// gets the closest one, from the console's list of covers.

QString coverListPath(const QString &console)
{
    return QStandardPaths::writableLocation(QStandardPaths::CacheLocation) + "/covers/" + console + ".txt";
}

// "Legend of Zelda, The - A Link to the Past (USA)" and "the legend of zelda a
// link to the past" -> "legendofzeldaalinktothepast": the title without its
// tags, "The", accents, punctuation or capitals
QString titleKey(QString name)
{
    static const QRegularExpression tags("[\\(\\[][^\\)\\]]*[\\)\\]]");
    static const QRegularExpression the("^the\\s+|,\\s*the\\b");
    static const QRegularExpression other("[^a-z0-9]");
    name.remove(tags);
    name = name.normalized(QString::NormalizationForm_KD).toLower().trimmed();
    name.replace('&', "and");
    name.remove(the);
    name.remove(other);
    return name;
}

// A name's tags in (brackets), in small letters: "usa", "en,fr,de", "disc 2"
QStringList tagsOf(const QString &name)
{
    static const QRegularExpression tag("\\(([^\\)]*)\\)");
    QStringList tags;
    for (auto it = tag.globalMatch(name); it.hasNext();)
        tags << it.next().captured(1).toLower();
    return tags;
}

// The regions a cover is picked for, best first when the ROM doesn't say
const QStringList &preferredRegions()
{
    static const QStringList regions = { "usa", "world", "europe", "japan" };
    return regions;
}

// GoodTools' region codes: (U), (E), (J), (W), (JU) ...
bool isGoodToolsRegion(const QString &tag)
{
    static const QRegularExpression codes("^[uejw]+$");
    return codes.match(tag).hasMatch();
}

// "usa", "europe, australia", "ju"
bool isRegionTag(const QString &tag)
{
    static const QSet<QString> places = { "usa", "world", "europe", "japan", "asia", "australia", "canada", "korea",
                                         "china", "taiwan", "hong kong", "brazil", "france", "germany", "spain",
                                         "italy", "uk", "netherlands", "sweden", "scandinavia", "russia", "latin america" };
    if (isGoodToolsRegion(tag))
        return true;
    for (const QString &part : tag.split(',')) {
        if (!places.contains(part.trimmed()))
            return false;
    }
    return true;
}

// Which of USA, World, Europe and Japan these tags are for
QSet<QString> regionsOf(const QStringList &tags)
{
    static const QHash<QChar, QString> codes = { { 'u', "usa" }, { 'e', "europe" }, { 'j', "japan" }, { 'w', "world" } };
    QSet<QString> regions;
    for (const QString &tag : tags) {
        if (isGoodToolsRegion(tag)) {
            for (const QChar code : tag)
                regions << codes.value(code);
        } else if (isRegionTag(tag)) {
            for (const QString &region : preferredRegions()) {
                if (tag.contains(region))
                    regions << region;
            }
        }
    }
    return regions;
}

// How well a cover suits a ROM with these tags: its region above all, the
// same disc or revision, and not a beta, demo or special edition
int coverScore(const QString &cover, const QStringList &romTags)
{
    static const QRegularExpression unwanted("\\b(beta|proto|demo|sample|kiosk|promo|preview|pirate|unl|hack|aftermarket|taikenban|trial)\\b");
    static const QRegularExpression plain("^([a-z]{2}(,[a-z]{2})*|rev \\w+|v\\d[\\d.]*\\w*|disc \\d+)$");   // languages, revisions, discs
    const QStringList tags = tagsOf(cover);
    int score = -int(tags.size());
    for (const QString &tag : tags) {
        if (isRegionTag(tag))
            continue;
        if (romTags.contains(tag))
            score += 20;                        // the same disc, revision or edition
        else if (unwanted.match(tag).hasMatch())
            score -= 100;
        else if (!plain.match(tag).hasMatch())
            score -= 10;                        // a special edition the ROM isn't
    }
    const QSet<QString> regions = regionsOf(tags);
    score += 50 * int((regions & regionsOf(romTags)).size());
    for (int i = 0; i < preferredRegions().size(); ++i) {
        if (regions.contains(preferredRegions().at(i))) {
            score += 8 - 2 * i;
            break;
        }
    }
    return score;
}

// A console's covers, by title. Read from its list again when the list changes.
struct CoverList
{
    QDateTime saved;                            // when the list was saved
    QSet<QString> names;
    QHash<QString, QStringList> byTitle;        // titleKey() -> covers, in the list's order
};

const CoverList *coverList(const QString &console)
{
    static QHash<QString, CoverList> lists;
    const QFileInfo file(coverListPath(console));
    if (!file.exists())
        return nullptr;
    CoverList &list = lists[console];
    if (list.saved != file.lastModified()) {
        QFile names(file.filePath());
        if (!names.open(QIODevice::ReadOnly))
            return nullptr;
        list = CoverList{ file.lastModified(), {}, {} };
        for (const QByteArray &line : names.readAll().split('\n')) {
            const QString name = QString::fromUtf8(line);
            if (name.isEmpty())
                continue;
            list.names << name;
            list.byTitle[titleKey(name)] << name;
        }
    }
    return &list;
}

// The name of libretro's cover for a ROM: its own name if there's one by that
// name, else the best one for the same title, or the closest longer title
// ("Pokemon Emerald" -> "Pokemon - Emerald Version"). "" if there's none.
// Until the console's list is downloaded, the ROM's own name.
QString coverName(const System &system, const QString &baseName)
{
    if (system.thumbnails.isEmpty())
        return {};
    static const QRegularExpression unsafe("[&*/:`<>?\\\\|\"]");      // made _ in libretro's names
    QString exact = baseName;
    exact.replace(unsafe, "_");
    const CoverList *list = coverList(system.thumbnails);
    if (!list || list->names.contains(exact))
        return exact;

    const QString title = titleKey(baseName);
    QStringList covers = list->byTitle.value(title);
    if (covers.isEmpty() && title.size() >= 6) {
        QString closest;
        for (auto it = list->byTitle.cbegin(); it != list->byTitle.cend(); ++it) {
            const QString &other = it.key();
            if (!other.startsWith(title) || other.size() - title.size() > 24)
                continue;
            if (closest.isEmpty() || other.size() < closest.size() || (other.size() == closest.size() && other < closest))
                closest = other;
        }
        covers = list->byTitle.value(closest);
    }

    const QStringList romTags = tagsOf(baseName);
    QString best;
    int bestScore = 0;
    for (const QString &cover : std::as_const(covers)) {
        const int score = coverScore(cover, romTags);
        if (best.isEmpty() || score > bestScore) {
            best = cover;
            bestScore = score;
        }
    }
    return best;
}

// One of libretro's pictures for a game, by the name coverName() found:
// kind is Named_Boxarts, Named_Snaps or Named_Titles
QString thumbnail(const System &system, const QString &name, const QString &kind)
{
    if (system.thumbnails.isEmpty() || name.isEmpty())
        return {};
    return "https://thumbnails.libretro.com/" + QString::fromUtf8(QUrl::toPercentEncoding(system.thumbnails))
           + "/" + kind + "/" + QString::fromUtf8(QUrl::toPercentEncoding(name)) + ".png";
}

// A picture you already have for a game: next to the ROM, or where ES-DE and EmuDeck keep theirs
QString localPicture(const QString &romPath, const QString &folder, const QString &baseName, const QString &kind)
{
    const QString home = QDir::homePath();
    const QFileInfo rom(romPath);
    QStringList candidates;
    if (kind == "covers")
        candidates << rom.absolutePath() + "/" + baseName;
    for (const QString &media : { home + "/ES-DE/downloaded_media", home + "/.emulationstation/downloaded_media",
                                 home + "/Emulation/tools/downloaded_media" })
        candidates << media + "/" + folder + "/" + kind + "/" + baseName;
    for (const QString &candidate : std::as_const(candidates)) {
        for (const QString &ext : { ".png", ".jpg", ".jpeg", ".webp" }) {
            if (QFile::exists(candidate + ext))
                return QUrl::fromLocalFile(candidate + ext).toString();
        }
    }
    return {};
}

// PS3 games are folders: their EBOOT.BIN is what RPCS3 starts
QString ps3Boot(const QString &folder)
{
    for (const QString &eboot : { folder + "/PS3_GAME/USRDIR/EBOOT.BIN", folder + "/USRDIR/EBOOT.BIN" }) {
        if (QFile::exists(eboot))
            return eboot;
    }
    return {};
}

}

QList<Game> scanRoms(const QStringList &extraRoots)
{
    const QString home = QDir::homePath();
    const QStringList roots = QStringList{
                                  home + "/ROMs", home + "/Roms", home + "/roms",
                                  home + "/Emulation/roms",               // EmuDeck
                                  home + "/retrodeck/roms",               // RetroDECK
                              } + extraRoots;

    // Every console folder to look in: those inside each root, or the root
    // itself when it's named like a console ("ps2")
    QList<QPair<const System *, QString>> places;
    for (const QString &root : roots) {
        if (!QDir(root).exists())
            continue;
        const QString rootName = QDir(root).dirName().toLower();
        const System *itself = nullptr;
        for (const System &system : systems()) {
            if (system.folders.contains(rootName))
                itself = &system;
        }
        if (itself) {
            places << qMakePair(itself, root);
            continue;
        }
        for (const System &system : systems()) {
            for (const QString &folderName : system.folders)
                places << qMakePair(&system, root + "/" + folderName);
        }
    }

    QList<Game> games;
    QSet<QString> seen;
    for (const auto &place : std::as_const(places)) {
        const System &system = *place.first;
        const QString folder = place.second;
        const QDir dir(folder);
        if (!dir.exists() || seen.contains(QFileInfo(folder).canonicalFilePath()))
            continue;
        seen.insert(QFileInfo(folder).canonicalFilePath());

        const QString command = commandFor(system, folder);
        if (command.isEmpty())
            continue;                   // nothing installed plays these

        const bool folders = system.extensions.contains("dir");
        const QFileInfoList entries = folders
                                          ? dir.entryInfoList(QDir::Dirs | QDir::NoDotAndDotDot, QDir::Name)
                                          : dir.entryInfoList(QDir::Files, QDir::Name);

        // Discs a .m3u playlist lists are played through it, not one by one
        QSet<QString> inPlaylists;
        for (const QFileInfo &entry : entries) {
            if (entry.suffix().compare("m3u", Qt::CaseInsensitive) != 0)
                continue;
            QFile playlist(entry.absoluteFilePath());
            if (playlist.open(QIODevice::ReadOnly | QIODevice::Text)) {
                for (const QString &line : QString::fromUtf8(playlist.readAll()).split('\n')) {
                    const QString disc = line.trimmed();
                    if (!disc.isEmpty() && !disc.startsWith('#'))
                        inPlaylists.insert(QFileInfo(dir, disc).absoluteFilePath());
                }
            }
        }

        for (const QFileInfo &entry : entries) {
            if (entry.fileName().startsWith('.') || inPlaylists.contains(entry.absoluteFilePath()))
                continue;
            QString target = entry.absoluteFilePath();
            if (folders) {
                if (system.label == "PS3") {
                    target = ps3Boot(target);
                    if (target.isEmpty())
                        continue;
                }
            } else if (!system.extensions.contains(entry.suffix().toLower())) {
                continue;
            }

            const QString baseName = folders ? entry.fileName() : entry.completeBaseName();
            Game game;
            game.name = displayName(baseName);
            game.source = system.label;
            game.system = system.folders.first();
            game.direct = true;
            game.command = QString(command).replace("{rom}", quoted(target));
            const QString cover = coverName(system, baseName);
            game.cover = localPicture(target, game.system, baseName, "covers");
            if (game.cover.isEmpty())
                game.cover = thumbnail(system, cover, "Named_Boxarts");
            game.hero = localPicture(target, game.system, baseName, "screenshots");
            if (game.hero.isEmpty())
                game.hero = thumbnail(system, cover, "Named_Snaps");
            game.banner = thumbnail(system, cover, "Named_Titles");
            games << game;
        }
    }
    return games;
}


QStringList coverListsToFetch(const QList<Game> &games)
{
    QStringList consoles;
    for (const Game &game : games) {
        for (const System &system : systems()) {
            if (game.system.isEmpty() || system.folders.first() != game.system || system.thumbnails.isEmpty()
                || consoles.contains(system.thumbnails))
                continue;
            const QFileInfo list(coverListPath(system.thumbnails));
            if (!list.exists() || list.lastModified().daysTo(QDateTime::currentDateTime()) > 30)
                consoles << system.thumbnails;
        }
    }
    return consoles;
}

QUrl coverListUrl(const QString &console)
{
    return QUrl("https://thumbnails.libretro.com/" + QString::fromUtf8(QUrl::toPercentEncoding(console)) + "/Named_Boxarts/");
}

bool saveCoverList(const QString &console, const QByteArray &page)
{
    // The folder page links each cover: <a href="Patapon%20(USA).png">
    static const QRegularExpression link("href=\"([^\"?/][^\"]*)\\.png\"");
    QStringList names;
    for (auto it = link.globalMatch(QString::fromUtf8(page)); it.hasNext();)
        names << QUrl::fromPercentEncoding(it.next().captured(1).toUtf8());
    if (names.isEmpty())
        return false;

    QDir().mkpath(QFileInfo(coverListPath(console)).absolutePath());
    QSaveFile list(coverListPath(console));
    if (!list.open(QIODevice::WriteOnly))
        return false;
    list.write(names.join('\n').toUtf8());
    return list.commit();
}