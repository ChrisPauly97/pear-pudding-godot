# TID-682: Town buildings: shared materials, merged trim, off-main-thread build

**Goal:** GID-164
**Type:** agent
**Status:** pending
**Depends On:** —

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

~5 draw calls per house, unique materials, first-tick SurfaceTool hitch. Part of GID-164 (3-agent perf audit, 2026-10-05).

## Research Notes

- `scenes/world/TownBuildingsView.gd:61-77` — 3 new StandardMaterial3D per building + separate roof/trim meshes; SurfaceTool work all on first tick.
- Mesh code: `BuildingMesh` (GID-154), `TownBuildings`.
- Fix: one shared material per roof style; per-building copy (or instance shader param for alpha) only while a roof is fading; merge static trim per town into one mesh; build arrays in a WorkerThreadPool task, commit on main.
- Verify roof fade (player inside) still works; check `docs/agent/named-maps-and-dungeons.md` / visual-polish docs.

Validation for every task: headless import parse check, `scripts/unsafe-hits.sh`, `gdlint`, `tests/runner.gd` (no `SCRIPT ERROR` in log), relevant smoke tests.

## Plan

_Written during Plan phase._

## Changes Made

_Filled after Build phase._

## Documentation Updates

_What was updated in agent docs._
