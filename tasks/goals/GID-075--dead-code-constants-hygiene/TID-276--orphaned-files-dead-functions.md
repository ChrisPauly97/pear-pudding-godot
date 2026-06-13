# TID-276: Orphaned files and dead functions

**Goal:** GID-075
**Type:** agent
**Status:** pending
**Depends On:** —

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

Pure deletion task; resolves BID-004 (extended — the sweep found 5 more orphans than originally logged). Both orphaned .uid sidecars and never-called functions are blocking clean imports and test clarity. Removes cruft that violates the single-responsibility and YAGNI principles.

## Research Notes

### Orphaned .uid sidecars (8 total)
- `scenes/ui/ChestOpenScene.gd.uid`
- `game_logic/world/BundledMaps.gd.uid`
- `game_logic/world/ProceduralGen.gd.uid` (the 3 originally in BID-004)
- `data/cards/ash_warden.uid`
- `data/cards/dawn_healer.uid`
- `data/cards/dusk_seer.uid`
- `data/cards/ember_imp.uid`
- `data/cards/void_creeper.uid`

**Note:** Card sidecars are `<name>.uid` not `.tres.uid` — verify the corresponding .tres truly doesn't exist before deleting, and check CardRegistry.gd doesn't reference these ids.

### Dead WorldMap.gd functions (9 total, zero call sites each)
- `is_wall_at_world` (line 99)
- `get_wall_height_at_world` (104)
- `get_hill_height_at_world` (111)
- `find_nearby_enemy` (121)
- `find_nearby_chest` (131)
- `find_nearby_door` (141)
- `find_nearby_npc` (150)
- `find_nearby_scroll` (159)
- `all_enemies_defeated` (174)

**Note:** WorldScene has private `_find_nearby_*` versions that are the live implementations. CAUTION: re-grep each name (including tests/) before deleting; GID-072 TID-268 may extract WorldScene's versions into a ProximityFinder — coordinate, the WorldMap copies die either way.

### Dead WorldScene function
- `flush_time_of_day` (WorldScene.gd:379–380) — also flagged in GID-072 TID-268; whoever runs first deletes it.

### Dead SaveManager functions
- **Handled by GID-074 TID-274** — do NOT delete them here (avoid conflicts).

## Plan

_Written during Plan phase._

## Changes Made

_Filled after Build phase._

## Documentation Updates

_What was updated in agent docs._
