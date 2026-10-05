# TID-665: Coordinate Helpers

**Goal:** GID-157
**Type:** agent
**Status:** done
**Depends On:** —

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

See goal. `IsoConst.world_to_tile` truncated toward zero; many call sites re-implemented the conversion.

## Research Notes

- Tile-centre copies: `DungeonGen.gd` (14), `WorldMap.gd` fallback generator (6).
- Entity-dict → tile copies: `QuestLog`, `ObjectiveTracker`, `RealmLayout`, `TownStreets`, `TownLife`.
- Player-position → tile copies: `TownBuildingsView`, `RealmRegions`, `ChunkRenderer`.
- `TerrainMath` / `ChunkStreamingManager` vertex indexing and `Player` / `WorldEventManager` / `Critters` already
  floor correctly and mix in chunk math — left as is.

## Plan

Make `tile_to_world` / `world_to_tile` static, floor in `world_to_tile`, add `entity_tile(dict)`, replace copies.

## Changes Made

- `autoloads/IsoConst.gd`: `world_to_tile` floors (bug fix for negative coords), static; new `entity_tile()`.
- `DungeonGen.gd`, `WorldMap.gd`: tile centres via `IsoConst.tile_center`; dropped `DungeonGen.TILE_SIZE` copy.
- `QuestLog.gd` (`_overworld_target` helper), `ObjectiveTracker.gd`, `RealmLayout.gd`, `TownStreets.gd`,
  `TownLife.gd`, `TownBuildingsView.gd`, `RealmRegions.gd`, `ChunkRenderer.gd`: use the helpers.
- `tests/unit/test_iso_const.gd`: negative-coordinate + `entity_tile` tests.

## Documentation Updates

CLAUDE.md "Constants" section names `world_to_tile` / `entity_tile`.
