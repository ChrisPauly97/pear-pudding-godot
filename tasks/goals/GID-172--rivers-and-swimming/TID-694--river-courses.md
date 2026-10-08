# TID-694: River courses (pure logic)

**Goal:** GID-172
**Type:** agent
**Status:** done
**Depends On:** —

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

Rivers need a deterministic, chunk-independent course with depth so rendering, swimming and pathing all agree.

## Research Notes

- New `game_logic/world/Rivers.gd` (RefCounted, static). 2–3 seeded courses: start in Mountains-biome chunks (`InfiniteWorldGen.biome_for_chunk`, `BiomeDef.MOUNTAINS`=4), walk downhill/meander (low-freq noise) toward the eastern sea (`Coast.SHORE`, x≈43..262, z 43..146). Store as polylines of world tiles; built once in `InfiniteWorldGen.warm()`.
- API: `depth(wx, wz, seed)` signed tiles (>0 in river; deep core ≥ `Coast.WADE_DEPTH` 1.5), `flow(wx, wz)` downstream unit vector × speed, `width_at` growing downstream. Fords at crossings with `RealmLayout.ROADS` (road_distance) — shallow there; bridges are TID-695.
- Hook into `WaterMath.intensity`/`water_at`/`flow_at` (max with inland/sea water) so existing grass/props/splash code respects it; `RealmLayout.reserved_distance` so trees/ruins/spawns stay off rivers; rivers must not cut through stitched towns (`RealmLayout.town_at_tile`) — route around or stop.
- Per-query cost matters (WaterMath is hot in chunk prep): use a spatial bucket grid of segments, measure with `Time.get_ticks_usec()` (GID-164 lesson).
- Tests: determinism per seed, river reaches the sea, never enters a town, depth/flow continuity across chunk borders.

Shared constraints: chunk-gen code (`InfiniteWorldGen`/`RealmLayout`/`TerrainMath`/`WaterMath`) runs on worker threads (BID-088) — pure, no autoloads/scene tree; lazily built statics go in `InfiniteWorldGen.warm()`. Explicit types (no `:=` on Variant), no unsafe access, preload scripts (no class_name), gdlint 120 cols, run `scripts/unsafe-hits.sh`, headless import, `godot --headless --path . -s tests/runner.gd` and check for `SCRIPT ERROR`. Docs: `docs/agent/world-generation.md`.

## Plan

Deviation from research notes: courses are **fixed realm geography** (like `RealmLayout.ROADS` and `Coast.SHORE`), not seeded —
`RealmLayout.reserved_distance` takes no seed, co-op needs no extra sync, and the sources are made mountains by forcing the biome.

1. `game_logic/world/Rivers.gd` (pure, static): three hand-routed control polylines (north, west, south) ending inside the sea;
   built once (mutex, also from `InfiniteWorldGen.warm`) into a Catmull-Rom curve with a sine meander, then segments bucketed in
   8-tile cells (each cell lists segments within `REACH` tiles), so a query scans one cell.
   API: `depth(px, pz)` (signed tiles, + inside; half-width grows source→mouth; capped shallow at road fords), `tile_depth`,
   `is_deep`, `water(wx, wz)` (sea-style intensity), `flow(wx, wz)`, `reserved_distance`, `touches_chunk`, `source_chunk`.
2. `RealmLayout.reserved_distance` / `stamp_tile_in` / `chunk_touches_realm` include rivers (bank never 0 → never paved; valley
   flattened over BLEND_MARGIN; trees/ruins/spawns keep off). `reserved_distance(.., rivers=false)` for the stream fade so streams
   behave the same in realm-clear and other chunks (no seams).
3. `WaterMath`: river water folded in after the fades like the sea (`intensity`, `water_at`, `wet_at`), `flow_at` returns the river current.
4. `InfiniteWorldGen.biome_for_chunk`: chunks round a source → Mountains; river chunks in a dry biome → Grasslands (so the water draws).
5. `tests/unit/test_rivers.gd`: reaches the sea, keeps off towns/camps/spots/sites, fords at the road crossing, depth/flow continuity, deep downstream, biome rules.

## Changes Made

- New `game_logic/world/Rivers.gd`: three fixed courses (north / west / south), Catmull-Rom + faded sine meander, two
  bucket tables (REACH 13 for depth/reserved, NEAR 5 for water/flow), fords at road crossings, `biome_for`, `water_reserved`.
- `RealmLayout`: `reserved_distance(wtx, wtz, rivers = true)`; `stamp_tile_in` and `chunk_touches_realm` include rivers.
- `WaterMath`: `sea_at` = max(sea, river); `flow_at` returns the river current; stream fade / realm-clear proof use
  `reserved_distance(.., false)`; `edge_prop_ok` excludes only the sea.
- `InfiniteWorldGen.biome_for_chunk` routes noise / safe-zone biomes through `Rivers.biome_for`.
- `tests/unit/test_rivers.gd` (8 tests; ford test mutation-checked). Full suite 3060 pass, 0 SCRIPT ERROR; world/chunk/town smokes clean;
  gdlint + unsafe-hits clean (RealmLayout / InfiniteWorldGen kept at the 500-line cap, no pragma).
- Perf (`tools/profile_world.gd`, 900 frames): p50 6.91 → 6.89 ms, chunk generate unchanged within noise; river water lookup ~1.7 µs.

## Documentation Updates

`docs/agent/world-generation.md` (Key Features + new Rivers section); CLAUDE.md map note.
