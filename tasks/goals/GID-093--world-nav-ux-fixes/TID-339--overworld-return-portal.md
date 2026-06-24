# TID-339: Persistent return portal from the infinite overworld to town

**Goal:** GID-093
**Type:** agent
**Status:** pending
**Depends On:** —

## Context

Once the player enters the infinite "main" overworld from madrian, there's no way back to
town unless they've activated a waystone. The chosen fix is a **persistent return-portal
entity**: a visible portal/door in the overworld that steps the player back to madrian.

## Research Notes

- Entry: `madrian.tres` has `door_10` with `target_map = "main"` (assets/maps/madrian.tres).
  Going through it calls `SceneManager.enter_map("main")` (autoloads/SceneManager.gd:222),
  which pushes "madrian" onto `map_stack`. In principle `exit_map()` (line 241) would pop
  back — but "main" is the infinite overworld and renders no return door, so `exit_map` is
  never triggered there.
- `WorldScene` treats `map_name == "main"` (or "infinite") as infinite:
  `_is_infinite = (map_name == "infinite" or map_name == "main")` (scenes/world/WorldScene.gd:223).
  The named-map door/entity spawning path is bypassed for infinite maps.
- Door handling lives in `_handle_interact` (WorldScene.gd:1890+): it finds a nearby door,
  reads `target_map`/`target_door_id`, plays `door_enter`, handles auto-dismount, and calls
  `SceneManager.exit_map()` (line 1911) for the back-out case. Doors are `MapDoor` resources
  (game_logic/world/resources/MapDoor.gd) spawned from `.tres` entities.
- Waystone system is the current (only) return route — see docs/agent/waystone-fast-travel.md.
  The new portal should be simpler: a fixed return-to-town target, no activation required.
- Implementation options to weigh in Plan:
  - Spawn a persistent return-portal entity in the infinite world near the player's main-map
    entry/spawn point (mirror how waystones / dig spots / other world entities are placed
    and given an interact prompt). On interact, route back to madrian — either via
    `exit_map()` (if the map_stack still holds madrian) or an explicit
    `enter_map("madrian")`. Confirm which is correct so the stack doesn't grow unbounded.
  - Ensure it works on both desktop (interact key) and mobile (tap prompt) per CLAUDE.md
    "Mobile / Desktop Feature Parity."
- Player spawn nuance: see CLAUDE.md "Named Map Player Spawn vs. Saved Position" — returning
  to madrian should land at the spawn/door position, not a stale saved coord, unless this is
  a continue_game load. Verify the entry-path table still holds with the new portal.
- Check `_spawn_player` / main-map entry (WorldScene.gd:706+, and the `map_name == "main"`
  block at 375) for where to anchor the portal so it's reliably reachable.

## Plan

_Written during Plan phase._

## Changes Made

_Filled after Build phase._

## Documentation Updates

_What was updated in agent docs._ Update `docs/agent/named-maps-and-dungeons.md` and/or
`docs/agent/world-generation.md` to document the overworld return portal and its routing.
