# TID-351: Tests + docs (world sync)

**Goal:** GID-096
**Type:** agent
**Status:** done
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

- **Unit** `tests/unit/test_world_sync.gd` (18 cases, auto-run): EnemySync state/batch round-trip
  + interp (incl. static-target no-op); WorldObjectSync event + snapshot encode/decode, distinct
  kinds, short/garbage tolerance, id→string coercion.
- **Smoke** `tests/net_world_sync_smoke.gd` (+ `.uid`): real ENet loopback + live `SessionStore` —
  authority `enemy_removed`/`chest_opened` events + late-join snapshot + enemy position batch all
  reach the client via real NetSync RPCs and decode; a defeated enemy + opened chest persist into
  the session file and resume on reopen; `save_slot_*.json` proven untouched.
- **Single-player regression:** all of `tests/runner.gd` passes (1603), incl. existing enemy/chest
  unit suites — no co-op branch runs without a session.
- **Validation gate:** headless import clean; `tests/runner.gd` exit 0; `net_world_sync_smoke`,
  `net_coop_smoke`, `net_session_smoke`, `net_coop_npeer_smoke` all PASS.

## Documentation Updates

- `docs/agent/multiplayer-coop.md`: *Shared World-Object Sync (GID-096)* section + Tests table rows
  (`test_world_sync.gd`, `net_world_sync_smoke.gd`) + Limitations refresh.
- `docs/agent/enemies-and-npcs.md` + `docs/agent/treasure-maps.md`: co-op cross-link notes.
