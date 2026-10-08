# TID-700: Cave mouth visuals + door

**Goal:** GID-173
**Type:** agent
**Status:** done
**Depends On:** TID-699

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

Caves must read clearly in the iso view.

## Research Notes

- Rock arch mesh (ArrayMesh/SurfaceTool like Coastline/BuildingMesh) with a black interior quad, rubble props; torch glow at night via `NightLights` rig.
- Door behaviour reuses the existing Door entity / map stack (`docs/agent/named-maps-and-dungeons.md` → Map Stack Navigation); interaction via `INTERACT_PRIORITY` door entry.
- Minimap/realm map icon.

Shared constraints: chunk-gen code (`InfiniteWorldGen`/`RealmLayout`/`TerrainMath`/`WaterMath`) runs on worker threads (BID-088) — pure, no autoloads/scene tree; lazily built statics go in `InfiniteWorldGen.warm()`. Explicit types (no `:=` on Variant), no unsafe access, preload scripts (no class_name), gdlint 120 cols, run `scripts/unsafe-hits.sh`, headless import, `godot --headless --path . -s tests/runner.gd` and check for `SCRIPT ERROR`. Docs: `docs/agent/world-generation.md`.

## Plan

Cave doors (`kind` "cave") build a rock-arch mesh (`CaveMouth.gd`) instead of the door sprite; cave maps get cave
names. Night glow and the minimap dot already come from being a door. `Door.SPAWN_Y` replaces the 0.75 literal so the
arch can stand on the ground.

## Changes Made

- New `scenes/world/entities/CaveMouth.gd` (static `make(facing, y_offset)`).
- `Door.gd`: `_is_cave`, builds the mouth and hides the door mesh; `SPAWN_Y` const (ChunkRenderer uses it).
- `PlaceNames.CAVE_NOUNS` + cave titles for `dungeon_cave_*`.
- Tests: `test_cave_sites` +2 (mouth orientation/placement, door flag + names); ad-hoc real-tree check: Door.tscn with
  cave data builds the CaveMouth and hides the door mesh. Suite 3076 pass / 0 SCRIPT ERROR; world smoke clean.
- Not verified visually (headless): the arch's look against the hillside should be eyeballed.

## Documentation Updates

`docs/agent/world-generation.md` (Caves → Mouth).
