#!/usr/bin/env python3
"""Regenerate game_logic/world/BundledMaps.gd from assets/maps/*.txt.

Run this after adding or editing any .txt map file so the bundled
resource stays in sync. The CI workflow runs this automatically before
export.

Usage:
    python3 scripts/bundle_maps.py
"""

import glob
import os
import sys

MAPS_DIR = os.path.join(os.path.dirname(__file__), "..", "assets", "maps")
OUTPUT = os.path.join(os.path.dirname(__file__), "..", "game_logic", "world", "BundledMaps.gd")


def main() -> None:
    files = sorted(glob.glob(os.path.join(MAPS_DIR, "*.txt")))
    if not files:
        print("No .txt map files found in assets/maps/", file=sys.stderr)
        sys.exit(1)

    lines: list[str] = []
    lines.append("## Bundled map data \u2014 compiled into the PCK as a GDScript constant.")
    lines.append("##")
    lines.append("## AUTO-GENERATED \u2014 do not edit by hand.")
    lines.append("## Regenerate with: python3 scripts/bundle_maps.py")
    lines.append("##")
    lines.append('## Why: Godot\'s export_filter="all_resources" skips plain .txt files,')
    lines.append("## so they are missing from Android APK/PCK builds. Embedding the text")
    lines.append("## inside a GDScript constant guarantees it is always available via")
    lines.append("## preload(), on every platform.")
    lines.append("extends RefCounted")
    lines.append("")
    lines.append("")
    lines.append("## Map name -> full file content as a single string.")
    lines.append("const DATA: Dictionary = {")

    for fpath in files:
        name = os.path.splitext(os.path.basename(fpath))[0]
        with open(fpath, "r") as f:
            content = f.read()
        escaped = content.replace("\\", "\\\\").replace('"', '\\"').replace("\n", "\\n")
        lines.append(f'\t"{name}": "{escaped}",')

    lines.append("}")
    lines.append("")
    lines.append("")
    lines.append("static func has_map(map_name: String) -> bool:")
    lines.append("\treturn DATA.has(map_name)")
    lines.append("")
    lines.append("")
    lines.append("static func get_content(map_name: String) -> String:")
    lines.append('\treturn DATA.get(map_name, "") as String')
    lines.append("")

    with open(OUTPUT, "w") as f:
        f.write("\n".join(lines))

    print(f"BundledMaps.gd: {len(files)} maps, {os.path.getsize(OUTPUT) / 1024:.1f} KB")


if __name__ == "__main__":
    main()
