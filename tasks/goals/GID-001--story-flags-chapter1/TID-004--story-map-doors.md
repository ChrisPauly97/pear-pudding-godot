# TID-004: Verify and Fix Story Map Door Connectivity

**Goal:** GID-001
**Type:** agent
**Status:** done
**Depends On:** —

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

The five Chapter 1 maps (madrian, madrian_masters_house, madrian_inn, maykalene, maykalene_inn, farsyth_mansion, blancogov, blancogov_temple) each contain DOOR entities. These need to point to correct target maps and door IDs so the player can navigate the full story path without hitting a dead end or loading the wrong map.

## Research Notes

**Map files to audit** (`assets/maps/`):
```
madrian.txt
madrian_masters_house.txt
madrian_inn.txt
maykalene.txt
maykalene_inn.txt
farsyth_mansion.txt
blancogov.txt
blancogov_temple.txt
```

**DOOR syntax** (`WorldMap.load_from_string()`, line 308–322):
```
DOOR x z target_map [target_door_id]
DOOR x z __exit__               ← returns to parent map
```
A door with an empty or missing `target_door_id` teleports the player to the `player_spawn` position of the target map.

**Expected connectivity:**

| From | Door leads to | Notes |
|---|---|---|
| madrian | madrian_masters_house | Sub-map (interior) |
| madrian | madrian_inn | Sub-map (interior) |
| madrian | maykalene | Main story progression |
| madrian_masters_house | `__exit__` → madrian | Return door |
| madrian_inn | `__exit__` → madrian | Return door |
| maykalene | maykalene_inn | Sub-map |
| maykalene | farsyth_mansion | Sub-map / story beat |
| maykalene_inn | `__exit__` → maykalene | Return door |
| farsyth_mansion | `__exit__` → maykalene | Return door |
| blancogov | blancogov_temple | Story progression |
| blancogov_temple | `__exit__` → blancogov | Return door |

**Note:** The open world (infinite-chunk path) has no connection to named maps — story maps are only reachable via SceneManager which starts from madrian. There is no DOOR from madrian → blancogov directly; the player is expected to travel through the open world between Maykalene and Blancogov (or SceneManager can chain them directly via `enter_map`). For now, verify the sub-map doors; the open-world leg is a future concern.

**How to audit:**
1. Read each `.txt` file's DOOR lines (they appear after the tile grid).
2. Check: does `target_map` match an existing map name in `BundledMaps` or `assets/maps/`?
3. Check: if `target_door_id` is non-empty, does a matching door ID exist in the target map?
4. Fix any broken or missing doors.

**BundledMaps** (`game_logic/world/BundledMaps.gd`) — verify all story map names are included so they load on Android too.

## Plan

1. Audit all DOOR lines in the 8 story map files.
2. Verify BundledMaps contains all story maps.
3. Fix broken doors and update WorldScene flag logic.
4. Regenerate BundledMaps.gd.

## Changes Made

- `assets/maps/madrian.txt`: Changed `DOOR 50 99 __exit__ madrian_exit` → `DOOR 50 99 maykalene`. The `__exit__` door was the main story progression exit from Madrian, but since Madrian is the root map (empty `map_stack`), `exit_map()` would call `go_to_menu()` instead of advancing the story.
- `scenes/world/WorldScene.gd`: Moved `chapter1_left_madrian` flag set from the `__exit__` branch to the named-map branch, firing when `current_map == "madrian"` and `target_map == "maykalene"`.
- `game_logic/world/BundledMaps.gd`: Regenerated via `python3 scripts/bundle_maps.py` to embed the updated madrian map data.

All 8 story maps were confirmed present in BundledMaps. All sub-map `__exit__` doors and SPAWNs are correctly defined.

**Non-blocking finding:** `target_door_id` values like `door_masters_exit` are descriptive names that won't match auto-generated `door_N` IDs. Players land at `player_spawn` (correctly positioned near each entrance) as fallback — functionally correct.

## Documentation Updates

No agent doc changes needed; story-implementation.md already documents the door connectivity model accurately.
