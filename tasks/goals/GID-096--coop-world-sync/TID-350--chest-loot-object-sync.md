# TID-350: Chest / loot / world-object state sync + persist into session file

**Goal:** GID-096
**Type:** agent
**Status:** done
**Depends On:** GID-095, TID-349

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

Sync the state of lootable/interactable world objects (chests, dig spots, etc.) so
opening one reflects for all players, and persist that state into the GID-095
session file so it survives reconnect.

## Research Notes

_To be expanded when TID-349 + GID-095 land._

- **Survey:** chest open state (`SaveManager.opened_chests`), dig spots
  (`docs/agent/treasure-maps.md`), and other interactables spawned in WorldScene's
  `Entities`. Determine which are per-player vs shared. Chests/loot are shared
  world state; loot *rewards* go to the per-player character (GID-095) of whoever
  opens it (decide + document: first-opener-takes, or each player loots once).
- **Model:** authority owns object state; a small `WorldObjectSync` (pure helper
  for encode/decode) + reliable RPC for state changes (open/close is discrete, not
  continuous — reliable, not interpolated). Clients reflect the authority's state.
- **Persistence:** opened/looted state writes into the `SessionState` world-progress
  block (GID-095 / TID-345), not `save.json`. Resume on reconnect.
- Reuse the GID-091 host-authoritative intent → apply → broadcast pattern.
- Guard by `is_active()`; single-player unchanged.

## Plan

Shares the RPC pair + snapshot from TID-349 (`recv_world_event` / `submit_world_event` /
`recv_world_snapshot`). Adds the **discrete object** path.

**Survey:** chest open is handled in `WorldScene._handle_interact` — it marks the chest opened
(`SaveManager.mark_chest_opened`), calls `node.mark_opened()`, and spawns loot (cards/coins/
equipment) for the opener. `Chest.gd` has `mark_opened()`. Dig spots: a single active `DigSpot`
tied to a per-player treasure map (per-player, **not** shared world state) — left out of shared
sync. Mimic chests route through `enemy_engaged` (already covered by the enemy path).

**Loot rule (chosen + documented): first-opener-takes.** The player who opens a chest gets the
loot (into their per-player GID-095 character — existing single-player drop code runs locally for
the opener only). Every other peer just sees the chest **flip to opened** (no loot). The chest can
never be looted twice.

**Pure helper:** `game_logic/net/WorldObjectSync.gd` — `encode_event(kind,id)` / `decode_event`,
`encode_snapshot(removed_enemies, opened_objects)` / `decode_snapshot`. Unit-tested.
(`recv_world_event` carries `[kind, id]`; `recv_world_snapshot` carries the two id lists.)

**Steps:**
1. `WorldObjectSync.gd` (above).
2. WorldScene chest-open branch: when `_coop_active`, after the local open, host persists into
   session `opened_chests` + broadcasts `chest_opened`; client submits `chest_opened` intent.
3. `_on_world_event_received("chest_opened", id)`: mark the local chest node opened (no loot).
4. `_on_world_event_submitted` host `chest_opened`: persist + mark host node + re-broadcast to
   other peers.
5. Persistence into the GID-095 `SessionState.opened_chests`; resume via
   `_coop_apply_world_progress` (host setup) and `recv_world_snapshot` (client join).

Built together with TID-349 in this session.

## Changes Made

- **New pure helper** `game_logic/net/WorldObjectSync.gd` (+ `.uid`): `encode_event`/`decode_event`
  (kinds `enemy_engaged`/`enemy_removed`/`enemy_defeated`/`chest_opened`) and
  `encode_snapshot`/`decode_snapshot` for late-join reconciliation (shared with the enemy path).
- **`scenes/world/WorldScene.gd`**: the chest-open branch of `_handle_interact` now calls
  `_on_chest_opened_coop(cid)` after the local open — host persists into
  `SessionState.opened_chests` + broadcasts `chest_opened`; a client submits the intent (host
  persists + re-broadcasts to other peers). `_coop_record_chest_opened` writes the session file;
  `_coop_mark_chest_opened_node` flips a peer's chest node to opened **without** dropping loot
  (first-opener-takes — the opener's existing local drop code still runs).
- Opened chests reconcile on host resume (`_setup_session` → `_coop_apply_world_progress`) and
  client join (`recv_world_snapshot`); state cleared in `_on_coop_session_ended`.
- Loot rule decided + documented: **first-opener-takes** (loot goes to the opener's per-player
  GID-095 character; peers only see the chest open).
- Dig spots intentionally excluded (per-player treasure-map state, not shared world).
- Validation: covered by `tests/net_world_sync_smoke.gd` (chest_opened event + opened-chest
  persistence/resume) and `test_world_sync.gd` unit cases.

## Documentation Updates

- `docs/agent/multiplayer-coop.md`: loot rule + chest flow in the *Shared World-Object Sync* section.
- `docs/agent/treasure-maps.md`: co-op note clarifying dig spots are per-player (excluded from sync).
