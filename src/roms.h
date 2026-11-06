#pragma once

#include "gamelibrary.h"

// Your ROMs, each one played by an emulator you have. They go in a folder per
// console under ~/ROMs (EmuDeck's ~/Emulation/roms and RetroDECK's
// ~/retrodeck/roms work too), named like ES-DE's: ~/ROMs/snes, ~/ROMs/ps2, ...
// A console's own emulator is used when it's installed (native or Flatpak),
// otherwise RetroArch with one of the console's cores. ROMs nothing installed
// can play aren't listed. extraRoots: more folders like ~/ROMs (from Settings),
// or a console's own folder ("/mnt/games/ps2").
QList<Game> scanRoms(const QStringList &extraRoots = {});