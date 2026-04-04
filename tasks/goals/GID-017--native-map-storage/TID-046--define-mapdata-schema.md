# TID-046: Define MapData Resource Schema

**Goal:** GID-017
**Type:** agent
**Status:** done
**Depends On:** —

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

This task creates the GDScript `Resource` subclasses that will replace the custom `.txt` format. All other tasks in GID-017 depend on these classes existing first.

The schema must encode everything the current `.txt` format stores, plus extensibility fields for features planned in GID-017: scripted triggers, map regions/zones, and per-map metadata.

## Research Notes

**Current entity dictionary fields** (from `WorldMap.load_from_string()`):

- `ENEMY` → `{ "id": String, "x": int, "z": int, "alive": bool, "tracking": bool, "enemy_type": String, "enemy_deck": Array[String] }`
- `CHEST` → `{ "id": String, "x": int, "z": int, "card_ids": Array[String], "opened": bool }`
- `NPC` → `{ "id": String, "x": int, "z": int, "dialogue": String, "flag_key": String, "after_dialogue": String }`
- `DOOR` → `{ "id": String, "x": int, "z": int, "target_map": String, "target_door_id": String, "flag_key": String }`
- `SCROLL` → `{ "id": String, "scroll_id": String, "x": int, "z": int, "flag_key": String }`

**Tile types** (from `autoloads/IsoConst.gd`): TILE_GRASS=0, TILE_WALL=1, TILE_HILL=2, TILE_PATH=3

**Tile grid storage**: currently `tiles[tz][tx]` as a 2D Array of Arrays (100×100). Migrate to flat `PackedInt32Array` of size `width * height`, indexed as `tz * width + tx`.

**Heights**: currently `heights[tz][tx]` sparse (only non-zero set). Migrate to flat `PackedInt32Array` — same indexing. Default 0.

**Key files:**
- `game_logic/world/WorldMap.gd` — current dict field definitions
- `autoloads/IsoConst.gd` — tile type constants
- `CLAUDE.md` — `.uid` sidecar requirement, GDScript Variant inference rules

## Plan

Create `game_logic/world/resources/` and write 8 `extends Resource` scripts following
the pattern in `data/CardData.gd` / `data/EnemyData.gd`:

- Each script has `class_name` (for `.tres` `script_class` annotation) + `extends Resource`
- `@export var` for every stored field
- No runtime state (alive, tracking, opened) — those are added at load time in TID-049
- Entity positions stored as **tile coordinates** (`tile_x`, `tile_z`) for readability;
  conversion to world coords (multiply by `TILE_SIZE`) happens in TID-049
- `MapData.enemies/chests/doors/npcs/scrolls/triggers/regions` typed as `Array[Resource]`
  (can't forward-reference typed sub-classes without `class_name` being scanned first)
- Generate a `.uid` sidecar for every `.gd` file per CLAUDE.md requirement

Files:
1. `MapData.gd` — top-level map resource (tiles, heights, spawn, entity arrays, metadata)
2. `MapEnemy.gd` — tile-positioned enemy entity (type string, not battle template)
3. `MapChest.gd` — tile-positioned chest with card_ids
4. `MapDoor.gd` — tile-positioned door with target_map / target_door_id / flag_key
5. `MapNpc.gd` — tile-positioned NPC with dialogue, npc_type, flag_key, after_dialogue
6. `MapScroll.gd` — tile-positioned scroll with scroll_id / flag_key
7. `MapTrigger.gd` — new: tile-positioned event trigger (event_id, once, flag_key)
8. `MapRegion.gd` — new: rectangular named zone (x, z, width, height, type, name)

## Changes Made

Created `game_logic/world/resources/` with 8 Resource scripts + `.uid` sidecars:

| File | class_name | Description |
|------|-----------|-------------|
| `MapData.gd` | MapData | Top-level map: tiles (PackedInt32Array), heights, spawn, entity arrays, metadata |
| `MapEnemy.gd` | MapEnemy | entity_id, tile_x, tile_z, enemy_type |
| `MapChest.gd` | MapChest | entity_id, tile_x, tile_z, card_ids (PackedStringArray) |
| `MapDoor.gd` | MapDoor | entity_id, tile_x, tile_z, target_map, target_door_id, flag_key |
| `MapNpc.gd` | MapNpc | entity_id, tile_x, tile_z, dialogue, npc_type, flag_key, after_dialogue |
| `MapScroll.gd` | MapScroll | entity_id, tile_x, tile_z, scroll_id, flag_key |
| `MapTrigger.gd` | MapTrigger | entity_id, tile_x, tile_z, event_id, flag_key, once |
| `MapRegion.gd` | MapRegion | region_id, region_name, region_type, tile_x, tile_z, tile_width, tile_height |

Design decisions:
- Entity positions stored in **tile coordinates** (not world coords) — TID-049 multiplies by TILE_SIZE at load time
- Runtime state (alive, tracking, opened) NOT stored — set as defaults in TID-049's load_from_resource()
- `MapData.enemies/chests/...` are `Array[Resource]` (not typed sub-class arrays) to avoid forward-reference issues before Godot scans the class_names
- `MapTrigger` and `MapRegion` are new extensibility types — empty in all existing maps initially

## Documentation Updates

No agent doc changes needed for this task — TID-053 updates `named-maps-and-dungeons.md` once the full migration is complete.
