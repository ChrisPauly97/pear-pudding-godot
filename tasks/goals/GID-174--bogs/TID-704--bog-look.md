# TID-704: Bog terrain look + props

**Goal:** GID-174
**Type:** agent
**Status:** done
**Depends On:** TID-703

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

Bogs should be visibly distinct.

## Research Notes

- Terrain shader: murky green-brown water band + peat tint (bake bog intensity into a vertex channel alongside UV2 water in `ChunkRenderer`).
- Props: dead trees (TreeScatter variant), reeds, mist (AmbientTouches ground mist), will-o'-wisp lights at night (`NightLights`).

Shared constraints: chunk-gen code (`InfiniteWorldGen`/`RealmLayout`/`TerrainMath`/`WaterMath`) runs on worker threads (BID-088) — pure, no autoloads/scene tree; lazily built statics go in `InfiniteWorldGen.warm()`. Explicit types (no `:=` on Variant), no unsafe access, preload scripts (no class_name), gdlint 120 cols, run `scripts/unsafe-hits.sh`, headless import, `godot --headless --path . -s tests/runner.gd` and check for `SCRIPT ERROR`. Docs: `docs/agent/world-generation.md`.

## Plan

Bake bog into CUSTOM0.z (packing extracted from TerrainMath into TerrainChannels — TerrainMath and ChunkRenderer are
lint debt, so both shrink); shader peat + murky pools; no tufts in pools; reeds round pools (edge-prop pass extracted
to WaterEdgeProps); dead trees in bogs. Validate the shader headless; tests.

## Changes Made

- New `game_logic/TerrainChannels.gd` (CUSTOM0 RG / RGB packing); `TerrainMath.build_terrain_mesh(.., bog_field)` (−3 lines).
- New `game_logic/world/WaterEdgeProps.gd` (moved from ChunkRenderer; + bog reeds); ChunkRenderer 836 → 802 lines with the bog field + pool grass skip.
- `assets/shaders/terrain.gdshader`: `v_bog`, pool vertex dip, peat / murk / scum / glint.
- `WaterMath`: `BOG_REED_*`, `BOG_DEAD_TREES`, `bog_prop`. `TreeScatter`: dead trees in bogs, none in pools.
- Tests: `test_bogs` +2 (CUSTOM0 packing; a real bog chunk through `prepare_terrain`: RGB CUSTOM0, pool vertices, no
  living trees in the bog, reeds/dead trees present). Shader validated headless (a planted typo is reported, the real
  shader is clean). Suite 3085 pass / 0 SCRIPT ERROR; world + chunk smokes clean; profiler noise only.
- Not verified visually (headless): the peat/pool colours should be eyeballed in a real run.

## Documentation Updates

`docs/agent/world-generation.md` (Bogs → Look).
