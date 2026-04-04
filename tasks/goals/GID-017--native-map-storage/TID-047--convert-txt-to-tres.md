# TID-047: Convert .txt Maps to .tres

**Goal:** GID-017
**Type:** agent
**Status:** done
**Depends On:** TID-046

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

Once the `MapData` and entity Resource classes exist (TID-046), this task writes a Python converter script that parses the 6 existing `.txt` maps and outputs `.tres` resource files to `assets/maps/`. The converter is a one-time migration tool.

## Research Notes

**Existing maps** (in `assets/maps/`):
- `main.txt`
- `blancogov.txt`
- `madrian.txt`
- `farsyth_mansion.txt`
- `maykalene.txt`
- `blancogov_temple.txt`

**Reference parser** — `game_logic/world/WorldMap.load_from_string()` is the authoritative parser. The Python converter should mirror its logic:
1. Line 1: `width height`
2. Lines 2–101: tile grid rows (single chars '0'–'3')
3. Optional `HEIGHTS` section: `x,z,h` triplets until next section header
4. `SPAWN x z`
5. `ENEMY x z [type]`
6. `CHEST x z card1,card2,...`
7. `NPC x z [FLAG:key] dialogue [|| after_dialogue]`
8. `DOOR x z target_map [target_door_id] [FLAG:key]`
9. `SCROLL x z scroll_id [FLAG:key]`

**Reference bundler** — `scripts/bundle_maps.py` shows how to iterate the map files.

**`.tres` format** — Godot text resource format. For a Resource with typed sub-resources, the structure is:
```
[gd_resource type="MapData" script_class="MapData" load_steps=N format=3 uid="uid://..."]

[ext_resource type="Script" uid="uid://..." path="res://game_logic/world/resources/MapData.gd" id="1_xxxxx"]
[ext_resource type="Script" uid="uid://..." path="res://game_logic/world/resources/EnemyData.gd" id="2_xxxxx"]
...

[sub_resource type="Resource" id="EnemyData_1"]
script = ExtResource("2_xxxxx")
x = 12
z = 8
...

[resource]
script = ExtResource("1_xxxxx")
map_name = "main"
tiles = PackedInt32Array(0, 0, 1, ...)
...
enemies = Array[ExtResource("2_xxxxx")]([SubResource("EnemyData_1"), ...])
```

**Alternative (simpler)**: generate the `.tres` file using Python's `ResourceSaver` equivalent — actually just write it as text, or better: write a Godot headless script that reads the `.txt` files using `WorldMap` and calls `ResourceSaver.save()`. This avoids reimplementing the parser in Python and reuses the existing GDScript parser exactly.

**Recommended approach**: Write a GDScript runner (`scripts/convert_maps.gd`) that Godot headless can execute:
```bash
godot --headless --path . -s scripts/convert_maps.gd
```
This reuses `WorldMap.load_from_string()` exactly and calls `ResourceSaver.save()` natively — no Python parser to maintain.

**Key files:**
- `assets/maps/*.txt` — source maps
- `scripts/bundle_maps.py` — reference for iterating map files
- `game_logic/world/WorldMap.gd` — existing parser to reuse

## Plan

Approach: Python converter (Godot headless not installed in this environment).

1. Fix bug in `maykalene.txt` — DOOR and SCROLL lines were concatenated without a newline.
2. Write `scripts/convert_maps.py` that mirrors `WorldMap.load_from_string()` logic:
   - Stops tile grid reading when a non-tile line is hit (some maps have < 100 rows)
   - Parses HEIGHTS, SPAWN, ENEMY, CHEST, NPC, MERCHANT, DOOR, SCROLL sections
   - Writes Godot 4 `.tres` text format with ext_resources + sub_resources
3. Run converter → produces 6 `.tres` files in `assets/maps/`
4. Log bug as BID-003.

## Changes Made

- **`assets/maps/maykalene.txt`** — Fixed bug: split concatenated `DOOR ... FLAG:chapter1_warned_farsythSCROLL 52 55 scroll_martarquas_first_war` into two correct lines. The scroll `scroll_martarquas_first_war` at (52,55) was previously lost.
- **`scripts/convert_maps.py`** — New Python converter. Parses all 6 `.txt` maps (handling < 100 tile rows gracefully) and emits `.tres` files using UIDs from TID-046.
- **`assets/maps/*.tres`** — 6 new files: blancogov, blancogov_temple, farsyth_mansion, madrian, main, maykalene. Entity counts: 41 total entities across all maps.
- **`tasks/backlog/BID-003--maykalene-concatenated-door-scroll.md`** — New backlog item documenting the bug (marked fixed).
- **`tasks/index.md`** — Added BID-003 to backlog table.

Notable decisions:
- Map files with < 100 tile rows (blancogov=95, blancogov_temple=96, farsyth_mansion=97, maykalene=95) — converter stops tile reading at first non-tile line; missing rows are implicitly all-grass in the resource (PackedInt32Array default 0).
- Entity positions stored as tile coordinates in the resource (not world coordinates). Conversion: `tile_coord = world_coord / TILE_SIZE`.
- `load_steps` in .tres header = 1 + count(ext_resource declarations).

## Documentation Updates

No agent doc changes. TID-053 updates `named-maps-and-dungeons.md` once the full migration is complete.
