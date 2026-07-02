# TID-388: Rally Waystones — Teleport to Party

**Goal:** GID-105
**Type:** agent
**Status:** done
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

1. **`scenes/ui/MapViewOverlay.gd`**: add `signal rally_requested(peer_id: int)`, a `_rally_targets: Array[Dictionary]` field, and an optional 10th `rally_targets: Array = []` parameter to `setup()`. Extend `_build_fast_travel_panel()` to append a "Rally To" section below the waystone list (same `vbox`, a separator label + one button per target formatted `"Rally to <name> (<map>)"`), blocked by the same `is_blocked` flag. Each button calls a new `_request_rally(peer_id)` which emits `rally_requested`, then `closed.emit()` + `queue_free()` (mirrors `_teleport_to_waystone`).
2. **`scenes/world/WorldScene.gd`**:
   - Add `_last_rally_time: float = -999.0` and `const _RALLY_COOLDOWN: float = 3.0`.
   - Add `_build_rally_targets() -> Array[Dictionary]` returning `{peer_id, name, color, map}` for every entry in `_remote_identities` whose `_remote_player_maps` entry is non-empty (guarded by `NetworkManager.is_active()`).
   - `_open_map_view()`: pass `_build_rally_targets()` as the new `setup()` arg; connect `_map_overlay.rally_requested` to `_rally_to_peer`.
   - Add `_rally_to_peer(peer_id: int)`: cooldown check → same-map branch (teleport `_player.global_position` to the cached `RemotePlayer.global_position`) or cross-map branch (broadcast `recv_map_transition` via `_net_sync` + call `SceneManager.enter_map`), plus a `recv_rally_notice` RPC to the target peer for the "teammate rallying to you" toast.
   - Add `_on_rally_notice_received(rallier_name: String)` → `GameBus.hud_message_requested.emit(...)`.
   - Small correctness fix bundled here: `_on_map_transition_received` currently re-enters `target_map` even if the receiving peer is already on it (no existing guard) — add `if not target_map.is_empty() and target_map == map_name: return` so a rally (or the pre-existing dungeon-crawl broadcast) never needlessly reloads a peer who is already on the destination map.
3. **`scenes/world/NetSync.gd`**: add `recv_rally_notice(rallier_name: String)` reliable RPC (mirrors the other one-shot notice RPCs), routed to `world_scene._on_rally_notice_received`.
4. Update `docs/agent/multiplayer-coop.md` (Co-op Story Mode section) with a "Rally waystones" subsection.
5. Manual/code review only — no Godot headless binary available in this sandbox (github.com release downloads are blocked by the egress policy, confirmed via the agent-proxy status). Verify via careful reading + grep for symbol consistency; note this limitation in Changes Made.

## Changes Made

- **`scenes/ui/MapViewOverlay.gd`**: added `signal rally_requested(peer_id)`, `_rally_targets: Array[Dictionary]` field, an optional 10th `rally_targets` param to `setup()`, a "Rally To" section in `_build_fast_travel_panel()` (title + one tinted button per target, respecting the existing `is_blocked` flag), and `_request_rally(peer_id)`.
- **`scenes/world/WorldScene.gd`**: added `_last_rally_time` / `_RALLY_COOLDOWN`, `_build_rally_targets()`, `_rally_to_peer(peer_id)` (same-map instant teleport / cross-map followed-transition broadcast), `_on_rally_notice_received()`; wired into `_open_map_view()`. Bundled a correctness fix in `_on_map_transition_received()`: added an early return when the receiving peer is already on the destination map, preventing a needless reload/position-reset (this also benefits the pre-existing TID-380 Dungeon Crawl broadcast).
- **`scenes/world/NetSync.gd`**: added `recv_rally_notice(rallier_name)` reliable RPC.
- **`docs/agent/multiplayer-coop.md`**: new "Party Convenience & Stakes (GID-105)" section, "Rally waystones (TID-388)" subsection.
- **Verification limitation**: no Godot headless binary is available in this sandbox — `godot` is not installed and downloading the 4.6-stable release from `github.com/godotengine/godot/releases` was blocked by the environment's egress policy (403 from the agent proxy; confirmed via `curl $HTTPS_PROXY/__agentproxy/status`, a policy denial per the proxy's own guidance, not something to retry or route around). Verified by careful manual reading, symbol-consistency grepping, and cross-checking against every existing call site of the changed signatures (`AvatarSync.encode/decode`, `MapViewOverlay.setup`, `_on_map_transition_received` callers) instead of a live headless import.

## Documentation Updates

- `docs/agent/multiplayer-coop.md` — added the "Party Convenience & Stakes (GID-105)" / "Rally waystones (TID-388)" subsection described above.
