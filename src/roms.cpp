#include "roms.h"

#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QRegularExpression>
#include <QSet>
#include <QStandardPaths>
#include <QUrl>

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

// libretro's box art collection names files like the ROM, with &*/:`<>?\|" made _
QString thumbnail(const System &system, const QString &baseName, const QString &kind)
{
    if (system.thumbnails.isEmpty())
        return {};
    QString file = baseName;
    static const QRegularExpression unsafe("[&*/:`<>?\\\\|\"]");
    file.replace(unsafe, "_");
    return "https://thumbnails.libretro.com/" + QString::fromUtf8(QUrl::toPercentEncoding(system.thumbnails))
           + "/" + kind + "/" + QString::fromUtf8(QUrl::toPercentEncoding(file)) + ".png";
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
            game.cover = localPicture(target, game.system, baseName, "covers");
            if (game.cover.isEmpty())
                game.cover = thumbnail(system, baseName, "Named_Boxarts");
            game.hero = localPicture(target, game.system, baseName, "screenshots");
            if (game.hero.isEmpty())
                game.hero = thumbnail(system, baseName, "Named_Snaps");
            game.banner = thumbnail(system, baseName, "Named_Titles");
            games << game;
        }
    }
    return games;
}