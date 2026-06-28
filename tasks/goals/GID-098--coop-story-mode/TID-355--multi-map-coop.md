# TID-355: Multi-map co-op — map-transition & cross-map avatar sync

**Goal:** GID-098
**Type:** agent
**Status:** pending
**Depends On:** —

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

The keystone of co-op story mode. Today co-op is single-map: the lobby calls
`SceneManager.enter_map_coop("madrian")` and the avatar layer (TID-352) hides any
peer whose `map_name` differs from the local one. To play the story together the
party must be able to move through the named maps and dungeons as a group and still
see each other.

## Research Notes

- **Entry today:** `autoloads/SceneManager.gd`
  - `enter_map_coop(map_name)` (line ~267) just calls `enter_map(map_name, "")` after
    `_exit_world_cleanup()` + `ensure_coop_deck()`.
  - `enter_map(map_name, target_door_id)` (line ~252) pushes the current map to
    `map_stack`, syncs stacks to SaveManager, then `_load_world`.
  - `exit_map()` (line ~276) pops `map_stack`/`door_stack` to return to a parent map.
  - `_load_world` (line ~297) instantiates WorldScene, sets `map_name` /
    `target_door_id`. WorldScene root is named `WorldScene` so the NetSync RPC path
    `/root/WorldScene/NetSync` matches on both peers — preserve this on every map.
- **Avatar map-scoping (TID-352):** `AvatarSync.encode/decode` carries the sender's
  `map` (5th element); `WorldScene._on_avatar_received` records `_remote_player_maps`
  and only shows/feeds avatars whose map equals the local `map_name`. This stays —
  it is correctness, not a blocker. The new work is **syncing the transition itself**
  so peers know where the party went and can follow.
- **Design decision (write into docs):** pick the co-op map-movement model:
  - *Followed transition* — when a player goes through a DOOR/waystone, broadcast the
    transition; others get a prompt/auto-follow into the same map. Simplest coherent
    "play together" model. Recommended.
  - *Independent movement* — each player roams maps freely; avatar filtering already
    handles rendering. Risk: party scatters across maps with no joint battles.
  - Likely a hybrid: independent roaming allowed, but a synced "party leader entered
    X" ping + one-tap follow. Decide during Plan and document in `multiplayer-coop.md`.
- **map_stack is currently local** to each peer (SaveManager/SceneManager). In co-op
  the *shared* map context belongs to the session — consider routing the active
  shared map through `SessionState.current_map` (already a field, GID-095) so a
  late-joiner / reconnecting peer lands where the party is.
- **NetSync RPCs** (`scenes/world/NetSync.gd`): add a reliable
  `recv_map_transition(map_name, door_id)` (authority→clients) +
  `submit_map_transition` (client→authority intent), mirroring the GID-096
  world-event RPC pattern. The node dies with the scene, so re-created per map load
  by `_setup_coop`.
- **Guarding:** every new path behind `NetworkManager.is_active()` / `_coop_active`.
  Single-player `enter_map`/`exit_map` must be untouched.
- **Dedicated server:** the headless server (GID-097) has no local player/map; ensure
  the shared-map authority logic works when the authority is the dedicated server
  (it already owns `SessionStore`). Test with `is_dedicated_server()` guards intact.

## Plan

_Written during Plan phase._

## Changes Made

_Filled after Build phase._

## Documentation Updates

_What was updated in agent docs._
