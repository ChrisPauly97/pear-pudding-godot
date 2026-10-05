# TID-678: Minor per-frame fixes: EnemyNPC meta, GrassBlades uploads, co-op enemy sync, downed banner

**Goal:** GID-164
**Type:** agent
**Status:** pending
**Depends On:** —

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

Small redundant per-frame work and network traffic. Part of GID-164 (3-agent perf audit, 2026-10-05).

## Research Notes

- `entities/EnemyNPC.gd:104-105` `set_meta(META_FAST, …)` every frame → only on state change.
- `scenes/world/GrassBlades.gd:276` `player_pos` global set every frame → only when moved; `:380` `_flush_trample_to_gpu` uploads whole texture every frame → only when dirty.
- `scenes/world/coop/CoopSession.gd:1367-1384` host sends every enemy pos at 5 Hz with `str(eid)` → per-enemy last-sent pos, send only moved > ~0.05 u, slow full resync (e.g. every 2-3 s). `:1400-1409` `_interp_synced_enemies` lerps forever incl. `get_terrain_height` → erase target within epsilon.
- `WorldScene.gd:1406-1409` downed banner formats text each frame → only when `int(ceil(remaining))` changes.
- Run co-op smoke tests + `world_scene_smoke` after.

Validation for every task: headless import parse check, `scripts/unsafe-hits.sh`, `gdlint`, `tests/runner.gd` (no `SCRIPT ERROR` in log), relevant smoke tests.

## Plan

_Written during Plan phase._

## Changes Made

_Filled after Build phase._

## Documentation Updates

_What was updated in agent docs._
