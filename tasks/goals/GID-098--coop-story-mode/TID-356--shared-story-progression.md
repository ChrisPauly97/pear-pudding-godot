# TID-356: Shared story progression & flag arbitration

**Goal:** GID-098
**Type:** agent
**Status:** done
**Depends On:** TID-355

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

For the party to experience the story coherently, story flags must be **shared**, not
per-device, and one-time story beats must fire **exactly once** for the party (not N
times, once per peer). Today story flags are local to `SaveManager`, and adoption of a
session character forces `_loaded = false`, so flag writes never persist for co-op.

## Research Notes

- **Flag reads today:** NPCs/scenes call `SaveManager.get_story_flag(key)` /
  `set_story_flag(key, value)`. `TownspersonNPC.get_dialogue()` (line ~54) gates on
  `SaveManager.get_story_flag(_flag_key)`.
- **Shared store exists:** `SessionState.story_flags` is already a declared shared-world
  field (GID-095, see `docs/agent/multiplayer-coop.md` → "Persistent Sessions"). It is
  authority-owned and persisted via `SessionStore` into
  `user://sessions/<id>.json`, isolated from `save_slot_*.json`.
- **Bridge needed:** route `get_story_flag` / `set_story_flag` through the session when
  `NetworkManager.is_active()`:
  - Read: prefer `SessionState.story_flags` (so all peers agree).
  - Write: send an intent to the authority; the authority sets the flag in
    `SessionState`, persists (mark_dirty), and **broadcasts** the change so every
    client's view updates. Mirror the GID-096 `submit_world_event` / `recv_world_event`
    RPC pattern on `NetSync`.
  - Single-player (no session): unchanged — write/read local `SaveManager`.
- **Arbitration:** a story beat (e.g. a cutscene/narration/flag set on first NPC
  interaction) must fire once. Pattern: the **authority** owns "has this beat fired";
  a client requesting a beat is a no-op if the authority already recorded it. Use the
  flag itself as the idempotency key — `if already set: skip side-effects`.
- **Watch:** `SaveManager.adopt_session_character` forces `_loaded = false` so
  `save()`/`_flush_if_dirty` are no-ops — never persist co-op story flags into the
  single-player save. Story flags persist via `SessionStore`, not `SaveManager`.
- **Story flag surface:** grep `set_story_flag` / `get_story_flag` across `scenes/`,
  `autoloads/`, and `docs/agent/story-implementation.md` to enumerate every beat that
  needs to be co-op-aware (chapter completion, NPC-met flags, etc.).

## Plan

**Model chosen:** GameBus bridge + authority arbitration. `GameBus.story_flag_set` fires for every local `set_story_flag` call. The new `_on_local_story_flag_set` handler routes the change through the co-op session: hosts write to `SessionState` + broadcast `recv_story_flag`; clients submit to authority via `submit_story_flag`. Idempotency key: if the flag already has the same value in `SessionState`, the authority skips the broadcast.

**Changes:**

1. `NetSync.gd` — added `recv_story_flag`, `submit_story_flag`, `recv_story_flags_snapshot`.
2. `WorldScene.gd` — added `_coop_story_flag_syncing` guard; `_on_local_story_flag_set`, `_on_story_flag_received`, `_on_story_flag_submitted`, `_on_story_flags_snapshot_received`, `_send_story_flags_snapshot_to_peer`; `_setup_session` restores session flags on host resume.
3. `tests/unit/test_coop_story_flags.gd` — unit tests for flag dict round-trip and idempotency logic.

## Changes Made

- `scenes/world/NetSync.gd` — 3 new reliable RPCs: `recv_story_flag`, `submit_story_flag`, `recv_story_flags_snapshot`.
- `scenes/world/WorldScene.gd`:
  - `_coop_story_flag_syncing: bool` guard (prevents re-entrant broadcast when receiving a flag already sets it locally via GameBus).
  - `_on_local_story_flag_set(key)` — host writes to SessionState + broadcasts; client submits to authority.
  - `_on_story_flag_received(key, value)` — applies flag to local `save_manager.story_flags` and SessionState, emits GameBus guarded by `_coop_story_flag_syncing`.
  - `_on_story_flag_submitted(sender, key, value)` — authority arbitrates with idempotency check, updates SessionState, broadcasts.
  - `_on_story_flags_snapshot_received(flags)` — client joining late: applies all session flags at once.
  - `_send_story_flags_snapshot_to_peer(peer_id)` — host sends snapshot to a just-joined peer.
  - `_setup_session` extended: restores `SessionState.story_flags` into `save_manager.story_flags` when host re-enters a saved co-op session.
- `tests/unit/test_coop_story_flags.gd` — new unit tests.

## Documentation Updates

- `docs/agent/multiplayer-coop.md` updated with GID-098 co-op story mode section.
