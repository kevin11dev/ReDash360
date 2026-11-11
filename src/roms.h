#pragma once

#include "gamelibrary.h"
#include <QUrl>

// Your ROMs, each one played by an emulator you have. They go in a folder per
// console under ~/ROMs (EmuDeck's ~/Emulation/roms and RetroDECK's
// ~/retrodeck/roms work too), named like ES-DE's: ~/ROMs/snes, ~/ROMs/ps2, ...
// A console's own emulator is used when it's installed (native or Flatpak),
// otherwise RetroArch with one of the console's cores. ROMs nothing installed
// can play aren't listed. extraRoots: more folders like ~/ROMs (from Settings),
// or a console's own folder ("/mnt/games/ps2").
QList<Game> scanRoms(const QStringList &extraRoots = {});

// libretro's box art: a list of each console's covers is kept in
// ~/.cache/ReDash360/ReDash360/covers, so a ROM gets the cover closest to its
// name. These are the consoles in `games` whose list is missing or a month
// old, by libretro's name for them ("Sony - PlayStation 2")...
QStringList coverListsToFetch(const QList<Game> &games);
// ...where to download one (a folder page on thumbnails.libretro.com), and
// keeping the cover names on it. false if it isn't a list of covers.
QUrl coverListUrl(const QString &console);
bool saveCoverList(const QString &console, const QByteArray &page);