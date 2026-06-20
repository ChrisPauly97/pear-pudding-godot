# TID-276: Orphaned files and dead functions

**Goal:** GID-075
**Type:** agent
**Status:** done
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

1. Delete `game_logic/world/BundledMaps.gd.uid` and `ProceduralGen.gd.uid` (no corresponding .gd files).
2. For 10 card `.uid` files that use wrong naming format (no `.tres.`): read UID from each, create `<name>.tres.uid` with same content, delete old `<name>.uid`. Cards affected: ash_arbiter, dawn_healer, dusk_seer, ember_covenant, ember_imp, hallowed_ground, pyre_warden, sacred_light, twilight_veil, void_creeper.
3. Delete 8 dead functions from `game_logic/world/WorldMap.gd`: `get_wall_height_at_world`, `get_hill_height_at_world`, `find_nearby_enemy`, `find_nearby_chest`, `find_nearby_door`, `find_nearby_npc`, `find_nearby_scroll`, `all_enemies_defeated`. Keep `is_wall_at_world` (used in test_cracked_wall_interact.gd). Keep WorldScene.flush_time_of_day (called by SceneManager via has_method).

## Changes Made

- **DELETED `game_logic/world/BundledMaps.gd.uid`** and **`game_logic/world/ProceduralGen.gd.uid`**: orphaned `.uid` sidecars with no corresponding `.gd` files (leftovers from GID-017 map migration). Resolves BID-004.
- **RENAMED 10 card `.uid` files → `.tres.uid`**: `ash_arbiter`, `dawn_healer`, `dusk_seer`, `ember_covenant`, `ember_imp`, `hallowed_ground`, `pyre_warden`, `sacred_light`, `twilight_veil`, `void_creeper` — all had wrong-format sidecars (`<name>.uid` instead of `<name>.tres.uid`). Created correct-format `.tres.uid` files with same UID content and deleted old `.uid` files.
- **MODIFIED `game_logic/world/WorldMap.gd`**: Removed 8 dead functions — `get_wall_height_at_world`, `get_hill_height_at_world`, `find_nearby_enemy`, `find_nearby_chest`, `find_nearby_door`, `find_nearby_npc`, `find_nearby_scroll`, `all_enemies_defeated`. Kept `is_wall_at_world` (used by `test_cracked_wall_interact.gd`).

## Documentation Updates

No agent docs update needed — deletion-only changes.
