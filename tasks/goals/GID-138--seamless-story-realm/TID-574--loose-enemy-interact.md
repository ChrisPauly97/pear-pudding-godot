# TID-574: Script-Spawned Enemies Unreachable by Interact (Isfig)

**Goal:** GID-138
**Type:** agent
**Status:** done
**Depends On:** TID-572

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

User report: "Encounter Isfig doesn't work, nothing happens." Isfig (`rival_enc2`) stands
at `RealmLayout.STORY_SITES["isfig_road"]`, but walking up and interacting did nothing.

## Research Notes

- Rivals are non-tracking (`tracking: false`), so they never proximity-engage; the player
  must interact.
- `WorldScene._find_nearby_enemy` (since the ef7c4247 chunk-scan dedupe) only scans
  `ChunkData.enemies` of the 3×3 neighbour chunks. Enemies a script places straight into
  `_enemy_nodes` — story rivals (all three Isfig encounters), single-player siege raiders,
  co-op night-hunt spectres / siege waves / siege boss, nocturnal spectres — are in no
  chunk list, so interact never found them.

## Plan

Side table `_loose_enemy_nodes` + `register_loose_enemy(id, node)` on WorldScene;
`_find_nearby_enemy` falls back to it. Route every script spawn through it.

## Changes Made

- `WorldScene`: `_loose_enemy_nodes`, `register_loose_enemy()`, fallback scan in `_find_nearby_enemy`.
- `StoryCast`, `TownSiege`, `NocturnalSpawner`, `CoopActivities` (spectres, siege wave, siege boss)
  register via `register_loose_enemy`; their erase paths (and `CoopSession`'s) drop the entry too.
- `tests/unit/test_loose_enemy_interact.gd`.

## Documentation Updates

- None beyond this file (internal lookup detail).
