# _Mario & Luigi_ (1994, 2001) by Mike Wiering: original Pascal sources.

This is the source code of [Mario & Luigi](https://wieringsoftware.nl/mario/)
game, the homebrew indie game from 1994. It was made for 16-bit DOS using Turbo
Pascal 7.x, without any 32-bit extenders.

The source comes straight from [MARIOSRC.ZIP](https://wieringsoftware.nl/mario/MARIOSRC.ZIP) archive and is NOT modified in any way on `legacy` branch.

The only changes are made in directory structure, as original ZIP file had every
file in root directory, probably limited by early archive packers.

Additionally, there's a `build.msdos.sh` script which uses FreePascal i8086/msdos compiler from trunk. It expects `$FPC_LARGE` environment variable to point on the path of your cross-compiler. [There are binary snapshots for Win32 and Linux, so don't worry](https://downloads.freepascal.org/fpc/snapshot/trunk/i8086-msdos/).

The game builds properly, but *does not run* currently due to sublte differences between Turbo Pascal 7.x and 16-bit FreePascal target for DOS. We are aware of that and we'll fix this in the future,

[You can check the FPC forums thread](https://forum.lazarus.freepascal.org/index.php/topic,71748.0.html) and let us know if you have any valuable information.

## LEGAL DISCLAIMER

This repository contains the original source code for the 1994 MS-DOS game "Mario & Luigi", created by Mike Wiering. The purpose of this repository is purely for **educational and historical preservation purposes**. It aims to ensure that this piece of fan-game history can be studied and compiled on modern systems.

* The characters "Mario", "Luigi", and all related names, images, and concepts are the registered trademarks and copyright of **Nintendo Co., Ltd.** This project is **not affiliated with, authorized, or endorsed by Nintendo** in any way.
* This project is strictly non-commercial. It is provided for free, and no profit is being made from its existence or distribution. Do not attempt to sell or commercialize this software.
* The original game and its source code were created by Mike Wiering in 1994. All credit for the original code goes to its author. You can find the original source at [wieringsoftware.nl](https://wieringsoftware.nl/mario/).
* The software is provided "as-is", without warranty of any kind. Use at your own risk.
