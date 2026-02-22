# Mario & Luigi Level Editor

A visual level editor for Mario & Luigi, built with SDL2 + OpenGL3 + Dear ImGui.

## Building

### Requirements

- [Free Pascal Compiler 3.2.2+](https://www.freepascal.org/) (`ppcrossx64` for 64-bit builds)
- SDL2, SDL2_mixer DLLs (included in `ImGui-Pascal/libs/dynamic/windows/64bit/`)
- cimgui DLL (included in `ImGui-Pascal/libs/dynamic/windows/64bit/`)

### Compile

```bat
cd editor
build.bat
```

Output goes to `editor/OUT/`. Run `OUT/EDITOR.exe` to launch.

## Controls

### Viewport Navigation

| Input              | Action                    |
|--------------------|---------------------------|
| Mouse wheel        | Scroll level horizontally |
| Middle-click drag  | Pan the viewport          |
| Left / Right arrow | Scroll by 20px            |
| 1 / 2 / 3         | Set zoom level (1x/2x/3x)|
| G                  | Toggle grid overlay       |
| M                  | Toggle markers            |

### Tile Editing

| Input              | Action                              |
|--------------------|-------------------------------------|
| Click tile palette | Select a tile to paint with         |
| Left-click drag    | Paint selected tile in viewport     |
| Right-click drag   | Erase tile (replace with empty)     |
| Alt + Left-click   | Eyedropper (pick tile under cursor) |
| Escape             | Deselect current tile               |

### Shortcuts

| Shortcut | Action                          |
|----------|---------------------------------|
| Ctrl+Z   | Undo last stroke                |
| Ctrl+Y   | Redo last undone stroke         |
| Ctrl+S   | Save level to file              |
| Ctrl+O   | Load level from file            |

## Menus

### File Menu

- **Open Built-In** - Load one of the 12 built-in levels (1A through 6B). If you have unsaved changes, a confirmation dialog appears.
- **Save Level** (Ctrl+S) - Save the current level to `level_edit.mled` in the editor folder.
- **Load Level** (Ctrl+O) - Load a previously saved level from `level_edit.mled`.
- **Quit** (Alt+F4) - Exit the editor.

### Edit Menu

- **Undo** (Ctrl+Z) - Undo the last paint/erase stroke. Up to 200 undo steps.
- **Redo** (Ctrl+Y) - Redo the last undone action.

### View Menu

- **Zoom 1x/2x/3x** - Change viewport zoom level.
- **Show Grid** (G) - Toggle tile grid overlay.
- **Show Markers** (M) - Toggle enemy sprites, item markers, pipe labels, camera locks, and player start position.
- **ImGui Demo** - Show the Dear ImGui demo window (development reference).

### Help Menu

- **About** - Show build info.

## Editor Panels

### Tile Palette

Shows all available tiles organized by category tabs:

| Tab        | Contents                              |
|------------|---------------------------------------|
| Ground     | Wall types (6 themes: Green, Sand, Brown, Grass, Desert + level default) |
| Bricks     | Brick blocks in 4 colors             |
| Pipes      | Pipe tiles in 6 colors               |
| Blocks     | Question, Used, Hidden, Solid, Note blocks |
| Items      | Coins, flags                         |
| Deco       | Decorative tiles (fences, palms, etc)|
| Platforms  | Moving platforms, pins               |
| Rewards    | X-Blocks and Wood blocks in color variants |

Click a tile to select it. The selected tile is highlighted with a yellow border. A semi-transparent preview appears at the cursor position in the viewport.

### Enemy Palette

Shows all 13 enemy types with their actual in-game sprites at 3x zoom. Click to select an enemy for placement.

### Level Viewport

The main editing area. Shows the level rendered with the game's actual rendering pipeline. Overlays include:

- **Hover highlight** - Yellow highlight on the tile under the cursor (when no tile is selected) or a preview of the selected tile (when painting).
- **Grid** - Optional tile grid overlay (press G).
- **Markers** - Enemy sprites, item indicators, pipe warp/exit labels, camera lock lines, and the player start position.
- **Tooltip** - Shows tile name, position, character code, and block contents on hover.

### Level Settings

Displays current level info:

- Level name, sky type, background type, music track
- Scroll position and zoom level
- Hovered tile details (position, character code, type name)
- Selected tile info (name, code)
- Unsaved changes indicator

### Sky & Background

Browse and preview all available sky and background combinations. Use the arrow buttons or slider to cycle through sky types (0-12) and background types.

## Undo/Redo System

- Each continuous paint or erase drag is recorded as a single **stroke** (one undo action).
- A stroke can contain up to 512 individual tile changes.
- The undo stack holds up to 200 strokes in a ring buffer. When full, the oldest strokes are discarded.
- Performing a new edit after undoing clears the redo history.

## Save/Load Format (.mled)

Levels are saved in a compact binary format:

| Offset | Size     | Description                    |
|--------|----------|--------------------------------|
| 0      | 4 bytes  | Magic: `MLED`                  |
| 4      | 1 byte   | Version (currently 1)          |
| 5      | varies   | WorldOptions record            |
| varies | XSize*13 | Tile data (column-major order) |
| varies | XSize    | Hidden row (camera locks, pipe warps) |

Total file size is approximately 3.3 KB for a maximum-width level (236 columns).

The default save file is `level_edit.mled` in the editor's working directory.

## Visual Feedback

- **Window title** shows `* Mario & Luigi Level Editor` when there are unsaved changes.
- **Level Settings panel** shows a red "Unsaved changes" indicator.
- **Unsaved changes dialog** appears when switching to a different built-in level with pending edits.
- **Cursor preview** shows a ghost of the selected tile at the hover position in the viewport.
