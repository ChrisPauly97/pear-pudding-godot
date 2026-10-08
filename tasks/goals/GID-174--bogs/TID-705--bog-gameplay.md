# TID-705: Bog gameplay: slow, critters, enemies

**Goal:** GID-174
**Type:** agent
**Status:** pending
**Depends On:** TID-703

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

Bogs should matter to play.

## Research Notes

- Player speed × ~0.5 in bog (`Player._get_move_speed`), squelch footsteps (`FootstepSurface`), no mounting/auto-dismount.
- `TapToMove`/`Pathfinder`: bog = high-cost tile (shares the per-tile cost hook from TID-695 if done).
- Critters (`CritterDef`: frogs, flies) and a bog enemy entry in `EnemyRegistry` / `BiomeDef` pools.
- Tests + docs (world-generation.md).

Shared constraints: chunk-gen code (`InfiniteWorldGen`/`RealmLayout`/`TerrainMath`/`WaterMath`) runs on worker threads (BID-088) — pure, no autoloads/scene tree; lazily built statics go in `InfiniteWorldGen.warm()`. Explicit types (no `:=` on Variant), no unsafe access, preload scripts (no class_name), gdlint 120 cols, run `scripts/unsafe-hits.sh`, headless import, `godot --headless --path . -s tests/runner.gd` and check for `SCRIPT ERROR`. Docs: `docs/agent/world-generation.md`.

## Plan

_Written during Plan phase._

## Changes Made

_Filled after Build phase._

## Documentation Updates

_What was updated in agent docs._
