# TID-247: Ley Line Field Math — Deterministic Position → Intensity Function

**Goal:** GID-068
**Type:** agent
**Status:** done
**Depends On:** —

## Context

Everything else in this goal — shader rendering, player speed boost, the Attuned battle buff, Mana Well placement — queries one pure function: "how ley-charged is this world position?". It must be cheap (called per physics frame for the player and per texel for the minimap), deterministic per seed, and headless-testable.

## Plan

Added three static functions to `game_logic/TerrainMath.gd` using ridged simplex noise bands (near-zero set). Two cached `FastNoiseLite` instances per seed (offsets 424243 and 868687). Named constants for frequencies, threshold, and seed offsets exported for consumers.

## Changes Made

- `game_logic/TerrainMath.gd`: added `LEY_FREQUENCY`, `LEY_FREQUENCY_B`, `LEY_THRESHOLD`, `LEY_SEED_OFFSET_A`, `LEY_SEED_OFFSET_B` constants; `_get_ley_noise_a`, `_get_ley_noise_b` cached getters; `ley_intensity`, `is_on_ley_line`, `ley_intersection_strength` static functions.
- `game_logic/TerrainMath.gd`: extended `build_terrain_mesh` with optional `ley_field: PackedFloat32Array` parameter; bakes UV2.x per vertex.
- `tests/unit/test_ley_lines.gd`: determinism, coverage, intersection, mana well, attuned flag tests.

## Documentation Updates

- Created `docs/agent/ley-lines.md`.
- Added row to CLAUDE.md documentation table.
