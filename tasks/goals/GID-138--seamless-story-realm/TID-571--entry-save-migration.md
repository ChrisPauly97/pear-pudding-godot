# TID-571: Entry Points & Save Migration

**Goal:** GID-138
**Type:** agent
**Status:** done
**Depends On:** TID-570

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

New Game → overworld at Madrian; interior exit → overworld at its door;
old saves in a stitched town migrate to `main` at translated position.

## Research Notes

- `SceneManager.enter_map/exit_map/_load_world`, map_stack/door_stack.
- `game_logic/save/SaveMigrations.gd`: bump CURRENT_VERSION + one row.
- Dedicated server default map "madrian".

## Plan

New game enters `main` at Madrian's spawn. Leaving the overworld pushes a `pos:x:z`
token on the door stack; the overworld spawn honours it. An interior with an empty
stack exits through its stitched door. `map:<town>` waystones teleport within the
overworld. Save v43 moves stitched-town saves/stacks/waypoints into `main`.

## Changes Made

- `RealmLayout`: `door_into`, `return_pos_for`, `pos_token` / `parse_pos_token`,
  `is_overworld`, `DROPPED_DOORS` (Madrian's shortcut doors into the mansion/temple).
- `SceneManager`: new game → `enter_map("main")`; `enter_map` pushes a `pos:` token when
  leaving the overworld; `exit_map` with an empty stack steps out of the interior's
  stitched door; `teleport_to_waystone` → `_teleport_overworld()` for stitched towns
  and `world:` stones; spire fallback entry → `main`.
- `WorldScene._spawn_player`: overworld default = Madrian spawn; honours `pos:` tokens.
- `SaveMigrations` v43 `_m43_stitched_towns` (position shift, stack collapse with
  return tokens, waypoint translation) + `tests/unit/test_save_migration_realm.gd`.
- Co-op left on the named maps — logged as BID-063.

## Documentation Updates

- Deferred to TID-573.
