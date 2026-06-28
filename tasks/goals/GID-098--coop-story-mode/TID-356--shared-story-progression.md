# TID-356: Shared story progression & flag arbitration

**Goal:** GID-098
**Type:** agent
**Status:** pending
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

_Written during Plan phase._

## Changes Made

_Filled after Build phase._

## Documentation Updates

_What was updated in agent docs._
