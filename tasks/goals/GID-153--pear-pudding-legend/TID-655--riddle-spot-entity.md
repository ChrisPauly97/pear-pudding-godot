# TID-655: Riddle-Spot Entity

**Goal:** GID-153
**Type:** agent
**Status:** done
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

Pure `RiddleSpots.gd` (table, `phase`, `evaluate`, `line_for`); `RiddleSpot` billboard entity; `Legend` world
module spawning spots on the overworld and resolving looks/Digs; WorldScene interaction wiring within the line
ceiling; Cantrips Dig fallback; pixel-art props; unit tests.

## Changes Made

- `game_logic/world/RiddleSpots.gd` (new): three spots (stones, pear tree, queen's well) with conditions and lines.
- `scenes/world/entities/RiddleSpot.gd` (new), `scenes/world/modules/Legend.gd` (new, `WorldScene.legend`).
- `scenes/world/WorldScene.gd`: module wiring, `riddle_spot` priority entry, "EXAMINE" prompt, finder (1889/1890 lines).
- `scenes/world/modules/Cantrips.gd`: Dig falls through to `legend.try_dig`.
- `autoloads/GameBus.gd`: `legend_riddle_solved(spot_id)`.
- `game_logic/SpriteRegistry.gd`: `_LEGEND_PROPS`, `legend_prop()`.
- `tools/generate_legend_props.py` + four `assets/textures/props/legend_*.png`.
- `tests/unit/test_riddle_spots.gd` (7 tests). Full suite, world/chunk/menu smokes, unsafe-hits, gdlint clean;
  a headless probe confirmed the 3 spots spawn on `main` and the pear tree solves.
- Placement on walkable, tree-free ground and the brew payoff are TID-657.

## Documentation Updates

`docs/agent/legends-pear-pudding.md` Riddle Spots section; `Legend.gd` row in the CLAUDE.md world-module table.
