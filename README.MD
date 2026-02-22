# Mario & Luigi - Improved SDL2 Port

![Mario & Luigi - Latest Build Screenshot](https://cdn.planetmagpie.net/mario.png)

A massive improvement and reimplementation of the SDL2 port of **Mario & Luigi** (1994) by Mike Wiering, original SDL2 port can be found on the main branch.

The original game is a side-scrolling platformer for DOS featuring 6 worlds, two-player mode (Mario & Luigi), enemies, power-ups, pipes, and PC speaker sound effects. This port preserves all gameplay, visuals, and audio identically while replacing all DOS/hardware-specific code with SDL2 equivalents and the improved version massive rewrittes a lot of the game with QoL changes and adds a bunch of new features.  
  
This was originally based on the original [MARIOSRC.ZIP](https://wieringsoftware.nl/mario/MARIOSRC.ZIP) release, not based on the GitHub repo that was featured on Hacker News recently.  
  
You can play the original on the [Internet Archive's DOSBOX for browsers](https://archive.org/details/msdos_Mario_and_Luigi_2001) and the base SDL2 port can be found in the releases page listed as "Feature Parity".  
  
## Building

### Requirements

- [Free Pascal Compiler 3.2.2+](https://www.freepascal.org/) (`ppcrossx64` for 64-bit builds)
- [SDL2 development library](https://github.com/libsdl-org/SDL/releases) (`SDL2.dll`, included)
- [SDL2_mixer development library](https://github.com/libsdl-org/SDL_mixer/releases) (`SDL2.dll`, included)
- [SDL2-for-Pascal](https://github.com/PascalGameDevelopment/SDL2-for-Pascal) bindings (`SDL2_mixer.dll`, included)

### Compile

Run the build script:

```bat
build.bat
```

Or compile manually:

```bat
fpc -Mtp -Sg -FuSDL2-for-Pascal MARIO.PAS
```

Place `SDL2.dll` in the same directory as `MARIO.exe` and run.

### Compiler Flags

| Flag   | Purpose                                              |
|--------|------------------------------------------------------|
| `-Mtp` | Turbo Pascal mode (`Integer` = 16-bit, matches original overflow behavior) |
| `-Sg`  | Allow `goto` statements (used in game loop)          |
| `-Fu`  | Unit search path for SDL2-for-Pascal bindings        |

## What Was Ported

The original game used extensive x86 inline assembly and direct hardware access. Every hardware-dependent component was rewritten in pure Pascal + SDL2:

### Graphics (VGA256.PAS)
- **VGA Mode 13h planar rendering** &rarr; Linear byte framebuffer arrays
- **Hardware page flipping** (CRTC registers) &rarr; Two software framebuffer pages
- **Hardware scrolling** (CRTC start address) &rarr; Viewport offset applied during presentation
- **VGA palette registers** (ports $3C8/$3C9) &rarr; SDL palette arrays, converted to ARGB during rendering
- **PushBackGr/PopBackGr** (VGA latch-copy sprite save/restore) &rarr; Heap-based stack with byte array storage
- **All drawing primitives** (DrawImage, PutImage, Fill, etc.) &rarr; Pure Pascal framebuffer operations
- Renders to a 320x182 software surface, scaled 3x to a 960x546 window via SDL2 renderer

### Input (KEYBOARD.PAS)
- **INT 09h keyboard interrupt handler** &rarr; SDL2 event polling
- **Direct port $60/$61 scancode reading** &rarr; SDL scancode-to-AT-scancode mapping
- **Demo recording/playback** from linked OBJ file &rarr; Typed constant array extracted from DEMOKEYS.OBJ

### Audio (MUSIC.PAS + BUFFERS.PAS)
- **PC speaker via ports $42/$43/$61** &rarr; SDL2 audio callback generating square waves at 44100 Hz
- Music sequence player with note sustain tracking to match PC speaker behavior
- Sound effect priority system ensuring one-shot beeps survive the audio callback timing

### Joystick (JOYSTICK.PAS)
- **Direct port $201 polling** &rarr; SDL2 joystick API

### Timing
- **DOS timer tick** (`$0000:$046C`) &rarr; `SDL_GetTicks div 55`
- **Frame pacing** &rarr; 14ms minimum per frame (~71 fps, matching original DOS speed)

### Sprite Data
- **VGA planar format** (`.$00` files with inline `asm db` blocks) &rarr; Linear byte-per-pixel format (`.000` files converted to typed constants via Python scripts)
- 170+ sprite include files auto-generated from original game assets

### Level Data (WORLDS.PAS)
- **Assembler `db`/`dw` blocks** in procedures &rarr; Typed constant byte arrays extracted via Python script

### Other Replacements
- `uses Crt` (Sound/NoSound/Delay) &rarr; SDL2 audio + SDL_Delay
- `CPU286` unit &rarr; Empty stub
- `{$L DEMOKEYS.OBJ}` &rarr; Extracted to typed constant
- VGA vertical blanking (CRTC SetYStart/SetYEnd) &rarr; Window sized to exact content area
- Executable name checksum protection &rarr; Removed

## Running

All game assets (sprites, levels, fonts, palettes) are compiled directly into the executable as typed constants. To run the game you need:

| File              | Description                                       |
|-------------------|---------------------------------------------------|
| `MARIO.exe`       | Game executable (all data embedded)               |
| `SDL2.dll`        | SDL2 runtime library                              |
| `SDL2_mixer.dll`  | SDL2 Mixer library (for background music, optional) |
| `music/*.ogg`     | Background music tracks (optional)                |

Place all files in the same folder and run `MARIO.exe`. The game works without `SDL2_mixer.dll` and `music/` — you'll just get the original PC speaker sound effects instead of background music.

## Controls

### Menu
| Key             | Action              |
|-----------------|----------------------|
| Up / Down       | Navigate menu        |
| Enter / Space   | Select               |
| Left / Right    | Change option value  |
| Escape          | Back / Quit          |

### Gameplay (defaults)
| Key             | Action              |
|-----------------|----------------------|
| Left / Right    | Move                 |
| X               | Jump                 |
| Z               | Run                  |
| C               | Fire (when in fire mode) |
| Down            | Duck / Enter pipe    |
| Up              | Look up / Enter pipe |
| Enter           | Pause                |
| S               | Toggle status bar    |
| Q               | Toggle sound on/off  |
| F12             | Debug menu           |
| Escape          | Quit to main menu    |

All six action keys (Jump, Run, Fire, Pause, Sound, Status) can be rebound in the **Options** menu. Joystick is also supported.

## Cheats

While paused, press **Tab** to enter cheat code mode, then type one of the following codes:

### Power-Ups & Lives
| Code   | Effect                     |
|--------|----------------------------|
| `03E8` | Extra life (+1)            |
| `B172` | 10,000 lives               |
| `9C32` | Star power (invincibility) |
| `F1F2` | Super Mushroom (grow big)  |
| `FFB5` | Fire Flower                |
| `1UP`  | Spawn 1-Up mushroom        |

### Gameplay
| Code   | Effect                           |
|--------|----------------------------------|
| `2305` | Skip to next level               |
| `D235` | Toggle turbo mode (double speed) |

### Visual Modes
| Code      | Effect                          |
|-----------|---------------------------------|
| `MONO`    | Black & white mode              |
| `EGAMODE` | Retro EGA color palette         |
| `VGAMODE` | Restore normal VGA palette      |
| `COLOR`   | Restore normal VGA palette      |

### Misc
| Code      | Effect                         |
|-----------|--------------------------------|
| `TEST`    | Toggle retrace debug overlay   |
| `0044`    | Toggle retrace debug overlay   |
| `CREDITS` | Show programmer credit         |

### Demo Recording (advanced)
| Code   | Effect                          |
|--------|---------------------------------|
| `76DD` | Start recording demo input      |
| `C7B4` | Play back recorded demo         |
| `208D` | Save recorded demo to file      |

## Debug Menu

Press **F12** during gameplay to open the debug menu. Options:

| Option              | Effect                                       |
|---------------------|----------------------------------------------|
| Trigger Game Over   | Immediately end the current game             |
| Skip to Next Level  | Advance to the next level                    |
| Skip to Level N     | Jump to a specific world (use Left/Right to pick 1-6) |
| Back to Main Menu   | Return to the title screen                   |
| Max Lives           | Set lives to 10,000                          |
| Power Up            | Give fire flower power                       |
| Resume              | Close debug menu and continue playing        |

## Level Editor

A visual level editor is included in the `editor/` folder. It uses the game's actual rendering pipeline with a Dear ImGui interface for browsing, editing, and saving levels. See **[editor/EDITOR.md](editor/EDITOR.md)** for full documentation including controls, features, and the save file format.

## Levels

The game features 6 worlds with a second harder "Turbo" loop after completion (12 progression stages total). See **[LEVELS.md](LEVELS.md)** for a complete level map, visual themes, pipe system details, and progression breakdown.

## Project Structure

```
sdl2_port/
  MARIO.PAS          Main program
  PLAY.PAS           Game loop
  VGA256.PAS         SDL2 graphics engine (core)
  KEYBOARD.PAS       SDL2 input handling
  MUSIC.PAS          SDL2 audio (square wave synthesis)
  BUFFERS.PAS        Game state, types, shared audio vars
  PALETTES.PAS       VGA palette management
  FIGURES.PAS        Tile/sprite initialization & rendering
  BACKGR.PAS         Background rendering (parallax, bricks, etc.)
  PLAYERS.PAS        Player movement & rendering
  ENEMIES.PAS        Enemy AI & rendering
  TMPOBJ.PAS         Temporary objects (fireballs, particles)
  BLOCKS.PAS         Breakable/bouncing blocks
  GLITTER.PAS        Sparkle/particle effects
  STARS.PAS          Background star field
  STATUS.PAS         HUD status bar
  TXT.PAS            Text rendering (Swiss bitmap font)
  WORLDS.PAS         World/level data management
  JOYSTICK.PAS       SDL2 joystick support
  CPU286.PAS         Stub (originally 286 detection)
  build.bat          Build script (Windows 64-bit)
  icon.ico           Application icon
  mario.rc           Windows resource script
  sprites/           170 auto-generated sprite include files
  data/              Level data, fonts, palettes, backgrounds
  music/             Background music tracks (.ogg)
  SDL2-for-Pascal/   SDL2 Pascal bindings (MPL/zlib licensed)
  editor/            Visual level editor (SDL2 + OpenGL3 + Dear ImGui)
```

## Credits

- The original game and its source code were created by Mike Wiering in 1994. All credit for the original code goes to its author. You can find the original source at [wieringsoftware.nl](https://wieringsoftware.nl/mario/).
- **SDL2 Port**: Created with assistance from Claude (Anthropic)
- **SDL2-for-Pascal**: PascalGameDevelopment community
- The characters "Mario", "Luigi", and all related names, images, and concepts are the registered trademarks and copyright of **Nintendo Co., Ltd.** This project is **not affiliated with, authorized, or endorsed by Nintendo** in any way.
- This project is strictly non-commercial. It is provided for free, and no profit is being made from its existence or distribution. Do not attempt to sell or commercialize this software.
