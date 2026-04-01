# TID-025: Update Fixed Maps — Path Tiles + Merchants

**Goal:** GID-011
**Type:** agent
**Status:** pending
**Depends On:** TID-024

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

With TILE_PATH (digit `3`) supported by the engine after TID-024, this task stamps path tiles onto the two town maps and adds MERCHANT NPCs to both inn maps. All changes must also be reflected in `BundledMaps.gd` — the compiled GDScript that embeds map content for Android export.

## Research Notes

### Maps to change

#### `assets/maps/madrian_inn.txt`
Current: 3 dialogue NPCs at (8,8), (15,10), (10,12). No merchant.
Building interior: walls at rows 6–16, cols 5–20. Door exits at (12,16).
Add merchant (innkeeper behind counter) at **`MERCHANT 18 8`** — right side of the inn near the wall, distinct from the dialogue NPCs.

#### `assets/maps/maykalene_inn.txt`
Current: 2 NPCs at (8,8), (14,10). No merchant.
Building interior: walls at rows 6–15, cols 5–18. Door exits at (11,14).
Add merchant at **`MERCHANT 16 8`** — right side of the interior.

#### `assets/maps/madrian.txt`
Current layout (relevant doors):
- Master's house door: `DOOR 11 18 madrian_masters_house door_masters_exit` → tile (11, 18)
- Inn door: `DOOR 39 32 madrian_inn door_inn_exit` → tile (39, 32)
- South exit: `DOOR 50 99 maykalene` → tile (50, 99)

Path plan — stamp `3` in the tile grid:
1. **Vertical path** from master's house door southward: tiles (11, 19)–(11, 31) — a 1-tile-wide north–south spine
2. **Horizontal connector** from spine to inn door: tiles (12, 31)–(39, 31) and then (39, 32) is the door itself (keep as `0`, door spawns on top)
3. **Path to south exit**: tiles (39, 33)–(50, 33) then (50, 34)–(50, 98) — a path leading down to the exit — this is optional/long; at minimum do (39, 33)–(50, 33) for the town square feel

Keep tile grid row indices: the tile grid is 100 rows (z=0..99). Row z is file line `z+2` (line 1 = dimensions, lines 2–101 = rows z=0..99).

To stamp path tiles: for each affected row, replace the character at column x with `'3'`. Each row is exactly 98 characters wide (cols 0–97, the file shows 98 digits per line even though MAP_WIDTH is declared as 100 — check actual line length when reading).

**Important**: inspect actual line widths in madrian.txt before editing. The tile parser reads `min(line.length(), MAP_WIDTH)` chars, so lines may be 98 chars (the first 98 of the 100 declared cols, with cols 98–99 implied as 0/grass).

#### `assets/maps/maykalene.txt`
Current layout (relevant doors):
- Inn door: `DOOR 57 58 maykalene_inn door_inn_exit` → tile (57, 58)
- Mansion door: `DOOR 49 98 farsyth_mansion door_mansion_exit` → tile (49, 98)
- North entry: `SPAWN 50 5`

Path plan:
1. **Central north–south spine**: tiles x=50, z=6 through z=57 (entry to inn door row)
2. **Inn door connector**: tiles x=51..57, z=58 (reaching inn at (57,58))
3. **Spine south**: tiles x=50, z=59 through z=97 (heading toward mansion)
4. **Mansion connector**: tiles x=49..50, z=98 row (in front of mansion door)

Maykalene is a large map (100×100 used fully) with many building clusters. Restrict paths to the main spine between spawn and inn/mansion doors; don't path between every individual building (that is future work).

### `BundledMaps.gd` update

`BundledMaps.gd` embeds all map content in a `const DATA: Dictionary` starting at line 14. Each entry maps the map name (String key) to the full map text (String value, multiline). After updating the `.txt` files, read each updated map file's content and replace the corresponding string in BundledMaps.gd.

The file is large (54 000+ tokens). Strategy:
1. Read the updated `.txt` file content for each changed map.
2. Use `Grep` to find the line range of each map's entry in `BundledMaps.gd` (search for e.g. `"madrian_inn"` as the key).
3. Use `Edit` to replace only the relevant string value for each map, not the entire file.

Map keys expected in DATA: `"main"`, `"madrian"`, `"maykalene"`, `"madrian_inn"`, `"maykalene_inn"`, `"madrian_masters_house"`, `"house_1"`, `"blancogov"`, `"blancogov_temple"`, `"farsyth_mansion"`, `"test"`.

### Exact edit workflow per map
1. Open the `.txt` file with `Read`.
2. For path tiles: identify rows that need `3` stamps; reconstruct the row string with replacements.
3. Use `Edit` on the `.txt` file to replace affected rows one at a time (each row is unique by its column pattern).
4. After all `.txt` edits, find the block in `BundledMaps.gd` for each changed map and replace its content string.

### Merchant placement rationale
- Innkeeper/merchant is placed on the right/far side of the inn interior — away from the door spawn position and the existing dialogue NPCs — so the player doesn't immediately bump into them on entry.
- The merchant uses the same `MERCHANT x z` directive format as WorldMap.gd parser expects (lines 335–345 of WorldMap.gd).

## Plan

_Written during Plan phase._

## Changes Made

_Filled after Build phase._

## Documentation Updates

_What was updated in agent docs._
