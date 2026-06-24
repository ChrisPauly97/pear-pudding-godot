# TID-337: Host button reliability — reset stale session before re-hosting

**Goal:** GID-092
**Type:** agent
**Status:** pending
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

_Written during Plan phase._ In `NetworkManager.host()` (and likely `join()`), tear down any
existing peer first — e.g. early `if is_active(): leave()` or reset
`multiplayer.multiplayer_peer = null` + stop listeners — before creating the new server, so
re-hosting always starts from a clean slate and the port is free. Confirm `_on_host` then
succeeds on repeat presses. Verify the LAN smoke tests still pass
(`godot --headless --path . -s tests/net_coop_smoke.gd` and `tests/net_discovery_smoke.gd`).

## Changes Made

_Filled after Build phase._

## Documentation Updates

_What was updated in agent docs._ Note the host/join reset contract in
`docs/agent/multiplayer-coop.md`.
