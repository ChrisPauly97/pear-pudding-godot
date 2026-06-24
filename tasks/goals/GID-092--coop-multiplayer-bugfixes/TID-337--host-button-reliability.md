# TID-337: Host button reliability — reset stale session before re-hosting

**Goal:** GID-092
**Type:** agent
**Status:** done
**Depends On:** —

## Context

The "Host Game" button doesn't always work. The reporter's observation: once you're
already "hosting," pressing Host again does nothing and you have to use Find Games to join
from the list instead. The host path never clears a prior peer/discovery binding before
creating a new server, so the second attempt fails on the already-bound port.

## Research Notes

- `MultiplayerLobbyScene._on_host` (scenes/ui/MultiplayerLobbyScene.gd:113) calls
  `NetworkManager.host()`; on a non-OK result it shows "Could not host (error %d)."
- `NetworkManager.host(port)` (autoloads/NetworkManager.gd:59):
  - Always creates a **new** `ENetMultiplayerPeer` and calls `create_server(port, MAX_PEERS)`.
  - If a previous peer is still assigned/active, the new `create_server` and/or
    `_start_discovery_listener()`'s `bind(DISCOVERY_PORT)` will fail because the port is
    still held → returns an error, OR binds noisily (the listener bind only push_warns).
  - `host()` does **not** call `leave()` / reset `multiplayer.multiplayer_peer = null` first.
- `is_active()` (line 100) returns true while a peer is assigned and not DISCONNECTED. After
  a host returns to the menu without an explicit `leave()`, the session can persist, so the
  next `host()` collides.
- `leave()` (line 92) already tears down both the discovery listener and the peer and emits
  `session_ended` — the building block to reuse.
- The lobby's `closed` handler (MultiplayerLobbyScene.gd:25) calls `NetworkManager.leave()`
  only if `is_active()` and only when the overlay is explicitly closed — not when `_on_host`
  changes scenes via `enter_map_coop`. So a host that goes back to the menu by another path
  leaves the session dangling.
- Note `_start_discovery_listener` (131) already calls `_stop_discovery_listener()` first,
  so the discovery side is idempotent; the ENet server side is not.

## Plan

Root cause confirmed: `leave()` only sets `multiplayer.multiplayer_peer = null` — it never
calls `peer.close()`, so the prior ENet server socket keeps the OS port bound until GC, and
the next `create_server(port)` fails with "address in use". Fix: add a private
`_reset_session()` that stops the discovery listener/scanner, **closes** the current peer
(`multiplayer.multiplayer_peer.close()`), then nulls it. Call `_reset_session()` at the
start of `host()` and `join()` (free the port before re-binding) and from `leave()` (which
keeps emitting `session_ended`). Re-hosting then starts from a clean slate every time.

Note: there is no Lock section in this task file; per workflow that means it is free to
claim. This whole goal is being executed in one session
(`claude/work-task-gid-092-t6krxi`).

## Changes Made

- `autoloads/NetworkManager.gd`: added private `_reset_session()` — stops the discovery
  listener/scanner, **closes** the current peer (`peer.close()`), then nulls it. `leave()`
  now delegates to it (still emits `session_ended`); `host()` and `join()` call it first so a
  stale peer/port is freed before `create_server`/`create_client`. The missing `close()` was
  the root cause: nulling alone left the ENet server socket bound until GC, so the second
  `host()` failed with "address in use".
- `tests/net_rehost_smoke.gd`: new on-demand smoke test — host→leave→host ×3, plus a re-host
  with no explicit `leave()`, all assert `OK`.

Verified: `net_rehost_smoke` PASS; full unit suite 1557/0; existing `net_coop_smoke` /
`net_discovery_smoke` still green; headless import clean.

## Documentation Updates

- `docs/agent/multiplayer-coop.md`: added the host/join reset contract to the
  NetworkManager API section + the new test row.
- `CLAUDE.md`: Bug Fix Learnings entry (always `close()` a peer before dropping it).
