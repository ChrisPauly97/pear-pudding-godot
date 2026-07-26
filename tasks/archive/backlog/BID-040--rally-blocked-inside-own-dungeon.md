# BID-040: Rally waystones inherit the fast-travel dungeon block, defeating a key use case

**Category:** design-gap
**Discovered During:** GID-105 / TID-388

## Summary

`MapViewOverlay._build_fast_travel_panel()` computes a single `is_blocked` flag
(`SceneManager._state != State.WORLD or SceneManager.current_map.begins_with
("dungeon_")`) and disables every button in the panel — waystones and, as of
TID-388, "Rally To" entries — whenever the *local* player is currently inside a
dungeon.

This is correct for waystones (you can't fast-travel out of a dungeon to an
arbitrary waystone), but it also blocks rallying to a teammate, which is most
useful exactly when the party has split up *inside* a shared dungeon crawl
(TID-380) — e.g. one player died and auto-respawned at the entrance (TID-389)
while the rest of the party pushed on deeper. That player currently has no way
to rally back to the party without walking there manually, which is the exact
friction GID-105 set out to remove.

## Suggested Fix

Give rally its own gating condition, independent of the waystone block:
block rally only when `SceneManager._state != State.WORLD` (mid-battle), not
when `current_map.begins_with("dungeon_")`. A same-map rally never needs to
change maps at all (it's a local position sync), so the dungeon restriction
never applied to that case anyway; a cross-map rally *while already in a
dungeon* would need to reuse the same `recv_map_transition` mechanism the
Dungeon Crawl button already uses to move the party between dungeon instances,
which should work unchanged.

## Files

- `scenes/ui/MapViewOverlay.gd` (`_build_fast_travel_panel`, `is_blocked`)
- `scenes/world/WorldScene.gd` (`_rally_to_peer`, `_build_rally_targets`)
