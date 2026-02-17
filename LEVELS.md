# Level Map

Mario & Luigi features **6 worlds**, each with a main overworld (A) and an optional underground sub-world (B) accessible via pipes. After completing all 6 worlds, a harder **Turbo loop** begins with faster enemies and remixed visual themes.

## World Overview

| World | Theme | Sub-world? | Pipes | Turbo Change |
|-------|-------|:----------:|:-----:|--------------|
| 1 | Outdoor, teal sky, brown ground, rolling hills | Yes | 5 | Sunset sky, mountains |
| 2 | Underground cave, dark brick walls | No | 7 | Brown brick variant, recolored |
| 3 | Outdoor, blue sky, custom-colored terrain, hills | No | 3 | Blue-cyan sky shift |
| 4 | Outdoor, bright blue-cyan sky, green ground, mountains | Yes | 5 | Warm sand sky, hills replace mountains |
| 5 | Outdoor, blue gradient, green ground, arch hills | Yes | 6 | Dark night sky |
| 6 | Castle fortress, gray brick, oppressive interior | Yes | 6 | Recolored pipes and ground |

## Detailed Level Breakdown

### World 1 - Rolling Hills

**Main (1A):** A classic outdoor level with a teal-blue gradient sky, brown terrain, and arch-shaped hills in the background. Contains 3 within-world teleport pipes, 2 cross-world pipes leading down to 1B, and 1 level-complete exit pipe.

**Sub-world (1B):** A short underground dungeon with dark brown brick sky and brick-wall background. Contains 1 within-world teleport pipe and 1 cross-world pipe back up to 1A. Find the hidden pipe to access a coin-filled bonus room!

**Turbo variant:** The teal sky becomes a warm sunset/desert gradient, and the arch hills are replaced with mountain silhouettes.

---

### World 2 - Underground Cave

**Main (2A):** An entirely underground level with a dark brown-red brick sky and brick wall backgrounds. The longest level in the game. Contains 5 within-world teleport pipes and 2 level-complete exit pipes. The teleport pipes connect different sections of the sprawling cave system.

**No sub-world.** Despite having cross-world pipe codes in the data, World 2 has no sub-level B.

**Turbo variant:** Shifts to a brown brick variant with modified background coloring.

---

### World 3 - Custom Terrain

**Main (3A):** An outdoor level with a blue-to-deep-blue gradient sky, custom-recolored ground tiles, and inverted arch hills in the background. Contains 2 within-world teleport pipes and 1 level-complete exit pipe.

**No sub-world.**

**Turbo variant:** The sky shifts from blue to blue-cyan.

---

### World 4 - Mountain Landscape

**Main (5A):** An outdoor level with a bright blue-cyan gradient sky, green ground, and mountain silhouettes in the background. Contains 1 within-world teleport pipe, 2 cross-world pipes leading to 5B, and 1 level-complete exit pipe. Look for the hidden pipe entrances among the mountains!

**Sub-world (5B):** A brown brick interior with very low horizon. Contains 1 within-world teleport pipe and 1 cross-world pipe back to 5A.

**Turbo variant:** The bright blue sky becomes a warm sandy gradient, the green ground changes to a different wall style, and the mountains are replaced with arch hills.

---

### World 5 - Arch Hills

**Main (6A):** An outdoor level with a blue-to-deep-blue gradient sky, green ground, and arch hills. Shares its visual theme with the title screen. Contains 1 within-world teleport pipe, 3 cross-world pipes leading to 6B, and 1 level-complete exit pipe. Multiple secret pipe entrances are scattered throughout!

**Sub-world (6B):** A bright outdoor area with a white-cyan gradient sky, custom-recolored terrain, and a unique arch-shaped background. Contains 1 within-world teleport pipe and 1 cross-world pipe back to 6A.

**Turbo variant:** The blue sky becomes a very dark night sky, transforming this into a night level.

---

### World 6 - Castle Fortress

**Main (4A):** A castle/fortress level with a gray brick sky, very low horizon, and an interior background. The most oppressive-looking level in the game. Contains 1 within-world teleport pipe, 2 cross-world pipes leading to 4B, and 1 level-complete exit pipe. The castle's pipe network leads deep underground.

**Sub-world (4B):** A substantial castle dungeon with brown brick sky, low horizon, and dark interior. Contains 2 within-world teleport pipes and 2 cross-world pipes back to 4A. The largest sub-world in the game!

**Turbo variant:** The castle gets recolored pipes, ground, and background colors for a different palette.

---

## Progression System

Each player (Mario and Luigi) tracks their own progress independently.

| Progress | Loop | World | Display |
|----------|------|-------|---------|
| 0 | Normal | World 1 | Level 1 |
| 1 | Normal | World 2 | Level 2 |
| 2 | Normal | World 3 | Level 3 |
| 3 | Normal | World 4 | Level 4 |
| 4 | Normal | World 5 | Level 5 |
| 5 | Normal | World 6 | Level 6 |
| 6 | Turbo | World 1 | Level 1* |
| 7 | Turbo | World 2 | Level 2* |
| 8 | Turbo | World 3 | Level 3* |
| 9 | Turbo | World 4 | Level 4* |
| 10 | Turbo | World 5 | Level 5* |
| 11 | Turbo | World 6 | Level 6* |

After progress exceeds 11, it wraps back to 6 and the Turbo loop repeats indefinitely.

In the save game menu, Turbo levels are marked with a blinking `*` indicator.

## Turbo Mode

Turbo mode activates on the second loop (progress >= 6) and introduces two changes:

1. **Faster enemies:** Enemy movement velocities are doubled and spawn delays are halved.
2. **Visual remix:** Each level loads alternative visual options that change the sky gradient and/or background type, giving familiar levels a fresh appearance (sunset skies, night mode, different terrain, etc.).

The level layouts and map data remain identical between Normal and Turbo mode.

## Pipe System

Pipes connect different areas within and between levels. The game uses a two-byte pipe code system where the first byte determines the pipe's behavior and the second byte routes the connection to a specific exit.

| Type | Behavior |
|------|----------|
| Within-world | Teleports to another location in the same sub-level |
| Cross-world | Swaps between main level (A) and sub-world (B) |
| Level-complete | Triggers the "STAGE CLEAR!" sequence and advances progress |

Enter pipes by pressing **Down** while standing on a pipe top, or **Up** from below certain pipes.

### Pipe Counts by Level

| Level | Within-world | Cross-world | Level-complete | Total |
|-------|:------------:|:-----------:|:--------------:|:-----:|
| World 1A | 3 | 2 | 1 | 6 |
| World 1B | 1 | 1 | - | 2 |
| World 2A | 5 | - | 2 | 7 |
| World 3A | 2 | - | 1 | 3 |
| World 4A (5A) | 1 | 2 | 1 | 4 |
| World 4B (5B) | 1 | 1 | - | 2 |
| World 5A (6A) | 1 | 3 | 1 | 5 |
| World 5B (6B) | 1 | 1 | - | 2 |
| World 6A (4A) | 1 | 2 | 1 | 4 |
| World 6B (4B) | 2 | 2 | - | 4 |
| **Total** | **18** | **14** | **7** | **39** |

