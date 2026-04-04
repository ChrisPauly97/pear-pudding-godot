# TID-047: Convert .txt Maps to .tres

**Goal:** GID-017
**Type:** agent
**Status:** pending
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

_Written during Plan phase._

## Changes Made

_Filled after Build phase._

## Documentation Updates

_What was updated in agent docs._
