# Project Specification — Pear Pudding TCG

> **This file is human-owned.** Write freely. No format is enforced.
> Claude will read this to derive designs, tasks, and architecture — but will never edit it.

---

## Overview

Pear Pudding TCG is a 3D isometric open-world RPG built in Godot 4 where the player explores a procedurally generated world, encounters enemies, and resolves combat through a collectible card game (TCG) battle system. The game features a hand-crafted story mode (The Tale of Saimtar) layered on top of the infinite sandbox world.

---

## Goals

- A complete, shippable game on Android (primary platform) and desktop
- Seamless world exploration with streaming infinite terrain across 5 distinct biomes
- A satisfying TCG battle loop: collect cards, build a deck, fight increasingly tough enemies
- A narrative story mode (Chapters 1+) woven through named hand-crafted maps
- Clean pixel-art isometric aesthetic with procedural grass, hills, and ruins

---

## Key Features

### World & Exploration
- Infinite procedural world divided into 16×16 tile chunks, streamed around the player
- Five biomes: Grasslands, Forest, Desert, Scorched, Mountains — each with distinct terrain shape, enemy pool, and visual tint
- Simplex noise tile generation (GRASS / HILL / WALL) with per-biome frequency and thresholds
- Procedural ruins (~33% of chunks) with crumbled walls and door openings leading to dungeons
- Day/night cycle with time-of-day shader tinting
- Isometric camera fixed at classic 1:1:1 axonometric ratio (−35.264° elevation, −45° azimuth)
- WASD movement mapped to isometric world directions; virtual joystick on mobile

### Card Battle System
- Turn-based TCG: player vs AI enemy
- Four card types: Ghost, Skeleton, Zombie, Ghoul — with mana cost, attack, and health
- 5-slot board zones per player; mana grows 1/turn capped at 10
- Summoning sickness, one attack per minion per turn, hero HP (30)
- Drag-to-play card UI; BasicAI plays and attacks automatically on enemy turn
- Card collection: earn cards from chests and battles; build/manage deck in Inventory scene

### Named Maps & Story Mode
- Text-file map format (`.txt`) with tile grid and entity directives (SPAWN, NPC, ENEMY, CHEST, DOOR)
- Hand-crafted maps: madrian, maykalene, farsyth_mansion, blancogov, blancogov_temple
- Story: The Tale of Saimtar — an 11-year-old orphan on an adventure with old wizard Maiteln to warn King Eldar of the rising Martarquas tribe
- Story flags in SaveManager gate NPC dialogue and progression
- Procedural dungeons generated from a seed when entering dungeon doors

### Save System
- Single JSON save at `user://save.json`
- Dirty-flag batched writes (max 2s delay)
- Field migration so old saves always load correctly
- Tracks: deck, owned cards, position, map stack, defeated enemies, opened chests, time of day, world seed, biome

### UI & Menus
- Scene stack managed by SceneManager (world → battle overlay → inventory → menus)
- Main menu, biome selection (new game), inventory/deck builder, game over screen
- Map editor for authoring named maps in-engine

---

## Architecture & Technical Constraints

- **Engine:** Godot 4.4.1 (GDScript, strict mode)
- **Primary export:** Android (APK via GitHub Actions CI)
- **Rendering:** 3D isometric with pixel-art sprites; no geometry shaders (Godot 4 does not support them)
- **Terrain:** CPU-built `ArrayMesh` via `TerrainMath.gd`; grass via fragment FBM shader on flat planes
- **Signals:** All cross-system communication via `GameBus` autoload (no direct node references between systems)
- **Constants:** All tile types, sizes, and ranges in `IsoConst` autoload — no duplicates elsewhere
- **Resources:** All `.gdshader`, `.tres`, `.material` files need `.uid` sidecars for Android export
- **Tests:** GUT-based tests run headless via `godot --headless --path . -s tests/runner.gd`

### Autoloads (singletons)
| Autoload | Role |
|---|---|
| `IsoConst` | Tile sizes, camera angles, gameplay ranges |
| `GameBus` | Signal hub decoupling all systems |
| `SceneManager` | Scene routing and map stack |
| `SaveManager` | JSON persistence |
| `CardRegistry` | Card template database |
| `EnemyRegistry` | Enemy deck database |

### Directory Layout
```
autoloads/          — singleton scripts
game_logic/         — pure GDScript (no rendering): battle/, world/, TerrainMath.gd
scenes/             — rendering + interaction: world/, battle/, ui/
assets/             — shaders/, textures/, maps/
data/               — cards/*.tres, enemies/*.tres
tests/              — GUT test scripts
docs/human/         — human-owned specs and workflow (never edited by agent)
docs/agent/         — agent-owned design docs (kept current after each feature)
tasks/              — goal and task tracking (agent-managed)
```

---

## Out of Scope (for now)

- Multiplayer / online features
- More than 4 card types in v1 battle system
- Voice acting or music
- Complex branching dialogue trees (single NPC line per state for now)
- Mac / iOS export (Android + desktop only)

---

## Open Questions

- What are the rewards for winning battles beyond card drops? (XP, coins, story flags?)
- Should defeated enemies respawn after a real-time interval, or stay dead per save?
- How many chapters are planned? Is Chapter 2 in scope for the first public release?
- Should the deck builder enforce a minimum / maximum deck size?

---

## References & Inspirations

- **TCG mechanics:** Hearthstone (mana curve, board zones, hero HP)
- **World exploration:** early Zelda games (top-down exploration feel in 3D)
- **Aesthetic:** classic RPG pixel art scaled into 3D isometric view
- **Story tone:** The Hobbit / Redwall — a young protagonist in a grounded fantasy world
