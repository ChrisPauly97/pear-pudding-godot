# TID-702: Retire ruin dungeon doors, tests & docs

**Goal:** GID-173
**Type:** agent
**Status:** done
**Depends On:** TID-700, TID-701

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

Make caves the way underground.

## Research Notes

- `_gen_ruins`: stop emitting DOOR entities (keep walls/crumbles). Old saves with `dungeon_<n>` in the map stack must still load (DungeonGen still handles plain prefix).
- Note `InfiniteWorldGen` line ~105 replicates the ruin RNG check for other placement — keep RNG order unchanged so the world doesn't reshuffle.
- Tests + docs: world-generation.md (Ruins + Caves), named-maps-and-dungeons.md (cave theme).

Shared constraints: chunk-gen code (`InfiniteWorldGen`/`RealmLayout`/`TerrainMath`/`WaterMath`) runs on worker threads (BID-088) — pure, no autoloads/scene tree; lazily built statics go in `InfiniteWorldGen.warm()`. Explicit types (no `:=` on Variant), no unsafe access, preload scripts (no class_name), gdlint 120 cols, run `scripts/unsafe-hits.sh`, headless import, `godot --headless --path . -s tests/runner.gd` and check for `SCRIPT ERROR`. Docs: `docs/agent/world-generation.md`.

## Plan

RuinGen stops appending ruin DOOR entities (keeps the gaps and the RNG stream); a `ChunkData.has_ruin` flag replaces
"has doors" as ChunkRenderer's cue to keep the courtyard dry. Old `dungeon_<n>` saves keep working (DungeonGen + the
overworld position-token return). Test, docs.

## Changes Made

- `RuinGen.stamp`: no door entities; gaps renamed; sets `chunk.has_ruin`.
- `ChunkData.has_ruin`; `ChunkRenderer.water_dry_points` keys the courtyard footprint on it (or doors, as before).
- `test_cave_sites.test_ruins_are_scenery_now` (stitched town doors such as Marsax Hold's war camp are exempt).
- Suite 3080 pass / 0 SCRIPT ERROR; world, chunk, swim smokes clean; gdlint + unsafe-hits clean.

## Documentation Updates

`docs/agent/world-generation.md` (Key Features, Ruins steps); CLAUDE.md map note.
