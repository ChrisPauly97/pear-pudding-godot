# TID-701: Cave interior theme for DungeonGen

**Goal:** GID-173
**Type:** agent
**Status:** done
**Depends On:** —

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

Cave interiors should feel different from built dungeons.

## Research Notes

- `game_logic/world/DungeonGen.gd` `generate(p_name, dungeon_seed)`: when name starts with `dungeon_cave_`, use an organic layout (cellular-automata caverns joined by tunnels) instead of rooms, keeping secret rooms (TILE_CRACKED) and mimic chests.
- Theme: stalagmite props, darker ambient, cave enemy pool (bats/golems from `EnemyRegistry._ensure_loaded`), ore/crystal chest loot. Ensure exit door + spawn connectivity test (flood fill).

Shared constraints: chunk-gen code (`InfiniteWorldGen`/`RealmLayout`/`TerrainMath`/`WaterMath`) runs on worker threads (BID-088) — pure, no autoloads/scene tree; lazily built statics go in `InfiniteWorldGen.warm()`. Explicit types (no `:=` on Variant), no unsafe access, preload scripts (no class_name), gdlint 120 cols, run `scripts/unsafe-hits.sh`, headless import, `godot --headless --path . -s tests/runner.gd` and check for `SCRIPT ERROR`. Docs: `docs/agent/world-generation.md`.

## Plan

New `CaveGen.gd` (cellular-automaton cavern, largest region, BFS-placed entrance / exit / dwellers / caches / rest,
stalagmites, secret room); `DungeonGen.generate` dispatches `dungeon_cave_*` to it, the old body becomes
`generate_rooms` (also the fallback). Chests flagged `crystal` get a pale-blue tint.

## Changes Made

- New `game_logic/world/CaveGen.gd`.
- `DungeonGen.generate` → dispatch; old layout is `generate_rooms`.
- `Chest.gd`: `CRYSTAL_TINT` for `crystal` chests.
- `tests/unit/test_cave_gen.gd` (3). Ad-hoc real-scene check: WorldScene on `dungeon_cave_31337` spawns 5 enemies,
  3 chests, player at the entrance, 0 SCRIPT ERROR. Suite 3079 pass / 0 SCRIPT ERROR; gdlint + unsafe-hits clean.
- Uses the existing enemy roster (no bespoke cave art); visual "dim mood" is the dungeon look as is.

## Documentation Updates

`docs/agent/named-maps-and-dungeons.md` (new Cave interiors section).
