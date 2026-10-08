# TID-701: Cave interior theme for DungeonGen

**Goal:** GID-173
**Type:** agent
**Status:** pending
**Depends On:** —

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

Cave interiors should feel different from built dungeons.

## Research Notes

- `game_logic/world/DungeonGen.gd` `generate(p_name, dungeon_seed)`: when name starts with `dungeon_cave_`, use an organic layout (cellular-automata caverns joined by tunnels) instead of rooms, keeping secret rooms (TILE_CRACKED) and mimic chests.
- Theme: stalagmite props, darker ambient, cave enemy pool (bats/golems from `EnemyRegistry._ensure_loaded`), ore/crystal chest loot. Ensure exit door + spawn connectivity test (flood fill).

Shared constraints: chunk-gen code (`InfiniteWorldGen`/`RealmLayout`/`TerrainMath`/`WaterMath`) runs on worker threads (BID-088) — pure, no autoloads/scene tree; lazily built statics go in `InfiniteWorldGen.warm()`. Explicit types (no `:=` on Variant), no unsafe access, preload scripts (no class_name), gdlint 120 cols, run `scripts/unsafe-hits.sh`, headless import, `godot --headless --path . -s tests/runner.gd` and check for `SCRIPT ERROR`. Docs: `docs/agent/world-generation.md`.

## Plan

_Written during Plan phase._

## Changes Made

_Filled after Build phase._

## Documentation Updates

_What was updated in agent docs._
