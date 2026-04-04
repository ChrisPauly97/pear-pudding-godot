# TID-048: MapRegistry Autoload

**Goal:** GID-017
**Type:** agent
**Status:** done
**Depends On:** TID-047

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

`BundledMaps.gd` currently bakes all map text into a GDScript constant dictionary so maps are available on Android without the `.txt` files. The new equivalent is `MapRegistry.gd` — an autoload that `const`-preloads the 6 built-in `.tres` files (so they're included in the export PCK and available at compile time) and falls back to runtime-loading from `user://maps/` for editor-saved or dungeon maps.

## Research Notes

**Current BundledMaps pattern** (`game_logic/world/BundledMaps.gd`):
```gdscript
const DATA: Dictionary = {
    "main": "100 100\n000...",
    "blancogov": "...",
    ...
}
```
Used in `WorldMap._init()`:
```gdscript
if BundledMaps.DATA.has(map_name):
    load_from_string(BundledMaps.DATA[map_name])
```

**New MapRegistry pattern**:
```gdscript
# autoloads/MapRegistry.gd
extends Node

const _MAIN    := preload("res://assets/maps/main.tres")
const _BLANCOGOV := preload("res://assets/maps/blancogov.tres")
# ... (one const per built-in map)

const _BUNDLED: Dictionary = {
    "main": _MAIN,
    "blancogov": _BLANCOGOV,
    # ...
}

func get_map(name: String) -> MapData:
    if _BUNDLED.has(name):
        return _BUNDLED[name] as MapData
    # Try user:// (editor saves, dungeons)
    var path_tres := "user://maps/%s.tres" % name
    var path_txt  := "user://maps/%s.txt"  % name
    if ResourceLoader.exists(path_tres):
        return ResourceLoader.load(path_tres) as MapData
    if FileAccess.file_exists(path_txt):
        # Backwards compat: load old .txt from user://
        var wm := WorldMap.new(name)  # uses legacy txt path
        return wm.to_map_data()       # convert to MapData (see TID-049)
    return null
```

**project.godot** — needs MapRegistry added to `[autoload]` section. Current autoloads include: `IsoConst`, `GameBus`, `SaveManager`, `SceneManager`, `AudioManager`.

**`.uid` file** — required per CLAUDE.md. Generate with:
```bash
python3 -c "import random,string; print('uid://'+''.join(random.choices(string.ascii_lowercase+string.digits,k=12)))"
```

**Key files:**
- `game_logic/world/BundledMaps.gd` — current pattern to replace
- `project.godot` — autoload registration
- `game_logic/world/WorldMap.gd` — `_init()` loading logic to update in TID-049

## Plan

1. Create `autoloads/MapRegistry.gd` with `.uid` sidecar:
   - `const` preloads for all 6 bundled `.tres` maps
   - `get_map(name) -> Resource` — returns bundled or runtime-loads from `user://maps/*.tres`
   - `.txt` fallback left as TODO (requires `WorldMap.to_map_data()` from TID-049)
   - `list_map_names() -> Array[String]` — bundled + user maps
2. Create `.uid` sidecars for all 6 `.tres` map files (UIDs already in file headers).
3. Register `MapRegistry` in `project.godot` autoload section.
4. Commit.

## Changes Made

- **`autoloads/MapRegistry.gd`** — New autoload. `const` preloads for all 6 built-in maps ensure they're tracked by the export system. `get_map()` tries bundled → `user://maps/*.tres` → null. `.txt` fallback commented-out as TODO for TID-049. `list_map_names()` returns bundled + user maps.
- **`autoloads/MapRegistry.gd.uid`** — UID sidecar `uid://5q4eakbdz9sk`.
- **`assets/maps/*.tres.uid`** — 6 new sidecar files matching the UIDs already embedded in each `.tres` header (required for Android export UID tracking).
- **`project.godot`** — Added `MapRegistry="*res://autoloads/MapRegistry.gd"` to `[autoload]` section.

## Documentation Updates

No agent doc changes. TID-053 updates `named-maps-and-dungeons.md` once the full migration is complete.
