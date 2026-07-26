# BID-018: Pre-existing test suite failures in headless runner

## Observed

When running `godot --headless --path . -s tests/runner.gd`, two suites are
skipped with `can_instantiate()` returning false:

- `test_weather_manager` — `Identifier not found: WeatherManager` (class_name
  not globally visible without editor scan)
- `test_weather_battle` — `Identifier not found: SaveManager` (autoload name
  not found when the script is compiled in isolation before autoloads register)

Additionally several tests in other suites fail due to missing imported assets
(CardRegistry returning empty, named-map NPC counts wrong, etc.).

## Root cause

GDScript `class_name` declarations are not globally available until the Godot
editor scans and caches the project. Running headless without a prior
`godot --headless --editor --quit` step means class_name references in
some test files resolve to "Identifier not found".

The `SaveManager` identifier-not-found errors during the pre-scan phase are
harmless (the scripts still run when autoloads are registered), but the
`WeatherManager` class_name error prevents those suites from loading.

## Fix

Option A: Replace `WeatherManager` class_name references in the test file with
explicit `preload("res://path/to/WeatherManager.gd")` constants (per CLAUDE.md
"class_name Not Immediately Available" guidance).

Option B: Pre-run `godot --headless --editor --quit` before tests in CI
(already done for the export step, should also cover tests).

## Discovered during

TID-179 (GID-048 mount framework)
