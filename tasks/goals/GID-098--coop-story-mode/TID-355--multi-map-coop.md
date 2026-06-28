# TID-355: Multi-map co-op — map-transition & cross-map avatar sync

**Goal:** GID-098
**Type:** agent
**Status:** done
**Depends On:** —

## Lock

**Session:** claude/work-task-gid-098-2r7qpg
**Acquired:** 2026-06-28T14:47:40Z
**Expires:** 2026-06-28T15:17:40Z

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

**Model chosen:** Followed transition. When any co-op player interacts with a door, all peers follow to the same map. The initiating player broadcasts a reliable `recv_map_transition` RPC before loading; receivers call the matching SceneManager entry point.

**Changes:**

1. `scenes/world/NetSync.gd` — add `recv_map_transition(target_map, door_id)` reliable RPC (any_peer, call_remote → WorldScene._on_map_transition_received).
2. `scenes/world/WorldScene.gd`:
   - Add `_coop_map_transitioning: bool = false` member (guards against double-transition on the same scene instance).
   - In `_handle_interact` door block: before calling `SceneManager.exit_map()` / `enter_map()`, when `_coop_active` broadcast `recv_map_transition` and set flag.
   - Add `_on_map_transition_received(target_map, door_id)` handler.
   - In `_on_identity_received` host block: after sending character + snapshot, if `SessionState.current_map != map_name`, unicast `recv_map_transition` to the new peer so late-joiners land where the party is.
3. `SessionState.current_map` already updated by `_setup_session()` on every new WorldScene — no extra code needed.
4. `tests/unit/test_coop_map_transition.gd` — unit tests for the new map-transition logic helper.

## Changes Made

- `scenes/world/NetSync.gd` — added `recv_map_transition(target_map, door_id)` reliable RPC (any_peer → WorldScene._on_map_transition_received).
- `scenes/world/WorldScene.gd`:
  - Added `_coop_map_transitioning: bool = false` member variable.
  - In `_handle_interact` door block: when `_coop_active` and not already transitioning, sets the guard and broadcasts `recv_map_transition` before calling the local `SceneManager.exit_map()` / `enter_map()`.
  - Added `_on_map_transition_received(target_map, door_id)` handler: guards against double-transition, routes empty string → `exit_map()`, non-empty → `enter_map(target_map, door_id)`.
  - In `_on_identity_received` host block: after sending character + snapshot, checks `SessionStore.current_map != map_name` and unicasts `recv_map_transition` to the joining peer so late-joiners land where the party is.
  - In `_setup_coop`: connects `GameBus.story_flag_set` to `_on_local_story_flag_set`.
  - In `_teardown_coop`: disconnects the signal.
- `tests/unit/test_coop_map_transition.gd` — new unit tests for the map-transition payload convention and `dialogue_group` field pipeline.

## Documentation Updates

- `docs/agent/multiplayer-coop.md` updated with GID-098 co-op story mode section.
