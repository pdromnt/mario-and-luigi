# Legacy - Original DOS Source & Assets

This directory contains the original DOS source code and game assets for **Mario & Luigi** by Mike Wiering (1994), along with the Python conversion tools used to create the SDL2 port.

These files are preserved for reference. The playable SDL2 port lives in `../sdl2_port/`.

## Original Source Code

The `.PAS` files are the original Turbo Pascal source, targeting DOS with VGA Mode 13h and x86 inline assembly. They require Turbo Pascal 7.0 or Borland Pascal and a DOS environment (or DOSBox) to compile.

| File           | Description                                    |
|----------------|------------------------------------------------|
| `MARIO.PAS`    | Main program                                   |
| `VGA256.PAS`   | VGA graphics engine (Mode 13h, inline asm)     |
| `PLAY.PAS`     | Game loop                                      |
| `KEYBOARD.PAS` | INT 09h keyboard handler                       |
| `MUSIC.PAS`    | PC speaker music (ports $42/$43/$61)           |
| `BUFFERS.PAS`  | Game state, types, DOS timer                   |
| `PALETTES.PAS` | VGA palette management                         |
| `FIGURES.PAS`  | Tile/sprite initialization                     |
| `BACKGR.PAS`   | Background rendering                           |
| `PLAYERS.PAS`  | Player movement & rendering                    |
| `ENEMIES.PAS`  | Enemy AI & rendering                           |
| `TMPOBJ.PAS`   | Temporary objects (fireballs, particles)       |
| `BLOCKS.PAS`   | Breakable/bouncing blocks                      |
| `GLITTER.PAS`  | Sparkle effects                                |
| `STARS.PAS`    | Background star field                          |
| `STATUS.PAS`   | HUD status bar                                 |
| `TXT.PAS`      | Text rendering                                 |
| `WORLDS.PAS`   | World/level data (assembler `db`/`dw` blocks)  |
| `JOYSTICK.PAS` | Joystick input (port $201)                     |
| `CPU286.PAS`   | 286 CPU detection                              |

## Game Assets

- **`.$00` / `.$01` / `.$02`...** — Raw VGA planar sprite data (4-plane format)
- **`.000` / `.001` / `.002`...** — Sprite metadata
- **`*.BK`** — Background image data
- **`DEFAULT.PAL`** — VGA palette
- **`MPAL256`** — 256-color palette data
- **`DEMOKEYS.OBJ`** — Pre-recorded demo keystroke data (linked into the original executable)

## Utilities

| File          | Description                           |
|---------------|---------------------------------------|
| `BIN2PAS.EXE` | Converts binary files to Pascal typed constants (DOS) |
| `GRED.EXE`    | Game/sprite editor (DOS)              |

## Documentation

| File        | Description                     |
|-------------|---------------------------------|
| `README.TXT`| Original game readme            |
| `MARIO.TXT` | Game information                |
| `GRED.TXT`  | Sprite/level editor manual      |

## Conversion Tools (`tools/`)

These Python 3 scripts were used during the porting process to convert the original DOS-format data into Pascal typed constants for the SDL2 port.

| Script                 | Description                                                       |
|------------------------|-------------------------------------------------------------------|
| `convert_sprites.py`   | Converts VGA planar sprite files (`.$00`, `.000`) to linear byte-per-pixel `.inc` files |
| `extract_worlds.py`    | Extracts level/world data from assembler `db`/`dw` blocks in `WORLDS.PAS` to byte arrays |
| `extract_demokeys.py`  | Extracts demo keystroke data from `DEMOKEYS.OBJ` to a typed constant |
| `extract_font.py`      | Extracts the Swiss bitmap font data to a typed constant            |
| `extract_asm_data.py`  | General-purpose assembler data block extractor                     |

**Note:** `extract_worlds.py` must use `latin-1` encoding (not `cp1252`) when reading `WORLDS.PAS`, because enemy spawn codes in the `$80`-`$9F` byte range are corrupted by CP1252's remapping of those bytes to different Unicode codepoints.
