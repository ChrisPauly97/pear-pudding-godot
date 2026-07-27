# BID-018: EnemyRegistry Uses DirAccess + ResourceLoader on Android

**Discovered during:** GID-045 (TID-170)

## Problem

`autoloads/EnemyRegistry.gd` loads enemy `.tres` files via `DirAccess.open("res://data/enemies")` + `ResourceLoader.load()` in `_ensure_loaded()`. Per CLAUDE.md, this pattern is unreliable inside an Android APK/PCK — `DirAccess` directory scanning fails, and dynamic `ResourceLoader.load()` paths are invisible to the export dependency scanner so the files may not be packaged at all.

The same code that calls `EnemyRegistry.get_all_enemy_ids()` / `get_deck()` / etc. will silently get empty results on Android.

## Impact

- All enemy encounter logic (deck selection, drop pools, bestiary tracking) could silently fail on Android
- `SaveManager.is_bestiary_complete()` would always return `false` since `EnemyRegistry.get_all_enemy_ids()` would return `[]`

## Fix

Convert `EnemyRegistry` to use `preload()` constants, following the same pattern as `CardRegistry`, `SkillRegistry`, etc.:

```gdscript
const _E_UNDEAD_BASIC    := preload("res://data/enemies/undead_basic.tres")
const _E_UNDEAD_HORDE    := preload("res://data/enemies/undead_horde.tres")
# … one per file

static func _ensure_loaded() -> void:
    if _loaded:
        return
    _loaded = true
    for res in [_E_UNDEAD_BASIC, _E_UNDEAD_HORDE, ...]:
        var enemy := res as EnemyData
        if enemy != null:
            _enemies[enemy.id] = enemy
```

Add a new `const` and array entry whenever a new `.tres` is created.

## Workaround

The CI workflow runs `godot --headless --editor --quit` before export, which imports all assets. The `.tres` files in `data/enemies/` ARE tracked by git and may be included via `DirAccess` during the editor scan. However, the dynamic `ResourceLoader.load()` path is not guaranteed to be included in the APK export packs.
