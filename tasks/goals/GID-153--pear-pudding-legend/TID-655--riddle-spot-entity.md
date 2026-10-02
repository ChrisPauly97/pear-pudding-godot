# TID-655: Riddle-Spot Entity

**Goal:** GID-153
**Type:** agent
**Status:** pending
**Depends On:** —

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

Each riddle resolves at a world spot that only reacts when its condition holds. Outside the condition it is plain
scenery (or invisible) and gives at most a subtle flavour line, never a marker.

## Research Notes

- Conditions needed: time of day (dusk / night) — `DayNightCycle.is_night(t)` static + `_dnc` built by
  `scenes/world/modules/WorldClock.gd`; add a dusk helper if none exists. Weather — `WeatherManager.current_weather`
  (use the real weather, not `shown()`, which hides effects per setting). Cantrip — Skeleton Dig in
  `scenes/world/modules/Cantrips.gd` `activate_skeleton_dig()`; existing `DigSpot` entity
  (`scenes/world/entities/DigSpot.gd`, treasure maps) is the closest pattern for "dig here reveals a thing".
  Carried item / prior flag — story flags.
- Data-driven: `game_logic/world/RiddleSpots.gd` static table `{id, world tile, condition{time, weather, cantrip,
  req_flag}, sets_flag, success_text, idle_text}`; entity `scenes/world/entities/RiddleSpot.gd` reads it.
- Placement: stitched overworld tiles (`RealmLayout.to_world_tile()` for town-local coords); spawn via a world module
  (e.g. `NamedMapProps` or a new `Legend` module under `scenes/world/modules/` created in `_ensure_world_modules()`).
- Interaction: add one `INTERACT_PRIORITY` entry + a branch in both chains, or a `_try_simple_interaction` table row
  (`test_interact_priority`). Peaceful → above hostiles. Keep a `_find_nearby_riddle_spot` finder on WorldScene.
- Proximity via `_first_node_in_range`, never a hand-written distance loop. Billboard via
  `SpriteRegistry.make_billboard()`.
- Mobile parity: interaction is the normal Interact button; Dig is the existing HUD cantrip button.
- Tests: condition evaluation as pure logic (`RiddleSpots.condition_met(spot, ctx)`), unit-tested per condition.

## Plan

_Written during Plan phase._

## Changes Made

_Filled after Build phase._

## Documentation Updates

_What was updated in agent docs._
