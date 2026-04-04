# TID-046: Define MapData Resource Schema

**Goal:** GID-017
**Type:** agent
**Status:** pending
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

_Written during Plan phase._

## Changes Made

_Filled after Build phase._

## Documentation Updates

_What was updated in agent docs._
