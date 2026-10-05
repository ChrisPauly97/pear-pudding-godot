# TID-668: Hot-Path Fixes

**Goal:** GID-160
**Type:** agent
**Status:** done
**Depends On:** —

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

See goal.

## Research Notes

- `CharacterPresence._process` → `ContactShadow.pick_slots` duplicated and fully `sort_custom`-ed every caster
  (GDScript lambda building two `Vector3`s per comparison) every frame to keep the nearest 6.
- Minimap quest pins, compass and objective beacon call `QuestTracker.quest_pos` per quest per frame →
  `ObjectiveTracker.place_on_map` → `RealmLayout.door_into` → `entities("doors")`, which copied the whole
  cached door list on each call. `entities_in_chunk` copied the full list per chunk per kind too.
- `WorldHUD.update_coords` re-formatted the tile label every frame; WorldScene computed the tile with `int()`
  truncation (wrong for negative coords).

## Plan

Top-K insertion in `pick_slots`; private copy-free `_cached_entities()` for internal hot readers; coord label
updates only on tile change via `IsoConst.world_to_tile`.

## Changes Made

- `game_logic/ContactShadow.gd`: `pick_slots` keeps the nearest `MAX_CASTERS` by insertion (O(n·k), no copy).
- `game_logic/world/RealmLayout.gd`: `_cached_entities(kind)` returns the cache read-only; `door_into` and
  `entities_in_chunk` use it. Public `entities()` still hands out a copy (it also no longer returns the cache
  object itself on the first call, which let a caller mutate the cache).
- `scenes/world/WorldHUD.gd` / `WorldScene.gd`: coord label formatted only when the tile changes; floor-correct tile.
- `tests/unit/test_contact_shadow.gd`: nearest-of-many-unsorted test.

## Documentation Updates

None needed (no new patterns beyond the per-frame note in code).
