# TID-323: WorldScene coop hooks — NetSync RPC node, spawn/despawn, 15 Hz broadcast

**Goal:** GID-090
**Type:** agent
**Status:** done
**Depends On:** TID-321, TID-322

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

This is the integration keystone — where co-op becomes visible. `WorldScene`
gains additive, guarded hooks that: (1) connect to `NetworkManager` signals when a
session is active, (2) spawn a `RemotePlayer` for each peer and free it on
disconnect, (3) broadcast the local avatar's state at 15 Hz over a fixed-name
`NetSync` RPC node, and (4) feed received state into the matching remote avatar.
Everything is gated on `NetworkManager.is_active()` so single-player is
untouched.

## Research Notes

**WorldScene structure:** `scenes/world/WorldScene.gd` (Node3D root). Children
include `Entities` (Node3D) holding Player + enemies/NPCs/etc. Entities are
registered in dicts (`_enemy_nodes[id]`, `_npc_nodes[id]`, …). The local player
ref is `_player`. `_process(delta)` already runs per-frame work (position
persistence throttled at >1 unit via `SceneManager.save_manager.update_position`;
camera follow `_camera.position = _player.position + Vector3(20,20,20)` — see
CLAUDE.md "Camera: Isometric Follow Without look_at"). `get_terrain_height(x, z)`
exists for Y lookups.

**Fixed-name RPC node (design decision):** add a child `Node` named exactly
`NetSync` to WorldScene (created in `_ready` when `NetworkManager.is_active()`, or
baked into the scene). RPCs must resolve to the **same node path on both peers**;
a fixed-name child of the world root satisfies this and dies with the scene
(unlike an autoload, which would couple net plumbing to gameplay payloads). Put
the `@rpc` method on a small `NetSync.gd` script attached to that node:
```gdscript
@rpc("any_peer", "unreliable_ordered", "call_remote")
func recv_avatar(x: float, z: float, flip_h: bool, moving: bool) -> void:
    var sender: int = multiplayer.get_remote_sender_id()
    # route to WorldScene -> _remote_player_nodes[sender].set_net_state(...)
```
Local broadcast: `net_sync.rpc("recv_avatar", x, z, flip_h, moving)`.

**Remote player tracking:** add `var _remote_player_nodes: Dictionary = {}`
(peer_id → RemotePlayer). On `NetworkManager.peer_connected(id)`: instantiate
`RemotePlayer` (preload the scene), `init_from_data({"peer_id": id, "x": spawn_x,
"z": spawn_z})`, add under the `Entities` node, store in the dict. On
`peer_disconnected(id)`: `queue_free()` + erase. On `session_ended`: clear all.

**15 Hz broadcast:** accumulate delta in `_process`; every `1.0/15.0` s, if
`NetworkManager.is_active()`, read the local player's `position.x/z`, sprite
`flip_h`, and a moving flag (velocity magnitude > small epsilon, or the existing
walk-anim state), call `AvatarSync.encode(...)` (preload TID-320) and `rpc` it via
NetSync. Receiver calls `AvatarSync.decode` + `RemotePlayer.set_net_state`.

**Guarding:** wrap all of the above so that when `NetworkManager.is_active()` is
false, none of it runs and WorldScene behaves exactly as today. Connect signals in
`_ready` only when active; disconnect / clean up on exit (`_exit_tree`) to avoid
dangling connections when the scene is detached for battles (battles are out of
scope but the world can still be detached — be defensive).

**Camera:** unchanged. Only `_player` drives the camera; RemotePlayers never do.
Do NOT add `look_at` anywhere.

**CLAUDE.md conventions:** explicit type annotations (dict indexing returns
Variant — annotate); preload all referenced scripts/scenes (`RemotePlayer.tscn`,
`AvatarSync.gd`, `NetSync.gd`); validate with headless editor import after edits
(parse errors cascade through WorldScene's preload chain — a bad line here blue-
screens the whole world).

## Plan

1. Create `scenes/world/NetSync.gd` — a `Node` with one `@rpc("any_peer",
   "unreliable_ordered", "call_remote")` method `recv_avatar(payload: Array)`
   that routes `(sender_id, payload)` to `world_scene._on_avatar_received(...)`.
   Has a `world_scene` property set by WorldScene.
2. WorldScene.gd additions (all guarded by `_coop_active` / `NetworkManager.is_active()`):
   - Preloads: `_NetSyncScript`, `_RemotePlayerScene`, `_AvatarSync`
   - Vars: `_remote_player_nodes: Dictionary`, `_net_sync: Node`,
     `_coop_active: bool`, `_net_broadcast_accum: float`
   - `_setup_coop()` called at end of `_ready`: if active, create the `NetSync`
     child node, connect NetworkManager signals (peer_connected/disconnected/
     session_ended), and spawn RemotePlayers for already-connected peers
     (`multiplayer.get_peers()` — handles the client-joining-host ordering)
   - `_spawn_remote_player(pid)` / `_on_coop_peer_disconnected` /
     `_on_coop_session_ended` manage the dict + Entities children
   - `_on_avatar_received(sender, payload)` decodes via AvatarSync and calls
     `set_net_state` on the matching RemotePlayer (spawns lazily if missing)
   - 15 Hz broadcast block in `_process`: encode local `(x, z, flip_h, moving)`
     (flip_h/moving read from the local Player via `get("_sprite")`/`get("_is_moving")`)
     and `rpc("recv_avatar", payload)`
   - `_exit_tree` disconnects the NetworkManager signals defensively
3. RPC path: NetSync is `/root/WorldScene/NetSync` on both peers (root node is
   "WorldScene", instantiated via change_scene_to_node — confirmed). Camera
   untouched. Headless compile + full test run.

## Changes Made

- Created `scenes/world/NetSync.gd` (+ editor-generated `.gd.uid`) — Node with the
  `@rpc("any_peer", "unreliable_ordered", "call_remote")` `recv_avatar(payload)`
  method routing `(sender, payload)` to `world_scene._on_avatar_received(...)`.
- `scenes/world/WorldScene.gd` additions (all guarded; single-player unchanged):
  - Preloads `_NetSyncScript`, `_RemotePlayerScene`, `_AvatarSync`; const
    `_NET_BROADCAST_INTERVAL = 1/15`
  - Vars `_remote_player_nodes`, `_net_sync`, `_coop_active`, `_net_broadcast_accum`
  - `_setup_coop()` (called at end of `_ready`): when `NetworkManager.is_active()`,
    creates the fixed-name `NetSync` child, connects NetworkManager
    peer_connected/peer_disconnected/session_ended, and spawns RemotePlayers for
    already-connected peers via `multiplayer.get_peers()` (covers client-joins-host)
  - `_spawn_remote_player(pid)` instantiates RemotePlayer, sets `world_scene`,
    `init_from_data`, adds under `Entities`, tracks in `_remote_player_nodes`
  - `_on_coop_peer_disconnected` / `_on_coop_session_ended` free + clear avatars
  - `_on_avatar_received(sender, payload)` decodes via AvatarSync and calls
    `set_net_state` (lazy-spawns if the packet beats the connect signal)
  - `_broadcast_local_avatar(delta)` 15 Hz: reads local `flip_h`/`_is_moving` via
    `get()`, encodes, `rpc("recv_avatar", payload)` — called from `_process` under
    `if _coop_active`
  - `_teardown_coop()` in `_exit_tree` disconnects NetworkManager signals
- RPC path `/root/WorldScene/NetSync` matches on both peers (root node "WorldScene"
  via change_scene_to_node). Camera logic untouched.
- All 1530 tests pass; headless compile clean. Live 2-instance verification is TID-325.

## Documentation Updates

None required — `docs/agent/multiplayer-coop.md` is created by TID-326.
