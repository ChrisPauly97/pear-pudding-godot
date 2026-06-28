# TID-349: Authoritative enemy & encounter sync

**Goal:** GID-096
**Type:** agent
**Status:** done
**Depends On:** GID-094

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

The single biggest sync task: make enemies authority-owned and visible/shared to
all players, with synced positions and defeat state. Enemies are currently
spawned and simulated per-instance with no networking.

## Research Notes

_To be expanded when GID-094 lands._

- **Survey first:** how WorldScene spawns/owns enemies today (the `Entities` node,
  `_enemy_nodes[id]` registry referenced in GID-090 research, enemy AI in
  `scenes/world/` / `game_logic/`). Identify the wander/track/engage AI
  (`docs/agent/enemies-and-npcs.md`) and where defeat is recorded
  (`SaveManager.defeated_enemies`).
- **Model:** authority owns enemy spawns + AI; broadcast enemy state (id, type,
  pos, facing, hp/alive) at a low Hz with interpolation, reusing the AvatarSync
  interp helper / a sibling `EnemySync` pure helper. Clients render display-only
  enemy nodes (like RemotePlayer) — no local AI when in a session.
- **Encounter rule (decide + document):** what happens when player A starts a
  battle with a shared enemy? Options: enemy becomes "engaged/locked" for others;
  or each player fights their own instance. Pick the simplest coherent rule and
  write it in the goal/docs. Defeat marks the enemy down for all and records into
  the session file (GID-095) — not `save.json`.
- **Guarding:** single-player path (no session) keeps local AI + local
  `defeated_enemies`. All net code behind `NetworkManager.is_active()` /
  `_coop_active`.
- This task may be split if it grows (separate spawn-ownership vs AI-sync vs
  battle-trigger). Flag during Plan.

## Plan

**Survey conclusions:**
- Co-op runs on **madrian**, a town map with `enemies = []` and `chests = []`. So the
  sync must be **generic** (any named map's enemies/chests), exercised by tests via
  synthetic state — there is no live madrian enemy to lean on.
- Named-map enemies are **static** (`EnemyNPC` has a proximity `Area3D`, no wander AI;
  wandering is infinite-world only: roaming boss / nocturnal — both out of co-op scope).
  They are spawned **deterministically** by `ChunkRenderer` from the shared `.tres`, so
  every peer already has identical enemy nodes at identical positions. Live sync therefore
  only needs **discrete lifecycle** (engaged → removed, defeated → persisted); positions
  are correct by construction. An `EnemySync` position-stream helper + low-Hz broadcast is
  added for forward-compat (future moving enemies) and to satisfy "positions sync,
  interpolated", verified end-to-end by the smoke test.
- `EnemyNPC.engage()` emits `GameBus.enemy_engaged(edata)` then frees itself. The engaging
  player goes into a **solo AI battle** (PvP is separate). On win, `SceneManager._on_battle_won`
  marks `SaveManager.mark_enemy_defeated(id)` (in-memory only for co-op — adopt forces
  `_loaded=false`, so save.json is untouched).

**Encounter rule (chosen + documented): engage-locks / first-engager-takes.**
The first player to reach an enemy fights it solo vs AI; the enemy is **removed for everyone
immediately** (authority broadcast). A **win** persists the defeat into the GID-095 session
file (stays gone after reconnect). A **loss/flee** leaves it gone for the live session but it
**returns on reconnect** (not persisted) — exactly single-player semantics.

**Steps:**
1. `game_logic/net/EnemySync.gd` — pure: `encode_state(id,x,z,alive)` / `decode_state`,
   `encode_batch`/`decode_batch`, `interp` (mirrors AvatarSync). Unit-tested.
2. `NetSync` RPCs: `recv_world_event(kind,id)` (authority→clients, reliable),
   `submit_world_event(kind,id)` (client→authority intent, reliable),
   `recv_world_snapshot(payload)` (authority→joining client, reliable),
   `recv_enemy_positions(payload)` (authority→clients, unreliable_ordered).
3. WorldScene hooks (all guarded by `_coop_active`):
   - `_on_enemy_engaged_coop(edata)`: host broadcasts `enemy_removed`; client submits
     `enemy_engaged`. Stores `_coop_last_engaged_enemy_id` for defeat persistence.
   - `_on_battle_won` (co-op branch): persist defeat into session (host) / submit
     `enemy_defeated` (client).
   - `_on_world_event_submitted` (host): apply engage/defeat/chest intents.
   - `_on_world_event_received` (peer): remove enemy node / mark chest opened.
   - `_coop_apply_world_progress(defeated, opened)`: remove already-resolved nodes on
     host resume + client snapshot.
   - host `_setup_session`: apply session world-progress; `_send_world_snapshot_to_peer`
     on client identify.
   - low-Hz `_broadcast_enemy_positions` (host) + client-side interp in `_process`.
4. (Chest/object sync detail lives in TID-350, which shares the same RPCs.)

This task and TID-350 are tightly coupled (one RPC pair, one helper family) and are built
together in this session; TID-351 adds tests + docs.

## Changes Made

- **New pure helper** `game_logic/net/EnemySync.gd` (+ `.uid`): `encode_state`/`decode_state`,
  `encode_batch`/`decode_batch`, `interp` for the enemy position stream (mirrors AvatarSync).
- **`scenes/world/NetSync.gd`**: added 4 RPCs — `recv_world_event` / `submit_world_event`
  (reliable), `recv_world_snapshot` (reliable), `recv_enemy_positions` (unreliable_ordered).
- **`scenes/world/WorldScene.gd`** (all guarded by `_coop_active`):
  - `_on_enemy_engaged_coop` (connected to `GameBus.enemy_engaged`) broadcasts `enemy_removed`
    (host) / submits `enemy_engaged` (client) — **engage-locks**; stores
    `_coop_last_engaged_enemy_id`.
  - `_on_battle_won` → `_coop_persist_enemy_defeat()` persists a win into the session file
    (host) / submits `enemy_defeated` (client). `_coop_record_enemy_defeated` writes
    `SessionState.defeated_enemies`.
  - `_on_world_event_received` / `_on_world_event_submitted` apply peer/authority events;
    host fans a client's engage out to every other peer.
  - `_setup_session` (host) + `_on_world_snapshot_received` (client) call
    `_coop_apply_world_progress` to remove already-resolved enemies; `_send_world_snapshot_to_peer`
    sent on client identify.
  - `_broadcast_enemy_positions` (host, 5 Hz) + `_interp_synced_enemies` (clients) in `_process`;
    new state reset in `_on_coop_session_ended`.
- Encounter rule decided + documented: **engage-locks / first-engager-takes** (win persists,
  loss returns on reconnect).
- Validation: headless import clean; `tests/runner.gd` 1603 pass (incl. 18 new world-sync unit
  cases); `net_world_sync_smoke.gd` PASS; co-op/session/npeer smoke regressions PASS.

## Documentation Updates

- `docs/agent/multiplayer-coop.md`: new *Shared World-Object Sync (GID-096)* section
  (encounter rule, helpers, RPCs, authority flow), header/Limitations/Tests updates.
- `docs/agent/enemies-and-npcs.md`: co-op note (engage-locks, session-file defeat persistence).
