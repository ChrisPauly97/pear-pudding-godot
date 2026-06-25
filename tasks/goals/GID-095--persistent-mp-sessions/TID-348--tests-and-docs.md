# TID-348: Tests + docs (persistence, handshake, reconnect)

**Goal:** GID-095
**Type:** agent
**Status:** pending
**Depends On:** TID-345, TID-346, TID-347

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

Verify session persistence and lock the design into the docs.

## Research Notes

_To be expanded as the goal lands._

- **Unit:** `tests/unit/test_session_state.gd` — `SessionState.to_dict/from_dict`
  round-trip, member add/lookup by token, migration scaffold, starter-character
  seeding. Mirror `test_save_manager.gd` / `test_pvp_protocol.gd`.
- **Smoke (real sockets):** `tests/net_session_smoke.gd` — host authority + client,
  client joins with token A (new character created + persisted), disconnects,
  reconnects with token A → same character + world progress restored from the
  session file. Assert single-player `save.json` untouched. Run with
  `godot --headless --path . -s tests/net_session_smoke.gd` (exit 0 = pass).
- **Isolation test:** confirm session writes go only to `user://sessions/...` and
  never to `save.json`.
- Validation gate: headless import clean, `tests/runner.gd` exits 0 (CLAUDE.md).
- **Docs:** update `docs/agent/multiplayer-coop.md` — new section on persistent
  sessions, the session file format, character handshake, reconnect, recent-servers,
  and the authority abstraction (host now; dedicated server in GID-097). Add test
  rows.

## Plan

_Written during Plan phase._

## Changes Made

_Filled after Build phase._

## Documentation Updates

_What was updated in agent docs._
