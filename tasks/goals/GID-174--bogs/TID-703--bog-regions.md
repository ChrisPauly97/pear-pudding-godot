# TID-703: Bog regions (pure logic)

**Goal:** GID-174
**Type:** agent
**Status:** done
**Depends On:** —

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

Bogs need a deterministic region query shared by rendering and gameplay.

## Research Notes

- Add `bog_at(wx, wz, seed)` 0..1 to `game_logic/world/WaterMath.gd` (second blob noise like ponds, own seed offset), only in Forest/Grasslands, only on level ground; faded off realm/structures like inland water (`structure_fade`, REALM_DRY_TILES).
- Must not overlap rivers (GID-172) — bog yields where river depth > 0.
- Tests: deterministic, none in towns/roads/desert.

Shared constraints: chunk-gen code (`InfiniteWorldGen`/`RealmLayout`/`TerrainMath`/`WaterMath`) runs on worker threads (BID-088) — pure, no autoloads/scene tree; lazily built statics go in `InfiniteWorldGen.warm()`. Explicit types (no `:=` on Variant), no unsafe access, preload scripts (no class_name), gdlint 120 cols, run `scripts/unsafe-hits.sh`, headless import, `godot --headless --path . -s tests/runner.gd` and check for `SCRIPT ERROR`. Docs: `docs/agent/world-generation.md`.

## Plan

`WaterMath.bog_at` / `bog_in` / `biome_has_bog`: a third noise ramped above BOG_LEVEL, faded by the full reserved
distance (towns, roads, rivers, sea), gated to grasslands + forest; tune coverage by probe; tests.

## Changes Made

- `WaterMath`: BOG_* consts, `_bog` noise in `_ensure`, `biome_has_bog`, `bog_in`, `bog_at`.
- Tuned BOG_LEVEL by probe: 0.42 → 1.8 %, 0.30 → 6.5 % (chosen), 0.26 → 8.8 % of grassland/forest.
- `tests/unit/test_bogs.gd` (3). Suite passes (see commit), gdlint clean.

## Documentation Updates

`docs/agent/world-generation.md` (Key Features + Bogs section).
