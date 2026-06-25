# TID-346: Per-player character handshake & session-scoped progress

**Goal:** GID-095
**Type:** agent
**Status:** done
**Depends On:** TID-345

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

Wire the session model (TID-345) into the connect flow: on join, match the player's
identity token to a stored character (or create one), send it to the client, have
the client adopt it for the session, and persist changes back as the player plays.

## Research Notes

_To be expanded when TID-345 lands._

- On `peer_connected` (authority side), look up `SessionState.members[token]`
  (token from GID-094 identity handshake). Hit → send that character record;
  miss → create a seeded starter record (reuse the `ensure_coop_deck` starter, but
  now *persisted* in the session file, not transient).
- Client adopts the received record into the in-memory game state used for co-op:
  deck/inventory/coins/level/skills. This is **session state, not `save.json`** —
  the client must render/use it without clobbering the player's single-player save.
  Audit every place co-op reads `SaveManager` (deck, coins, skills, level) and route
  it through the session character when `NetworkManager.is_active()`.
- Persist-back: on relevant events (card gained, coins changed, level up, skill
  unlocked, position update) the authority updates the member record and marks the
  session dirty. Clients send intents to the authority (reliable RPC) — clients
  never write the file; only the authority does (single source of truth, reuses the
  GID-091 host-authoritative pattern).
- Reconnection resume is the payoff — verified in TID-348.
- CLAUDE.md: guard all by `is_active()`; reliable RPC for character/intent;
  reconnect to fresh state objects must reconnect their signals (see the GID-092
  `from_dict` signal-reconnect learning).

## Plan

1. **`SaveManager.adopt_session_character(record)`** — load the per-player session
   slice (owned_cards/_uid_index/player_deck/loadouts/coins/essence/xp/level/skills/
   magic/corruption/redemption) into the in-memory state co-op/PvP already read,
   **forcing `_loaded = false`** so `save()`/the 2 s flush stay no-ops — the hard
   isolation guarantee that `save_slot_*.json` is never written during a session.
   Plus **`export_session_character()`** to snapshot that slice back to a record dict.
2. **`NetSync`** — two reliable RPCs: `recv_character(record, resume)` (host→client)
   and `submit_character(record)` (client→host intent). Routed to WorldScene.
3. **WorldScene co-op:** host opens `SessionStore` with `MpProfile.get_host_session_id()`
   in `_setup_coop`, seeds shared world fields, ensures + adopts its own member record
   (resume = pre-existing). On a client's identity (`_on_identity_received`, host-only),
   look up/create the member by token, send `recv_character`. Client adopts on
   `_on_character_received`, restoring position on resume. Guard all by
   `NetworkManager.is_active()` / `_session_adopted` (survives PvP re-attach).
4. **Persist-back:** a 5 s snapshot tick in `_process` — host writes its own member
   directly, clients `rpc_id(1, "submit_character", record)`; host merges by the
   peer→token map. Only the host writes the file (single source of truth).
5. Session end → host `flush_now()` + `close()`. Headless import + runner gate.

## Changes Made

- **`SaveManager.adopt_session_character(record)`** — loads the session character
  slice into the in-memory state co-op/PvP read (owned_cards/_uid_index/player_deck/
  loadouts/coins/essence/xp/level/skills/magic/corruption/redemption), **forcing
  `_loaded = false`** so `save()`/the flush stay no-ops → `save_slot_*.json` is never
  touched. **`export_session_character()`** snapshots that slice back to a record dict.
- **`scenes/world/NetSync.gd`** — two reliable RPCs: `recv_character(record, resume)`
  (host→client) and `submit_character(record)` (client→host), routed to WorldScene
  `_on_character_received` / `_on_character_submitted`.
- **`scenes/world/WorldScene.gd`** — session block (all host/`_session_adopted`-guarded):
  - `_setup_session()` (host): `SessionStore.open(MpProfile.get_host_session_id(), …)`,
    seeds shared world fields, ensures + adopts its own member, restores position on resume.
  - `_on_identity_received` (host branch): `_send_character_to_peer(sender, token, name)`
    — resolves the member by token (resume or fresh starter) and sends `recv_character`.
  - `_on_character_received` (client): adopts the record, restores position on resume.
  - `_on_character_submitted` (host): persists a client's snapshot by its token.
  - `_tick_session_persist` in `_process` (5 s): host writes its own member, clients
    `rpc_id(1, "submit_character", …)`; host merges via the `_session_token_by_peer` map.
  - Session lifecycle: flush on peer-disconnect; `flush_now()` + `close()` on session end;
    `_session_adopted` survives PvP re-attach (SessionStore stays open across battles).
- Validation: headless import clean; `tests/runner.gd` 1572 passed / 0 failed.

## Documentation Updates

Deferred to TID-348 (the goal's docs task).
