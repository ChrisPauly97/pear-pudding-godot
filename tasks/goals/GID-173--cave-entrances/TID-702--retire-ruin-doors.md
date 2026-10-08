# TID-702: Retire ruin dungeon doors, tests & docs

**Goal:** GID-173
**Type:** agent
**Status:** pending
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

_Written during Plan phase._

## Changes Made

_Filled after Build phase._

## Documentation Updates

_What was updated in agent docs._
