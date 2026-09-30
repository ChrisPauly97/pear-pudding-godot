# TID-643: Stream foam and bank dressing

**Goal:** GID-152
**Type:** agent
**Status:** done
**Depends On:** TID-642

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

Streams have a flat one-texel shoreline only; add foam and pond dressing. Part of GID-152 (art motion pass).

## Research Notes

- Shader water block in `terrain.gdshader`: add foam pixels at shoreline (depth band 0) and where flow speed is high (narrows), animated along `v_flow`; blink with existing `blink` hash.
- Pond props: reeds / lily pads as new prop keys drawn in `tools/generate_sprites.py` (palette from `tools/pixel_palette.py`), registered via `SpriteRegistry.prop_variants()` preloads. ChunkRenderer `_compute_prop_positions` currently skips wet tiles (`WaterMath.wet_at` → continue); add a water-edge scatter pass for reeds (bank) and lily pads (pond only, flow == 0).
- New PNGs need `.import` via headless import; no `.uid` needed for png.

## Plan

1. Shader: foam flecks on the flow-map offsets, denser in narrows and at the bank.
2. `reed` / `lily_pad` props in `generate_sprites.py`, registered in `SpriteRegistry._PROP_VARIANTS`.
3. `WaterMath.edge_prop()` rule + `ChunkRenderer._compute_water_edge_props()` scatter.

## Changes Made

- `assets/shaders/terrain.gdshader`: foam in the flowing branch.
- `tools/generate_sprites.py`: `reed()`, `lily_pad()`; 6 new PNGs in `assets/textures/props/`.
- `game_logic/SpriteRegistry.gd`: preloads + variants for both keys.
- `game_logic/world/WaterMath.gd`: `edge_prop()` + `REED_*` / `LILY_*` constants.
- `scenes/world/ChunkRenderer.gd`: `_compute_water_edge_props()` merged into chunk props.
- Test: `test_water_math::test_edge_props_follow_the_water`. Rendered under xvfb to tune foam density.

## Documentation Updates

- `docs/agent/terrain-rendering.md`: "Foam and bank dressing".
