# TID-351: Tests + docs (world sync)

**Goal:** GID-096
**Type:** agent
**Status:** pending
**Depends On:** TID-349, TID-350

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

Verify world-state sync and document it.

## Research Notes

_To be expanded as the goal lands._

- **Unit:** pure encode/decode round-trips for any `EnemySync` / `WorldObjectSync`
  helpers (mirror `test_coop_sync.gd`).
- **Smoke (real sockets):** `tests/net_world_sync_smoke.gd` — authority + client;
  enemy state broadcast reaches the client; defeating an enemy / opening a chest on
  the authority reflects on the client and persists into the session file; reconnect
  shows the dead enemy / open chest. Exit 0 = pass.
- **Single-player regression:** confirm enemy AI + chest opening unchanged with no
  session (run existing enemy/chest tests).
- Validation gate: headless import clean, `tests/runner.gd` exits 0.
- **Docs:** update `docs/agent/multiplayer-coop.md` (world-sync section, encounter
  rule, loot rule) and cross-link `enemies-and-npcs.md` / `treasure-maps.md` if
  their behavior now branches on `is_active()`.

## Plan

_Written during Plan phase._

## Changes Made

_Filled after Build phase._

## Documentation Updates

_What was updated in agent docs._
