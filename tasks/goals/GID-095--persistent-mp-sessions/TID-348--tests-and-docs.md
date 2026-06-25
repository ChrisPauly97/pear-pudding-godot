# TID-348: Tests + docs (persistence, handshake, reconnect)

**Goal:** GID-095
**Type:** agent
**Status:** done
**Depends On:** TID-345, TID-346, TID-347

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Plan

1. **Unit** `tests/unit/test_session_state.gd` — round-trip, member lookup/create by
   token, resume-without-reset, starter seeding (token-salted UIDs, deck integrity),
   migration scaffold, garbage tolerance.
2. **Smoke** `tests/net_session_smoke.gd` — real ENet loopback + live `SessionStore`/
   `SaveManager` autoloads: token-A join → starter via `recv_character`; persist +
   close; reopen → resume same character (coins) + world; assert `save_slot_*.json`
   untouched (isolation).
3. **Docs** — persistent-sessions section in `docs/agent/multiplayer-coop.md` + test rows.
4. Validation gate: headless import clean, `tests/runner.gd` exits 0.

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

- **`tests/unit/test_session_state.gd`** (new, auto-run) — 16 cases: to_dict/from_dict
  round-trip (identity, world progress, members, version stamp), member roster
  (has/get/ensure-create/ensure-resume-without-reset/update/blank-token), starter
  seeding (full 12-card deck, coins/defaults, token-salted unique UIDs, deck↔owned
  referential integrity), migration scaffold (versionless upgrade, garbage tolerance).
- **`tests/net_session_smoke.gd`** (new, on-demand) — real ENet loopback + the live
  `SessionStore` autoload (fetched by node path since autoload globals aren't resolvable
  in a bare `-s` script). Proves: token-A join → host sends a seeded 12-card starter via
  the real `recv_character` RPC; after persisted progress (coins=777 + a defeated enemy)
  and close, re-opening the session resumes the **same** character + world from disk;
  `save_slot_1.json` existence is unchanged (isolation). All 4 phases PASS, exit 0.
- **`docs/agent/multiplayer-coop.md`** — new "Persistent Sessions & Per-Player Progress
  (GID-095)" section (SessionState model, CardInstanceUtil, SessionStore authority
  writer, character handshake + adoption/isolation, persist-back, reconnection/recent
  servers/WAN guidance); status header, Integrations rows, two test rows, and
  Limitations updated.
- Validation: headless import clean; `tests/runner.gd` 1588 passed / 0 failed; all
  net smokes (coop, npeer, pvp, session) PASS.

## Documentation Updates

`docs/agent/multiplayer-coop.md` — added the full GID-095 persistent-sessions section
and refreshed the status header, integrations table, test table, and limitations.
The CLAUDE.md `docs/agent/` index already lists `multiplayer-coop.md`, so no index change.
