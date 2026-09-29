#!/usr/bin/env python3
"""Append a MapNpc sub-resource to a named map .tres and register it in `npcs`.

Usage: scripts/add_map_npc.py <map> <entity_id> <tile_x> <tile_z> <dialogue> [npc_type] [flag_key]
       [--hide <hide_flag_key>] [--after <after_dialogue>]
Idempotent: an existing entity_id is left alone.
"""
import re
import sys


def main() -> None:
    args = sys.argv[1:]
    opts = {}
    for key in ("--hide", "--after", "--show"):
        if key in args:
            i = args.index(key)
            opts[key] = args[i + 1]
            del args[i:i + 2]
    name, eid, tx, tz, dialogue = args[:5]
    npc_type = args[5] if len(args) > 5 else ""
    flag_key = args[6] if len(args) > 6 else ""
    path = f"assets/maps/{name}.tres"
    s = open(path).read()
    if f'entity_id = "{eid}"\n' in s:
        print(f"{eid} already in {name}")
        return
    nums = [int(n) for n in re.findall(r'id="MapNpc_(\d+)"', s)]
    rid = f"MapNpc_{max(nums, default=0) + 1}"
    esc = dialogue.replace('"', '\\"')
    block = (f'[sub_resource type="Resource" id="{rid}"]\nscript = ExtResource("3_mapnpc")\n'
             f'entity_id = "{eid}"\ntile_x = {tx}\ntile_z = {tz}\ndialogue = "{esc}"\n'
             f'npc_type = "{npc_type}"\nflag_key = "{flag_key}"\n')
    if "--hide" in opts:
        block += f'hide_flag_key = "{opts["--hide"]}"\n'
    if "--show" in opts:
        block += f'show_flag_key = "{opts["--show"]}"\n'
    block += 'after_dialogue = "%s"\n\n' % opts.get("--after", "").replace('"', '\\"')
    s = s.replace("[resource]\n", block + "[resource]\n", 1)
    s = re.sub(r"^(npcs = \[.*?)\]$", lambda m: m.group(1) + f', SubResource("{rid}")]', s, count=1, flags=re.M)
    m = re.search(r"load_steps=(\d+)", s)
    if m:
        s = s.replace(m.group(0), f"load_steps={int(m.group(1)) + 1}", 1)
    open(path, "w").write(s)
    print(f"added {eid} as {rid} to {name}")


if __name__ == "__main__":
    main()
