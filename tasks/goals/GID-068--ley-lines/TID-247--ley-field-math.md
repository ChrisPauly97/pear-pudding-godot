# TID-247: Ley Line Field Math — Deterministic Position → Intensity Function

**Goal:** GID-068
**Type:** agent
**Status:** pending
**Depends On:** —

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

Everything else in this goal — shader rendering, player speed boost, the Attuned battle buff, Mana Well placement — queries one pure function: "how ley-charged is this world position?". It must be cheap (called per physics frame for the player and per texel for the minimap), deterministic per seed, and headless-testable.

## Research Notes

**Where it lives:**
- `game_logic/TerrainMath.gd` is the canonical home for shared terrain math (CLAUDE.md: never duplicate terrain algorithms — add methods there). Add static functions; no autoload state.

**The math — ridged noise bands:**
- Lines = the near-zero set of a simplex noise field: `intensity = 1.0 - abs(noise.get_noise_2d(wx * f, wz * f)) / threshold`, clamped to 0–1. Where `|noise| < threshold` you're "on" a line; the abs() ridge makes thin snaking bands rather than blobs.
- Low frequency (~0.01 in world units) so lines span many chunks (CHUNK_SIZE=16 × TILE_SIZE=2.0 = 32 units per chunk) and feel like geography, not texture.
- Threshold ~0.04–0.06 of the noise range gives bands roughly 1–2 tiles wide covering a few percent of the map — tune with a headless coverage test.
- Intersections: use a SECOND independent noise channel (different seed offset, slightly different frequency). A point is an intersection when BOTH channels are below threshold — rare, point-like loci.

**Suggested API (all static, all pure):**
- `static func ley_intensity(wx: float, wz: float, world_seed: int) -> float` — 0..1, primary channel.
- `static func is_on_ley_line(wx: float, wz: float, world_seed: int) -> bool` — intensity > 0.
- `static func ley_intersection_strength(wx: float, wz: float, world_seed: int) -> float` — min of both channels' intensities (>0 means intersection zone).
- Noise caching: cache `FastNoiseLite` instances per seed in static vars, exactly like `InfiniteWorldGen._get_biome_noise()` does (`static var _noise; static var _noise_seed: int = -1; rebuild when seed differs`). Seed channels with distinct offsets (e.g. `world_seed + 424243`, `world_seed + 868687`).

**Constants:**
- Frequencies, thresholds, and seed offsets must be exported as named constants — TID-248 has to port the SAME math into shader code with identical values, and TID-249/InfiniteWorldGen consume them for well placement. Keeping them in one constants block (TerrainMath or IsoConst — IsoConst is the project's canonical constants home, but these are math-internal; TerrainMath consts referenced by others is acceptable, document the choice).

**GDScript strict mode:**
- `abs`/`min`/`max`/`clamp` return Variant on mixed args — annotate explicitly: `var v: float = clamp(x, 0.0, 1.0)`.

**Testing (headless, tests/ with the GUT runner — `godot --headless --path . -s tests/runner.gd`):**
- Determinism: same (pos, seed) twice → identical result; different seeds → different fields.
- Coverage: sample a large grid (e.g. 200×200 points over several chunks); fraction with `is_on_ley_line` should land in a tuned band (~2–8%).
- Intersections strictly rarer than lines; every intersection point is also on both lines.
- Cache correctness: switching seeds back and forth returns consistent values.

## Plan

_Written during Plan phase._

## Changes Made

_Filled after Build phase._

## Documentation Updates

_What was updated in agent docs._
