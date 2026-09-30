# TID-642: Stream flow direction

**Goal:** GID-152
**Type:** agent
**Status:** pending
**Depends On:** —

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

Stream ripples in `assets/shaders/terrain.gdshader` (~L343) drift in one fixed direction (`vec2(0.35,0.2)`), so streams shimmer instead of flowing. Part of GID-152 (art motion pass).

## Research Notes

- `game_logic/world/WaterMath.gd`: stream = band of `_stream` FastNoiseLite near 0 (`STREAM_WIDTH`), pond = `_pond` noise > `POND_LEVEL`. Add `flow_at(wx, wz, seed) -> Vector2`: central-difference gradient of stream noise, rotated 90° (along the band), normalised; sign made consistent (e.g. pick the orientation with +x / downhill preference) so neighbouring chunks agree. Ponds: zero flow.
- Speed factor: narrower band (|noise| close to 0 with steep gradient) → faster; derive from gradient magnitude, clamp 0.5–2.
- `scenes/world/ChunkRenderer.gd` L133-155 bakes ley (UV2.x) + water (UV2.y) per vertex via `TerrainMath` mesh builder (`ley_field`, `water_field`). Add a flow field (2 floats) — COLOR.rg or CUSTOM0 — through the same builder in `game_logic/TerrainMath.gd`. Must be deterministic from world coords (no chunk seams).
- Shader: replace the fixed ripple offset with `v_flow * speed * frame` (keep stepped `floor(TIME*4)/4` pixel look); stretch streaks along flow (rotate `wq` into flow space).
- Tests: extend `tests/unit/test_water_math.gd` (flow unit length in streams, zero in ponds, continuous across a chunk border).
- Validate: headless import, `scripts/unsafe-hits.sh`, gdlint, test runner.

## Plan

_Written during Plan phase._

## Changes Made

_Filled after Build phase._

## Documentation Updates

_What was updated in agent docs._
