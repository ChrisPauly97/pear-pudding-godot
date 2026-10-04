# TID-659: Town Buildings — Footprints, Tall Walls, Roofs, Trim

**Goal:** GID-154
**Type:** agent
**Status:** done
**Depends On:** —

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

See goal. Houses must look like houses in the overworld towns without re-authoring the maps.

## Research Notes

- Walls render via `TerrainMath.build_wall_face_mesh` (per chunk, height = tile height level × `WALL_FACE_H`) and
  collide via `ChunkRenderer._build_walls_physics`; both already honour per-tile wall heights.
- Wall heights do not affect the terrain height field (`get_height_at` only uses walls to suppress hills).
- Town tiles reach chunk data through `RealmLayout.stamp_tile` (called by `InfiniteWorldGen`).
- Rooms: hollow rings with single-tile door gaps; Maykalene's twin rooms share an alley and one room's east wall
  is a separate component, so wall-component bounding boxes are unreliable — detect rooms from their floor instead.
- Many NPCs stand inside houses (Madrian master's house, Maykalene hall); name tags / quest marks are
  `no_depth_test`, and roofs must get out of the way when the player walks in.
- `WorldScene.gd` sits at its line ceiling (BID-055), so the view hangs off `RealmRegions` instead of a new module.

## Plan

Pure `TownBuildings.detect` (rooms from enclosed floor with doorway gaps closed; solid blocks → towers; long walls
→ ramparts) cached per town in `RealmLayout.building_plan`; `stamp_tile` returns the raised height. Pure
`BuildingMesh` builds roof (gabled / pyramid, shingle bands, gables, chimney) and trim (lintels, painted door,
glowing windows). `TownBuildingsView` (owned by `RealmRegions`) spawns them once and fades a roof while the
player is inside its footprint (grown by 1).

## Changes Made

- `game_logic/world/TownBuildings.gd` (new): footprint detection; houses 3 levels, towers 4, ramparts 2, fences as authored.
- `game_logic/world/RealmLayout.gd`: `building_plan()`, `buildings_world()`; `stamp_tile` uses raised heights.
- `game_logic/world/BuildingMesh.gd` (new): roof + trim ArrayMeshes, vertex-coloured.
- `scenes/world/TownBuildingsView.gd` (new): spawns roofs/trim, roof fade on entry.
- `scenes/world/modules/RealmRegions.gd`: owns and ticks `buildings`.
- `tests/unit/test_town_buildings.gd` (new, 6 tests). Full suite 3002/3002, world smoke 0 SCRIPT ERRORs, unsafe-hits,
  gdlint clean; verified visually with xvfb captures (Madrian, Maykalene, roof fade inside).

## Documentation Updates

`docs/agent/named-maps-and-dungeons.md`: "Town buildings" section.
