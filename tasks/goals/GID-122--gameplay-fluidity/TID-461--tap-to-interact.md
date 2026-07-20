# TID-461: Tap-to-Interact on Arrival

**Goal:** GID-122
**Type:** agent
**Status:** done
**Depends On:** —

## Lock

**Session:** none · **Acquired:** — · **Expires:** —

## Context

`WorldScene._handle_tap_to_move()` (scenes/world/WorldScene.gd:6407) resolves
a tap/click to a tile, path-finds to it, and sets the player's destination —
nothing more. If the tapped tile is a chest, door, NPC, waystone, etc., the
player still has to press E (desktop) or tap the separate USE button
(Android) once they arrive. `_handle_interact()` (WorldScene.gd:5014) already
contains the full priority-ordered dispatch for every interactable type
(door, enemy, chest, npc, scroll, camps, shrine, digspot, waystone, mailbox,
garden plot, burial mound, blight heart, mana well) keyed off the player's
*current* position — reusing it as-is (rather than duplicating any of its
branches) is the safe path, since none of that logic needs to change.

Player.gd's path-following (`_physics_process`) only ever calls the shared
`cancel_path()` for three cases: manual input override, `enemy_engaged`
signal, and natural waypoint-index overflow (arrival). WorldScene needs to
tell these apart — auto-firing an interaction on a manual override (player
pressed WASD to abandon the walk) would be wrong.

## Plan

1. `Player.gd`: add `signal path_arrived`. Emit it (in addition to the
   existing `cancel_path()` call) only in the natural-arrival branch —
   `if _path_wp_index >= _path_waypoints.size(): cancel_path();
   path_arrived.emit()`. Manual-override and `enemy_engaged` cancellations
   are untouched and never emit it.
2. `WorldScene._spawn_player()`: after `_player = _create_player_node()`,
   connect `if _player.has_signal("path_arrived"):
   _player.connect("path_arrived", _on_player_path_arrived)` (dynamic
   connect — `_player` is statically typed `CharacterBody3D`, matching the
   existing `has_method()`/`call()` pattern this file already uses for the
   Player-specific API).
3. Add `var _pending_tap_interact: bool = false`.
4. Add a private helper mirroring `_check_interactions()`'s `has_entity`
   check but parameterized on an arbitrary world point instead of the live
   player position — `_tile_has_interactable(wx: float, wz: float) -> bool`
   — calling the same `_find_nearby_*` finders (door at
   `IsoConst.INTERACT_RANGE * 2.0`, everything else at
   `IsoConst.INTERACT_RANGE`) and returning true if any is non-empty/non-null.
5. In `_handle_tap_to_move()`, after the path is found to be non-empty
   (i.e. the tap will actually move the player) compute the tapped tile's
   world center and set `_pending_tap_interact =
   _tile_has_interactable(wx, wz)` before placing the marker/path.
6. `_on_player_path_arrived()`: if `_pending_tap_interact` and not
   `_coop_downed` and not `SceneManager.has_open_overlay()`, call
   `_handle_interact()`. Always clear `_pending_tap_interact` after.
7. `_clear_dest_marker()`: also reset `_pending_tap_interact = false`
   (covers battle-start/map-change/new-tap cancellation paths).

## Changes Made

- `scenes/world/entities/Player.gd`: added `signal path_arrived`, emitted
  only on natural waypoint-arrival in `_physics_process()`.
- `scenes/world/WorldScene.gd`:
  - `_pending_tap_interact: bool` field.
  - `_tile_has_interactable(wx, wz) -> bool` helper reusing the existing
    `_find_nearby_*` finder battery.
  - `_handle_tap_to_move()` sets the pending flag once a valid path is found.
  - `_on_player_path_arrived()` fires `_handle_interact()` when the flag is
    set and no overlay/downed-state blocks it.
  - `_spawn_player()` wires the dynamic `path_arrived` connection.
  - `_clear_dest_marker()` clears the pending flag.

## Documentation Updates

- `docs/agent/tap-to-move.md`: new "Tap-to-Interact on Arrival" subsection.
