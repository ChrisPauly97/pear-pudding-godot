# TID-682: Town buildings: shared materials, merged trim, off-main-thread build

**Goal:** GID-164
**Type:** agent
**Status:** done
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

- Measured first: the build was a 7.2 ms main-thread hitch (25 buildings).
- Worker: `_build_meshes` (RealmLayout plans are warmed; BuildingMesh is pure) builds roofs and merges trim per town via SurfaceTool.append_from; `tick` commits nodes once the task completes; PREDELETE waits on a live task.
- Shared materials per texture; fades duplicate them (transparent), tween, then restore the shared opaque ones (mid-fade toggles reuse the copies, old tween killed).
- Trim: 25 nodes → one per town (5).

## Changes Made

- `scenes/world/TownBuildingsView.gd`.
- `tests/unit/test_town_buildings_view.gd`: merged trim vertex counts equal the per-building sum per surface; same-style roofs share a material.
- `town_life_smoke`: roof fades out with the hero inside, back in outside, ends on the shared opaque material (mutation-checked).
- Validation: import, gdlint, unsafe-hits, 3027 passed / 0 failed, 0 SCRIPT ERROR, all smoke tests.

## Documentation Updates

- `docs/agent/named-maps-and-dungeons.md` TownBuildingsView entry.
