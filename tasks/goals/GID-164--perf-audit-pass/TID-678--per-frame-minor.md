# TID-678: Minor per-frame fixes: EnemyNPC meta, GrassBlades uploads, co-op enemy sync, downed banner

**Goal:** GID-164
**Type:** agent
**Status:** done
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

- EnemyNPC: META_FAST written only when the chase state flips.
- GrassBlades: `player_pos` global only when the push value changes; trample texture uploaded only when a byte actually changed (decay floors and stamps saturate, so a still hero uploads nothing).
- Co-op: host sends only enemies moved ≥ 0.05 since their last send + full resync every 3 s (unreliable channel, so the resync covers drops); client drops a converged interp target.
- Downed banner text reformatted only when the second changes.

## Changes Made

- `scenes/world/entities/EnemyNPC.gd`, `scenes/world/GrassBlades.gd`, `scenes/world/coop/CoopSession.gd`, `scenes/world/WorldScene.gd`.
- Validation: import, gdlint, unsafe-hits, 3022 passed / 0 failed, 0 SCRIPT ERROR, all 44 smoke tests (incl. net_world_sync_smoke).

## Documentation Updates

- `docs/agent/multiplayer-coop.md` position stream.
