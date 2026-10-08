# TID-699: Cave site placement (pure logic)

**Goal:** GID-173
**Type:** agent
**Status:** pending
**Depends On:** —

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

Caves need deterministic placement in hilly/rocky terrain.

## Research Notes

- In `InfiniteWorldGen` (or new `game_logic/world/CaveSites.gd`): per chunk, seeded roll; candidate = TILE_WALL/high TILE_HILL cluster edge with a walkable tile in front. Weight by biome: Mountains/Scorched high, Forest low, none in Desert-flat/grasslands? (tune). Skip realm chunks (`RealmLayout.chunk_touches_realm`) and the sea.
- Output a `cave` entity in ChunkData with facing + `target_map` named `dungeon_cave_<seed>` so every existing `begins_with("dungeon_")` check (WorldScene 631/914, NamedMapProps 187, MapViewOverlay 335) keeps working.
- Tests: deterministic, never in towns/roads, always has a walkable approach tile.

Shared constraints: chunk-gen code (`InfiniteWorldGen`/`RealmLayout`/`TerrainMath`/`WaterMath`) runs on worker threads (BID-088) — pure, no autoloads/scene tree; lazily built statics go in `InfiniteWorldGen.warm()`. Explicit types (no `:=` on Variant), no unsafe access, preload scripts (no class_name), gdlint 120 cols, run `scripts/unsafe-hits.sh`, headless import, `godot --headless --path . -s tests/runner.gd` and check for `SCRIPT ERROR`. Docs: `docs/agent/world-generation.md`.

## Plan

_Written during Plan phase._

## Changes Made

_Filled after Build phase._

## Documentation Updates

_What was updated in agent docs._
