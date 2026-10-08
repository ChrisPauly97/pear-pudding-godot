# TID-700: Cave mouth visuals + door

**Goal:** GID-173
**Type:** agent
**Status:** pending
**Depends On:** TID-699

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

Caves must read clearly in the iso view.

## Research Notes

- Rock arch mesh (ArrayMesh/SurfaceTool like Coastline/BuildingMesh) with a black interior quad, rubble props; torch glow at night via `NightLights` rig.
- Door behaviour reuses the existing Door entity / map stack (`docs/agent/named-maps-and-dungeons.md` → Map Stack Navigation); interaction via `INTERACT_PRIORITY` door entry.
- Minimap/realm map icon.

Shared constraints: chunk-gen code (`InfiniteWorldGen`/`RealmLayout`/`TerrainMath`/`WaterMath`) runs on worker threads (BID-088) — pure, no autoloads/scene tree; lazily built statics go in `InfiniteWorldGen.warm()`. Explicit types (no `:=` on Variant), no unsafe access, preload scripts (no class_name), gdlint 120 cols, run `scripts/unsafe-hits.sh`, headless import, `godot --headless --path . -s tests/runner.gd` and check for `SCRIPT ERROR`. Docs: `docs/agent/world-generation.md`.

## Plan

_Written during Plan phase._

## Changes Made

_Filled after Build phase._

## Documentation Updates

_What was updated in agent docs._
