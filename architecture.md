# Pear Pudding TCG — Godot Rewrite Architecture

## Project Overview

A Godot 4 rewrite of the LibGDX isometric TCG. Uses Godot's 3D scene tree for isometric rendering, GDScript class_name system for game logic, and autoload singletons for global state management.

**Engine:** Godot 4, 3D scene graph with orthographic camera
**Main scene:** `res://scenes/ui/MenuScene.tscn`
**Rendering:** Forward Plus, 1280×720

---

## Directory Structure

```
pear-pudding-tcg-godot/
├── ai/
│   └── BasicAI.gd              # Static AI decision logic
├── autoloads/
│   ├── CardRegistry.gd         # Card template database
│   ├── GameBus.gd              # Global signal bus
│   ├── IsoConst.gd             # All isometric/gameplay constants
│   └── SceneManager.gd         # Screen transitions + map stack
├── game_logic/
│   ├── TerrainMath.gd          # Shared terrain height, mesh, wall, and entity spawn helpers
│   ├── TextureGen.gd           # Runtime texture generation with caching
│   ├── battle/
│   │   ├── CardInstance.gd     # Card runtime state
│   │   ├── GameState.gd        # Battle state root
│   │   ├── HeroState.gd        # Hero HP/mana
│   │   ├── PlayerState.gd      # Hand/board/deck for one player
│   │   └── ZoneState.gd        # 5-slot board zone
│   └── world/
│       ├── WorldEntity.gd      # Base class for world objects
│       └── WorldMap.gd         # Tile grid + entity lists + save/load
├── scenes/
│   ├── battle/
│   │   └── BattleScene.gd/.tscn   # Turn-based battle UI overlay
│   ├── ui/
│   │   ├── ChestOpenScene.gd/.tscn
│   │   ├── GameOverScene.gd/.tscn
│   │   ├── MapEditorScene.gd/.tscn
│   │   └── MenuScene.gd/.tscn
│   └── world/
│       ├── WorldScene.gd/.tscn    # 3D isometric world
│       ├── ChunkRenderer.gd       # Per-chunk terrain/wall/entity rendering
│       ├── GrassBlades.gd         # Grass shader + MultiMesh per chunk
│       └── entities/
│           ├── Chest.gd/.tscn
│           ├── Door.gd/.tscn
│           ├── EnemyNPC.gd/.tscn
│           └── Player.gd/.tscn
└── assets/
    └── maps/                   # Map text files (main.txt, etc.)
```

---

## Autoloads (Global Singletons)

### IsoConst
All constants in one place — never inline magic numbers.
- Tile: `MAP_WIDTH=100, MAP_HEIGHT=100, TILE_SIZE=2.0`
- Camera: `CAM_ELEVATION_DEG=-35.264, CAM_AZIMUTH_DEG=-45.0, CAM_ORTHO_SIZE=15.0`
- Gameplay: `AUTO_BATTLE_RANGE=1.5, INTERACT_RANGE=1.5, TRACKING_SPEED=2.5, PLAYER_SPEED=6.0`
- Utility: `tile_to_world(tx, tz)`, `world_to_tile(wx, wz)`

### GameBus
Signal hub — decouples scenes from each other.
```gdscript
# World signals
signal enemy_engaged(enemy_data: Dictionary)
signal battle_won(result: Dictionary)
signal battle_lost()
signal chest_opened(card_ids: Array)

# Battle signals
signal card_played
signal card_attacked
signal turn_ended
signal battle_ended
```

### SceneManager
Manages scene transitions and map navigation stack.
- `start_new_game()` → enters "main" map
- `enter_map(map_name, target_door_id)` → pushes current map to stack, loads WorldScene
- `exit_map()` → pops parent map + return door, respawns at return door
- Handles overlays: BattleScene (on `enemy_engaged`), ChestOpenScene (on `chest_opened`)

### CardRegistry
4 card templates: ghost (1/1/2), skeleton (2/2/2), zombie (3/2/4), ghoul (4/4/3).
- `get_template(id) -> Dictionary`
- `get_all_ids() -> Array[String]`

---

## Game Logic (Pure GDScript, no rendering)

### WorldMap
`class_name WorldMap extends RefCounted`
- Tile grid `tiles[tz][tx]` (GRASS=0, WALL=1, HILL=2), sparse heights
- Entity lists: `enemies[]`, `chests[]`, `doors[]` (Array of Dictionaries)
- Loads from `user://maps/<name>.txt` first, then `res://assets/maps/<name>.txt`
- Falls back to `_build_default_map()` with procedural entity generation
- Save format: text-based sparse (same as Java version)
  ```
  100 100
  [tile rows as digit chars]
  HEIGHTS
  x,z,height  ← sparse, non-zero only
  SPAWN x z
  ENEMY x z
  CHEST x z card1,card2
  DOOR x z targetMap [targetDoorId]  ← targetDoorId optional
  ```

### GameState / Battle Classes
- `GameState` — 2 players, turn number, `end_turn()`, `is_game_over()`, `winner()`
- `PlayerState` — hero + hand + board (`ZoneState`) + draw/discard decks
- `ZoneState` — 5-slot board, `snapshot()`/`restore_snapshot()` for drag animations
- `CardInstance` — stats + state (`summoning_sick`, `attack_count`, `out_of_play`)
- `HeroState` — HP/mana

### BasicAI
`static func decide_turn(state: GameState) -> Array[Callable]`
Returns a list of lambda actions: play all affordable cards, attack viable targets (enemy hero if no minions, else first minion).

---

## Scenes

### WorldScene (Node3D)
- `@export var map_name: String` — set by SceneManager before adding to tree
- `@export var target_door_id: String` — spawn override
- `_ready()`: builds tiles/walls/entities, spawns player
- `_process()`: camera follows player, checks nearby interactables
- `_input()`: E key → `_handle_interact()` (doors/chests)
- Tiles: `PlaneMesh` quads positioned at `(tx * TILE_SIZE, 0, tz * TILE_SIZE)`
- Walls: stacked `BoxMesh` cubes (one per height level), `StaticBody3D` for collision
- Entities: loaded from `.tscn` with `init_from_data(dict)` pattern

### BattleScene (Control — overlay)
- Added as child of current WorldScene via SceneManager
- `enemy_data: Dictionary` set before adding to tree
- Human: left-click hand card to play, click board card + click target to attack
- AI: `BasicAI.decide_turn()` generates actions, executed with 0.6s delays via `await`
- Signals `GameBus.battle_won` / `battle_lost` on game end

### Player (CharacterBody3D)
- Isometric WASD: W=NE, A=NW, S=SW, D=SE (diagonal movement)
- `move_and_slide()` physics, gravity, jump
- Speed constants from `IsoConst.PLAYER_SPEED`

### EnemyNPC (Node3D)
- Tracks player if within range, auto-engages at `AUTO_BATTLE_RANGE`
- On engage: emits `GameBus.enemy_engaged`, marks `alive=false`, queues free

---

## Game Flow

```
MenuScene
    ↓ start_new_game
SceneManager.enter_map("main")
    ↓
WorldScene("main")
  ├─ Enemy nearby → GameBus.enemy_engaged
  │       ↓
  │   BattleScene overlay
  │   ├─ Win → remove overlay, continue
  │   └─ Lose → GameOverScene
  ├─ Chest E → GameBus.chest_opened
  │       ↓
  │   ChestOpenScene overlay (sequential reveal)
  └─ Door E → SceneManager.enter_map(target) or exit_map()
```

---

## Key Patterns

### Autoload vs. Pass-by-constructor
Use autoloads for truly global state (signals, constants, transitions). Pass data via constructor/export for scene-specific context (`map_name`, `target_door_id`, `enemy_data`).

### init_from_data pattern
Entity scenes (EnemyNPC, Chest, Door) expose `init_from_data(data: Dictionary)` called after instantiation. WorldScene uses `has_method("init_from_data")` check for fallback safety.

### Map Stack for Sub-areas
`SceneManager` maintains `map_stack` and `door_stack` arrays. Entering a dungeon pushes current map; exiting pops and spawns at the return door. Supports arbitrary nesting.

### Overlay Scenes
Battle and chest screens are added as children of the current WorldScene (not replacing it). This keeps world state alive during overlays and allows seamless return to exploration.

### TerrainMath — Single Source of Truth for Terrain
All terrain height computation, mesh building, wall mesh building, and entity spawning
are consolidated in `game_logic/TerrainMath.gd`. Both the named-map path (WorldScene)
and the infinite-chunk path (ChunkRenderer) delegate to TerrainMath via Callable-based
tile lookups. This avoids the previous duplication of ~400 lines of terrain code.

Key static methods:
- `get_height_at(wx, wz, tile_lookup, height_lookup, curve_r, peak_h)` — single-point height query
- `compute_height_field(tile_lookup, ...)` — packed float array for mesh vertices
- `build_terrain_mesh(hfield, tile_lookup, ...)` — ArrayMesh + HeightMapShape3D
- `build_wall_mesh(get_tile_fn, get_height_fn, grid_w, grid_h)` — wall ArrayMesh with surface_types meta
- `ensure_wall_materials(tex_left, tex_right, tex_top)` / `get_wall_materials()` — shared wall StandardMaterial3Ds
- `spawn_entity(scene, data, y_offset, entity_root, world_scene)` — shared entity instantiation

### Canonical Constants
All tile types (`TILE_GRASS`, `TILE_WALL`, `TILE_HILL`), sizes (`TILE_SIZE`, `CHUNK_SIZE`),
and physics constants (`WALL_FACE_H`) live in `IsoConst`. WorldMap re-exports them as
aliases for backward compatibility. Never duplicate these values in other files.
