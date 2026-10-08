# TID-699: Cave site placement (pure logic)

**Goal:** GID-173
**Type:** agent
**Status:** done
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

InfiniteWorldGen sits at its 500-line cap: extract the ruin stamp into `RuinGen.gd` (same RNG stream), then add
`CaveSites.gd` (rocky-biome roll, off realm / ruin / landmark, mouth at the foot of the tallest reachable hill,
facing +X/+Z so it opens toward the camera) and one `add_to` call in `generate_chunk`. Tune by probing placement.

## Changes Made

- New `game_logic/world/RuinGen.gd` (`has_ruin`, `stamp`) — InfiniteWorldGen 500 → 410 lines.
- New `game_logic/world/CaveSites.gd` (`add_to`, `site_for`, `is_cave_map`); `InfiniteWorldGen.generate_chunk` calls it.
- Placement tuned by probe: steep faces (height ≥ 3 within 2 tiles) essentially never occur in the generated hills,
  so the mouth goes at the foot of the tallest hill instead; seed 42 ±25 chunks → 63 caves.
- `tests/unit/test_cave_sites.gd` (4). Suite 3074 pass / 0 SCRIPT ERROR; world + chunk smokes clean; gdlint + unsafe-hits clean.
- Found + fixed: `InfiniteWorldGen` couldn't compile in `-s` scripts (IsoConst function without a preload) — added the
  preload. Logged BID-091 for the remaining landmark ruin-roll mask mismatch.

## Documentation Updates

`docs/agent/world-generation.md` (RuinGen note, new Caves section).
