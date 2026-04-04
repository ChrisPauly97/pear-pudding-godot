# GID-017: Native Godot Map Storage Migration

## Objective

Migrate map storage from custom `.txt` files with a Python bundling pipeline to native Godot `.tres` resource files using typed `Resource` subclasses, eliminating the bundling script and Android export workaround.

## Context

Maps are hand-authored `.txt` files in `assets/maps/`. Because Godot excludes plain `.txt` files from Android APK/PCK exports, `scripts/bundle_maps.py` must run (manually or in CI) to generate `game_logic/world/BundledMaps.gd` — a GDScript file with all map data baked in as escaped string constants. This is fragile and error-prone.

By migrating to `.tres` resource files with typed `Resource` subclasses:
- The bundling pipeline (`bundle_maps.py` + `BundledMaps.gd`) is deleted entirely
- Godot includes `.tres` files in exports natively when they are referenced via preload
- Maps gain type safety, native editor support, and a clean extensibility path for future features (triggers, regions, metadata)

## Tasks

| ID | Name | Type | Status | Depends On |
|----|------|------|--------|------------|
| TID-046 | Define MapData resource schema | agent | done | — |
| TID-047 | Convert .txt maps to .tres | agent | done | TID-046 |
| TID-048 | MapRegistry autoload | agent | done | TID-047 |
| TID-049 | Migrate WorldMap to load from MapData | agent | done | TID-046, TID-048 |
| TID-050 | Update DungeonGen to output .tres | agent | done | TID-046, TID-049 |
| TID-051 | Update Map Editor to save/load .tres | agent | done | TID-049 |
| TID-052 | Remove bundling pipeline | agent | pending | TID-049, TID-050, TID-051 |
| TID-053 | Update agent docs | agent | pending | TID-052 |

## Acceptance Criteria

- [ ] All 6 named maps load correctly from `.tres` files with no runtime errors
- [ ] `bundle_maps.py` and `BundledMaps.gd` are deleted
- [ ] DungeonGen writes `user://maps/dungeon_<seed>.tres`
- [ ] Map Editor saves/loads `.tres` to/from `user://maps/`
- [ ] `godot --headless --path . -s tests/runner.gd` passes with exit code 0
- [ ] Android CI build succeeds without any bundling step
- [ ] `MapData` resource schema includes extensibility fields: `triggers`, `regions`, metadata
