# TID-660: Town Streets & Grimy Street Lamps

**Goal:** GID-155
**Type:** agent
**Status:** done
**Depends On:** —

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

See goal. Streets and lamps must come from the existing town maps (no re-authoring).

## Research Notes

- Town tiles reach chunks through `RealmLayout.stamp_tile`; `TILE_PATH` is already drawn (terrain shader), walkable
  (Pathfinder, TapToMove), mapped (minimap / map view) and paved for footsteps — the realm roads use it.
- `TownBuildings.detect` gives house rects + doorway gaps; door entities live in `WorldMap.doors`.
- `NightLights` already pools night lights (glow dot, depth-reconstructed pool, optional OmniLight3D) from sources
  WorldScene tracks; a new style + source list is all a new light kind needs.
- `WorldScene.gd` is at its line ceiling (BID-055) — the view hangs off `RealmRegions` like `TownBuildingsView`.

## Plan

Pure `TownStreets.plan` (BFS routes gate → spawn trunk 3 wide, door lanes 1 wide, straight walk-back; lamps every
7 steps beside routes) cached in `RealmLayout.street_plan`; `stamp_tile` paves planned grass. Pure `StreetLampMesh`
(iron + glass surfaces, vertex grime) instanced per town by `TownStreetsView` (owned by `RealmRegions`), glass glow
from the night factor. `NightLights` gathers lamps as `street_lamp` sources; pooled rigs always carry a real omni.

## Changes Made

- `game_logic/world/TownStreets.gd` (new): street + lamp planner.
- `game_logic/world/RealmLayout.gd`: `street_plan()`, `street_lamps_world()`; `stamp_tile` paves street grass.
- `game_logic/world/StreetLampMesh.gd` (new), `assets/shaders/street_lamp_glass.gdshader` (new).
- `scenes/world/TownStreetsView.gd` (new): MultiMesh lamps per town, glass glow follows night.
- `scenes/world/modules/RealmRegions.gd`: owns/ticks `streets`.
- `game_logic/NightLightMath.gd`: `street_lamp` style. `scenes/world/modules/NightLights.gd`: lamp sources on the
  overworld; omni on every pooled rig (shadows still knob-gated).
- `tests/unit/test_town_streets.gd` (new, 4 tests). Full suite pass, world smoke 0 SCRIPT ERRORs, unsafe-hits and
  gdlint clean; lamp render checked with an xvfb capture. Plans: Madrian 189 street tiles / 19 lamps, Maykalene
  441 / 42, Blancogov 257 / 13, Larik 107 / 6, Marsax Hold 210 / 13 (≤ 80 ms per town, once).

## Documentation Updates

`docs/agent/named-maps-and-dungeons.md`: "Town streets and street lamps" section. `docs/agent/visual-polish.md`:
night-light style + omni change. `CLAUDE.md`: Map Storage note.
