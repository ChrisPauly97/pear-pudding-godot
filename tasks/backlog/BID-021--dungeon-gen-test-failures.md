# BID-021: test_dungeon_secrets suite fails headless — DungeonGen.new() error

## Observed

Running `godot --headless --path . -s tests/runner.gd` produces 12 failures in `test_dungeon_secrets`:

```
SCRIPT ERROR: Invalid call. Nonexistent function 'new' in base 'GDScript'.
          at: generate (res://game_logic/world/DungeonGen.gd:33)
```

Line 33 of DungeonGen.gd is:
```gdscript
var map: _WorldMap = _WorldMap.new(p_name, true)
```
where `_WorldMap = preload("res://game_logic/world/WorldMap.gd")`.

## Root cause

`WorldMap.gd` itself preloads `EnemyRegistry.gd` and several resource scripts. If any of those fail to compile in the headless runner (class_name not scanned, autoloads not initialised), WorldMap fails silently and calling `.new()` on the broken GDScript object triggers this error.

This is the same class of issue documented in BID-018 (pre-existing test suite failures due to missing editor scan).

## Fix

Option A: Pre-run `godot --headless --editor --quit` before the test runner to trigger the project scan and resolve class_name/import references.

Option B: Refactor DungeonGen tests to avoid direct WorldMap instantiation; mock the map or accept RefCounted and call known methods explicitly.

## Discovered during

GID-079 verification run (2026-06-21).
