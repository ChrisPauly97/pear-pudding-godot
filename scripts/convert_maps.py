#!/usr/bin/env python3
"""Convert assets/maps/*.txt to assets/maps/*.tres (Godot 4 MapData resources).

One-time migration tool for GID-017. Mirrors the parsing logic in
game_logic/world/WorldMap.load_from_string() and writes Godot 4 text
resource (.tres) files.

Usage:
    python3 scripts/convert_maps.py
"""

import glob
import os
import random
import string
import sys

# ---------------------------------------------------------------------------
# Config
# ---------------------------------------------------------------------------

MAPS_DIR = os.path.join(os.path.dirname(__file__), "..", "assets", "maps")
MAP_WIDTH = 100
MAP_HEIGHT = 100

# UIDs match the .uid sidecar files created in TID-046.
SCRIPT_UIDS = {
    "MapData":   "uid://fycqebooc6ig",
    "MapEnemy":  "uid://2euwyq0xb3oo",
    "MapChest":  "uid://zbrrvlvybh24",
    "MapDoor":   "uid://r18om43tz40b",
    "MapNpc":    "uid://pz39p9z9yzt7",
    "MapScroll": "uid://l2exioez3eml",
}
SCRIPT_PATHS = {
    "MapData":   "res://game_logic/world/resources/MapData.gd",
    "MapEnemy":  "res://game_logic/world/resources/MapEnemy.gd",
    "MapChest":  "res://game_logic/world/resources/MapChest.gd",
    "MapDoor":   "res://game_logic/world/resources/MapDoor.gd",
    "MapNpc":    "res://game_logic/world/resources/MapNpc.gd",
    "MapScroll": "res://game_logic/world/resources/MapScroll.gd",
}
# Canonical ordering for ext_resource declarations.
ENTITY_TYPES = ["MapEnemy", "MapChest", "MapDoor", "MapNpc", "MapScroll"]


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def rand_uid() -> str:
    chars = string.ascii_lowercase + string.digits
    return "uid://" + "".join(random.choices(chars, k=12))


def gdstr(s: str) -> str:
    """Escape and quote a string for use in a .tres file."""
    return '"' + s.replace("\\", "\\\\").replace('"', '\\"') + '"'


# ---------------------------------------------------------------------------
# Parser  (mirrors WorldMap.load_from_string)
# ---------------------------------------------------------------------------

def parse_txt(content: str) -> dict:
    lines = content.split("\n")

    tiles: list[int] = [0] * (MAP_WIDTH * MAP_HEIGHT)
    heights: list[int] = [0] * (MAP_WIDTH * MAP_HEIGHT)
    spawn_x: int = 5
    spawn_z: int = 5
    enemies: list[dict] = []
    chests: list[dict] = []
    doors: list[dict] = []
    npcs: list[dict] = []
    scrolls: list[dict] = []

    uid_counter = 0
    line_idx = 1  # skip line 0 (dimensions header)

    # --- Tile grid (up to MAP_HEIGHT rows) ---
    # Some .txt files omit trailing all-grass rows. Stop early if a non-tile
    # line is encountered (e.g. "HEIGHTS") and leave those rows as 0 (grass).
    for tz in range(MAP_HEIGHT):
        if line_idx >= len(lines):
            break
        row = lines[line_idx].strip()
        # Detect non-tile lines (headers, entity lines) and stop the grid loop.
        if row and not all(c in "0123" for c in row):
            break  # line_idx stays at this line; remainder loop will process it
        line_idx += 1
        for tx in range(min(len(row), MAP_WIDTH)):
            tiles[tz * MAP_WIDTH + tx] = int(row[tx])

    # --- Remainder: sections and entity lines ---
    in_heights = False
    while line_idx < len(lines):
        line = lines[line_idx].strip()
        line_idx += 1
        if not line:
            continue

        if line == "HEIGHTS":
            in_heights = True
            continue

        if line.startswith("SPAWN "):
            parts = line.split(" ")
            if len(parts) >= 3:
                spawn_x = int(parts[1])
                spawn_z = int(parts[2])

        elif line.startswith("ENEMY "):
            parts = line.split(" ")
            if len(parts) >= 3:
                uid_counter += 1
                etype = parts[3] if len(parts) >= 4 else "undead_basic"
                enemies.append({
                    "id": f"enemy_{uid_counter}",
                    "tile_x": int(parts[1]),
                    "tile_z": int(parts[2]),
                    "enemy_type": etype,
                })

        elif line.startswith("CHEST "):
            parts = line.split(" ")
            if len(parts) >= 4:
                uid_counter += 1
                card_ids = [c.strip() for c in parts[3].split(",")]
                chests.append({
                    "id": f"chest_{uid_counter}",
                    "tile_x": int(parts[1]),
                    "tile_z": int(parts[2]),
                    "card_ids": card_ids,
                })

        elif line.startswith("NPC "):
            # split into at most 4 parts: ["NPC", x, z, rest-of-line]
            parts = line.split(" ", 3)
            if len(parts) >= 3:
                uid_counter += 1
                raw = parts[3] if len(parts) >= 4 else "..."
                flag_key = ""
                after_dialogue = ""
                dialogue = raw
                if raw.startswith("FLAG:"):
                    space_idx = raw.find(" ")
                    if space_idx > 0:
                        flag_key = raw[5:space_idx]
                        rest = raw[space_idx + 1:]
                        sep_idx = rest.find(" || ")
                        if sep_idx >= 0:
                            dialogue = rest[:sep_idx]
                            after_dialogue = rest[sep_idx + 4:]
                        else:
                            dialogue = rest
                npcs.append({
                    "id": f"npc_{uid_counter}",
                    "tile_x": int(parts[1]),
                    "tile_z": int(parts[2]),
                    "dialogue": dialogue,
                    "npc_type": "",
                    "flag_key": flag_key,
                    "after_dialogue": after_dialogue,
                })

        elif line.startswith("MERCHANT "):
            parts = line.split(" ")
            if len(parts) >= 3:
                uid_counter += 1
                npcs.append({
                    "id": f"merchant_{uid_counter}",
                    "tile_x": int(parts[1]),
                    "tile_z": int(parts[2]),
                    "dialogue": "Welcome, traveller! Browse my wares.",
                    "npc_type": "merchant",
                    "flag_key": "",
                    "after_dialogue": "",
                })

        elif line.startswith("DOOR "):
            parts = line.split(" ")
            if len(parts) >= 4:
                uid_counter += 1
                target = "" if parts[3] == "__exit__" else parts[3]
                tdoor = ""
                flag_key = ""
                if len(parts) >= 5:
                    if parts[4].startswith("FLAG:"):
                        flag_key = parts[4][5:]
                    else:
                        tdoor = parts[4]
                        if len(parts) >= 6 and parts[5].startswith("FLAG:"):
                            flag_key = parts[5][5:]
                doors.append({
                    "id": f"door_{uid_counter}",
                    "tile_x": int(parts[1]),
                    "tile_z": int(parts[2]),
                    "target_map": target,
                    "target_door_id": tdoor,
                    "flag_key": flag_key,
                })

        elif line.startswith("SCROLL "):
            parts = line.split(" ")
            if len(parts) >= 4:
                uid_counter += 1
                scroll_id = parts[3]
                flag_key = ""
                for p in parts:
                    if p.startswith("FLAG:"):
                        flag_key = p[5:]
                scrolls.append({
                    "id": f"scroll_{uid_counter}",
                    "tile_x": int(parts[1]),
                    "tile_z": int(parts[2]),
                    "scroll_id": scroll_id,
                    "flag_key": flag_key,
                })

        elif in_heights:
            height_parts = line.split(",")
            if len(height_parts) == 3:
                tx = int(height_parts[0])
                tz = int(height_parts[1])
                h = int(height_parts[2])
                if 0 <= tx < MAP_WIDTH and 0 <= tz < MAP_HEIGHT:
                    heights[tz * MAP_WIDTH + tx] = h

    return {
        "tiles": tiles,
        "heights": heights,
        "spawn_x": spawn_x,
        "spawn_z": spawn_z,
        "enemies": enemies,
        "chests": chests,
        "doors": doors,
        "npcs": npcs,
        "scrolls": scrolls,
    }


# ---------------------------------------------------------------------------
# .tres writer
# ---------------------------------------------------------------------------

def write_tres(map_name: str, data: dict, out_path: str) -> None:
    """Emit a Godot 4 text resource file for the given parsed map data."""

    # Which entity script types are actually used in this map?
    used_types: set[str] = set()
    if data["enemies"]:
        used_types.add("MapEnemy")
    if data["chests"]:
        used_types.add("MapChest")
    if data["doors"]:
        used_types.add("MapDoor")
    if data["npcs"]:
        used_types.add("MapNpc")
    if data["scrolls"]:
        used_types.add("MapScroll")

    # Assign ext_resource IDs: MapData is always "1_mapdata"; entities follow.
    ext_ids: dict[str, str] = {"MapData": "1_mapdata"}
    counter = 2
    for t in ENTITY_TYPES:
        if t in used_types:
            ext_ids[t] = f"{counter}_{t.lower()}"
            counter += 1

    num_ext = 1 + len(used_types)  # MapData + used entity scripts
    # load_steps = 1 (main resource) + ext_resources
    load_steps = 1 + num_ext
    tres_uid = rand_uid()

    out: list[str] = []

    # --- Header ---
    out.append(
        f'[gd_resource type="Resource" script_class="MapData" '
        f'load_steps={load_steps} format=3 uid="{tres_uid}"]'
    )
    out.append("")

    # --- Ext resources ---
    out.append(
        f'[ext_resource type="Script" uid="{SCRIPT_UIDS["MapData"]}" '
        f'path="{SCRIPT_PATHS["MapData"]}" id="{ext_ids["MapData"]}"]'
    )
    for t in ENTITY_TYPES:
        if t in ext_ids:
            out.append(
                f'[ext_resource type="Script" uid="{SCRIPT_UIDS[t]}" '
                f'path="{SCRIPT_PATHS[t]}" id="{ext_ids[t]}"]'
            )
    out.append("")

    # --- Sub-resources ---
    sub_ids: dict[str, list[str]] = {}

    for i, e in enumerate(data["enemies"]):
        sid = f"MapEnemy_{i + 1}"
        out += [
            f'[sub_resource type="Resource" id="{sid}"]',
            f'script = ExtResource("{ext_ids["MapEnemy"]}")',
            f'entity_id = {gdstr(e["id"])}',
            f'tile_x = {e["tile_x"]}',
            f'tile_z = {e["tile_z"]}',
            f'enemy_type = {gdstr(e["enemy_type"])}',
            "",
        ]
        sub_ids.setdefault("enemies", []).append(sid)

    for i, c in enumerate(data["chests"]):
        sid = f"MapChest_{i + 1}"
        cids = ", ".join(gdstr(cid) for cid in c["card_ids"])
        out += [
            f'[sub_resource type="Resource" id="{sid}"]',
            f'script = ExtResource("{ext_ids["MapChest"]}")',
            f'entity_id = {gdstr(c["id"])}',
            f'tile_x = {c["tile_x"]}',
            f'tile_z = {c["tile_z"]}',
            f'card_ids = PackedStringArray({cids})',
            "",
        ]
        sub_ids.setdefault("chests", []).append(sid)

    for i, d in enumerate(data["doors"]):
        sid = f"MapDoor_{i + 1}"
        out += [
            f'[sub_resource type="Resource" id="{sid}"]',
            f'script = ExtResource("{ext_ids["MapDoor"]}")',
            f'entity_id = {gdstr(d["id"])}',
            f'tile_x = {d["tile_x"]}',
            f'tile_z = {d["tile_z"]}',
            f'target_map = {gdstr(d["target_map"])}',
            f'target_door_id = {gdstr(d["target_door_id"])}',
            f'flag_key = {gdstr(d["flag_key"])}',
            "",
        ]
        sub_ids.setdefault("doors", []).append(sid)

    for i, n in enumerate(data["npcs"]):
        sid = f"MapNpc_{i + 1}"
        out += [
            f'[sub_resource type="Resource" id="{sid}"]',
            f'script = ExtResource("{ext_ids["MapNpc"]}")',
            f'entity_id = {gdstr(n["id"])}',
            f'tile_x = {n["tile_x"]}',
            f'tile_z = {n["tile_z"]}',
            f'dialogue = {gdstr(n["dialogue"])}',
            f'npc_type = {gdstr(n["npc_type"])}',
            f'flag_key = {gdstr(n["flag_key"])}',
            f'after_dialogue = {gdstr(n["after_dialogue"])}',
            "",
        ]
        sub_ids.setdefault("npcs", []).append(sid)

    for i, s in enumerate(data["scrolls"]):
        sid = f"MapScroll_{i + 1}"
        out += [
            f'[sub_resource type="Resource" id="{sid}"]',
            f'script = ExtResource("{ext_ids["MapScroll"]}")',
            f'entity_id = {gdstr(s["id"])}',
            f'tile_x = {s["tile_x"]}',
            f'tile_z = {s["tile_z"]}',
            f'scroll_id = {gdstr(s["scroll_id"])}',
            f'flag_key = {gdstr(s["flag_key"])}',
            "",
        ]
        sub_ids.setdefault("scrolls", []).append(sid)

    # --- Main resource block ---
    def array_field(key: str) -> str:
        ids = sub_ids.get(key, [])
        if not ids:
            return "[]"
        inner = ", ".join(f'SubResource("{sid}")' for sid in ids)
        return f"[{inner}]"

    tiles_str = ", ".join(str(t) for t in data["tiles"])
    heights_str = ", ".join(str(h) for h in data["heights"])

    out += [
        "[resource]",
        f'script = ExtResource("{ext_ids["MapData"]}")',
        f'map_name = {gdstr(map_name)}',
        f"width = {MAP_WIDTH}",
        f"height = {MAP_HEIGHT}",
        f"tiles = PackedInt32Array({tiles_str})",
        f"heights = PackedInt32Array({heights_str})",
        f"spawn_x = {data['spawn_x']}",
        f"spawn_z = {data['spawn_z']}",
        f"enemies = {array_field('enemies')}",
        f"chests = {array_field('chests')}",
        f"doors = {array_field('doors')}",
        f"npcs = {array_field('npcs')}",
        f"scrolls = {array_field('scrolls')}",
        'triggers = []',
        'regions = []',
        'music_track = ""',
        "difficulty = 0",
        'author = ""',
        "version = 1",
        "",
    ]

    content = "\n".join(out)
    with open(out_path, "w", encoding="utf-8") as f:
        f.write(content)

    total_entities = sum(
        len(data[k]) for k in ("enemies", "chests", "doors", "npcs", "scrolls")
    )
    print(
        f"  {map_name}.tres — {total_entities} entities "
        f"({len(data['enemies'])}e {len(data['chests'])}c "
        f"{len(data['doors'])}d {len(data['npcs'])}n {len(data['scrolls'])}s)"
    )


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

def main() -> None:
    files = sorted(glob.glob(os.path.join(MAPS_DIR, "*.txt")))
    if not files:
        print("No .txt map files found in assets/maps/", file=sys.stderr)
        sys.exit(1)

    print(f"Converting {len(files)} maps...")
    for fpath in files:
        map_name = os.path.splitext(os.path.basename(fpath))[0]
        with open(fpath, encoding="utf-8") as f:
            content = f.read()
        data = parse_txt(content)
        out_path = os.path.join(MAPS_DIR, f"{map_name}.tres")
        write_tres(map_name, data, out_path)

    print("Done.")


if __name__ == "__main__":
    main()
