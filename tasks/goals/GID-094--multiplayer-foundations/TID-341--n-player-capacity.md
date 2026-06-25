# TID-341: Raise player cap to 4 + generalize avatar sync to N peers

**Goal:** GID-094
**Type:** agent
**Status:** pending
**Depends On:** —

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

Co-op is hard-capped at 2 players. To support persistent 4-player sessions
(GID-095) and world sync (GID-096), the transport and WorldScene avatar plumbing
must handle up to 4 peers (1 host + 3 clients, or — later — a dedicated server +
4 clients). This task lifts the cap and removes the single-remote-peer
assumptions, with no change to single-player.

## Research Notes

**Cap constant:** `autoloads/NetworkManager.gd:15` — `const MAX_PEERS: int = 1`
(comment "2-player slice: host + 1 client"). ENet `create_server(port, MAX_PEERS)`
treats `MAX_PEERS` as max *clients*, so host-is-player wants `MAX_PEERS = 3` for
4 total. A future dedicated server (GID-097) hosts without being a player, so it
will want `4`; consider exposing the desired client count as a `host()` parameter
defaulting to 3 rather than baking it, so GID-097 doesn't re-edit the constant.

**Avatar registry is already N-safe:** `scenes/world/WorldScene.gd` keeps
`_remote_player_nodes: Dictionary` (peer_id → RemotePlayer) and
spawns/frees per-peer in `_spawn_remote_player` / `_on_coop_peer_connected` /
`_on_coop_peer_disconnected` / `_on_coop_session_ended` (lines ~490–516). The
15 Hz broadcast (`_broadcast_local_avatar`, ~530) uses `rpc(...)` which already
fans out to all peers, and `_on_avatar_received(sender, payload)` (~519) keys by
`sender`. So the receive/broadcast path needs **no change** for N peers.

**The single-peer assumption to fix — spawn offset:** the doc notes "the non-host
avatar spawns +2 tiles over so the two don't overlap at the shared madrian spawn
marker." Current `_spawn_remote_player` (WorldScene.gd:490) seeds the remote at
the *local* player's position; with 4 players at one SPAWN marker they stack.
Replace the fixed nudge with a deterministic fan-out keyed by `peer_id` (e.g. a
small ring/grid offset `f(peer_id)`), so each avatar lands on a distinct tile
regardless of join order. Keep it terrain-safe (Y recomputed by RemotePlayer).

**Setup already iterates existing peers:** `_setup_coop()` spawns RemotePlayers
for `multiplayer.get_peers()` already (covers the join-ordering race) — confirm it
still works for >1 existing peer (it iterates, so it should).

**Discovery payload `players` count:** `NetworkManager._serve_discovery()`
computes `players = multiplayer.get_peers().size() + 1` — already correct for N.
The lobby reply/label shows the count; verify it reads sensibly at 3–4.

**CLAUDE.md conventions:** guard all co-op code by `NetworkManager.is_active()` /
`_coop_active`; explicit type annotations; `preload` not `class_name`.

## Plan

_Written during Plan phase._

## Changes Made

_Filled after Build phase._

## Documentation Updates

_What was updated in agent docs._
