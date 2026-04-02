# TID-039: Embed Inn/Building Interiors into Parent Named Maps

**Goal:** GID-015
**Type:** agent
**Status:** pending
**Depends On:** —

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

Three named maps currently exist solely as destinations for DOOR entities within their parent town maps. Entering them causes a full scene reload (loading screen). The parent maps already have the building wall geometry in their tile grids — the DOORs are just entity markers at wall gaps. This task eliminates the sub-maps by placing their NPC/MERCHANT entities directly within the parent map at the correct tile coordinates, and removing the DOOR entities that pointed to them.

## Research Notes

### Sub-maps to eliminate

| Sub-map file | Parent map | DOOR in parent | Exit door in sub-map |
|---|---|---|---|
| `madrian_inn.txt` | `madrian.txt` | `DOOR 39 32 madrian_inn door_inn_exit` | `DOOR 12 16 __exit__ door_inn_exit` |
| `madrian_masters_house.txt` | `madrian.txt` | `DOOR 11 18 madrian_masters_house door_masters_exit` | `DOOR 10 14 __exit__ door_masters_exit` |
| `maykalene_inn.txt` | `maykalene.txt` | `DOOR 57 58 maykalene_inn door_inn_exit` | `DOOR 11 14 __exit__ door_inn_exit` |

### Building footprints in parent maps

**madrian.txt — inn building** (the building at rows z=22–32, cols x=33–45):
- Walls: top row z=22 (cols 33–45), bottom row z=32 (cols 33–45 with gap at x=39), sides x=33 and x=45
- Interior walkable space: x=34–44, z=23–31
- Door gap at (39, 32) — currently blocked by the DOOR entity; leaving it as-is (open gap) makes the building enterable by walking in

**madrian_inn.txt — entities to translate into madrian.txt:**
Offset to use: interior origin of the inn building in madrian is approximately (34, 23). The inn sub-map has its room at cols 5–20, rows 5–16; interior at cols 6–19, rows 6–15.
Translate by: x_new = x_sub - 6 + 36, z_new = z_sub - 6 + 25 (centers the room in the available space)

| Original (inn coords) | Translated (madrian coords) | Content |
|---|---|---|
| NPC 8 8 | NPC 38 27 | Welcome to the inn! Rest your weary bones here. |
| NPC 15 10 | NPC 43 28 | I heard strange noises coming from the temple last night. |
| NPC 10 12 | NPC 38 30 | The ale here is the finest in all of Madrian. |
| MERCHANT 18 8 | MERCHANT 44 25 | — |

**madrian.txt — master's house building** (building at rows z=8–18, cols x=5–17):
- Walls: top row z=8, bottom row z=18 (gap at x=11), sides x=5 and x=17
- Interior walkable space: x=6–16, z=9–17

**madrian_masters_house.txt — entities to translate:**
Sub-map interior at cols 5–17, rows 5–16. Translate: x_new = x_sub + 2, z_new = z_sub + 4

| Original (sub-map coords) | Translated (madrian coords) | Content |
|---|---|---|
| NPC 8 8 | NPC 10 12 | You dare enter my house? Get out before I call the guards! |
| NPC 12 10 | NPC 14 14 | Shh... the master is in a foul mood today. Best stay quiet. |

**maykalene.txt — inn building:**
The DOOR is at (57, 58). Need to identify the building walls around that position in maykalene.txt to determine the interior footprint. The inn building walls must surround tile (57, 58). Read the tile rows around z=50–65, cols x=52–65 to find the enclosing walls. Place entities centrally within the enclosed space.

**maykalene_inn.txt — entities to translate:**
| Original (inn coords) | Translated (maykalene coords) | Content |
|---|---|---|
| NPC 8 8 | TBD — read building footprint | Welcome to Maykalene! The port city of the eastern coast. |
| NPC 14 10 | TBD | Be wary of the Farsyth mansion on the hill. Strange things happen there. |
| MERCHANT 16 8 | TBD | — |

### Files to edit
- `assets/maps/madrian.txt` — remove 2 DOOR lines, add 4 NPC + 1 MERCHANT + 2 NPC lines
- `assets/maps/maykalene.txt` — remove 1 DOOR line, add 2 NPC + 1 MERCHANT lines

### Files to delete
- `assets/maps/madrian_inn.txt`
- `assets/maps/madrian_masters_house.txt`
- `assets/maps/maykalene_inn.txt`

### No GDScript changes required
The DOOR entity-to-sub-map mechanism is handled entirely by `SceneManager.enter_map()`. Removing the DOOR directives from the map files means no doors will be spawned at those positions and no map transitions will be triggered. The wall gaps remain open (tile type 0 = grass at door positions), so the buildings are enterable by walking in.

### Also clean up dev-test doors in madrian.txt
`madrian.txt` has a cluster of developer-convenience doors at z=50 and z=56 that are not part of the story and clutter the map. These should be removed as part of this task:
```
DOOR 65 50 house_1      ← dev test
DOOR 70 50 test         ← dev test
DOOR 75 50 maykalene_inn  ← will be eliminated anyway
```
Keep the story-relevant doors: `DOOR 50 99 maykalene`, `DOOR 60 50 main`, `DOOR 80 50 farsyth_mansion`, `DOOR 85 50 blancogov`, `DOOR 60 56 blancogov_temple`, `DOOR 65 56 infinite`.

Also delete `assets/maps/house_1.txt` and `assets/maps/test.txt` if they have no story role (confirm they are dev-only before deleting).

### docs/agent/named-maps-and-dungeons.md
After completing changes, update the Asset Requirements table to remove the eliminated map files, and note that building interiors are embedded in-map rather than as separate files.

## Plan

_Written during Plan phase._

## Changes Made

_Filled after Build phase._

## Documentation Updates

_What was updated in agent docs._
