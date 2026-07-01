# TID-388: Rally Waystones — Teleport to Party

**Goal:** GID-105
**Type:** agent
**Status:** pending
**Depends On:** —

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

The #1 friction point in co-op multiplayer is regrouping after a split. Players explore different regions, take different dungeon exits, or walk through separate doors and end up on different maps with no way to converge. Without rally travel, co-op sessions collapse as players manually backtrack or abandon and rejoin. Rally waystones solve this by letting any player teleport to a connected party member instantly from the fast-travel UI, with the destination determining whether the rally is same-map (instant position sync) or cross-map (full map transition reusing TID-355's `recv_map_transition` mechanism). This creates a tight feedback loop: player A opens the fast-travel menu, sees "Rally to Alice (madrian)", taps it, and appears next to Alice mid-exploration. The mechanic is inherently mobile-parity (tap target in the UI list) and guarded by `NetworkManager.is_active()`, so single-player fast travel UX is unaffected.

## Research Notes

**Existing infrastructure:** The fast-travel UI already exists (GID-044, docs/agent/waystone-fast-travel.md) and is driven by `WaystoneRegistry` entries listing activated waystone IDs. WorldScene maintains `_remote_identities: Dictionary[int, Dictionary]` mapping peer_id to `{token, name, color}` and `_remote_player_maps: Dictionary[int, String]` tracking the last-known map of each peer from the AvatarSync payload (5th element added in GID-096). `_remote_player_nodes: Dictionary[int, RemotePlayer]` holds avatar nodes for same-map peers, storing their last synchronized position.

**Rally entry point:** Extend the fast-travel UI to show a "Rally To" section listing connected session members (pulled from `_remote_identities.keys()` filtered by `_remote_player_maps[peer_id] != ""` to skip late-joiners with unknown location). Each rally entry displays the target's colored name and current map. Tapping a rally entry calls a new `_rally_to_peer(peer_id: int)` method on WorldScene.

**Same-map rally:** If `_remote_player_maps[peer_id] == current_map`, the rally is local. Query `_remote_player_nodes[peer_id].global_position` (or fall back to the stored position if the avatar node is not in tree) and teleport the player there instantly via `_player.global_position = target_pos`. Emit a "rallying" toast ("Rallying to Alice…") for immediate feedback.

**Cross-map rally:** If the target is on a different map, reuse the TID-355 multi-map transition mechanism. Call `NetSync.recv_map_transition(_remote_player_maps[peer_id], "")` (empty door_id, since we're teleporting, not using a door) to broadcast the map transition to all peers. This ensures all peers follow through to the target map, then the receiving peer (or host) applies the position sync on arrival via the existing post-transition hook in WorldScene.

**Cooldown & polish:** Add a small cooldown (e.g., 3 seconds) to prevent spam; check `_last_rally_time` and emit a brief toast if cooldown is active. On the target peer, broadcast a discrete "teammate rallying to me" notification (sound or UI toast) for the hero moment — this can be a simple `GameBus` signal or carried in the AvatarSync payload extension.

**Authority & guard:** Guard all rally logic with `if not NetworkManager.is_active(): return` so single-player fast travel sees no rally section. Host arbitration is not needed (teleport is local and instant); cross-map transitions already go through `NetSync` which is host-authoritative.

**Mobile parity:** The rally entries are tap targets in the fast-travel UI list, so parity is automatic — same interaction pattern as tapping a waystone.

## Plan

_Written during Plan phase._

## Changes Made

_Filled after Build phase._

## Documentation Updates

_What was updated in agent docs._
