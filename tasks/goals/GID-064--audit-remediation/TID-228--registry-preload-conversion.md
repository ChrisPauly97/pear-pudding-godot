# TID-228: Convert EnemyRegistry & WeaponRegistry to preload consts

**Goal:** GID-064
**Type:** agent
**Status:** done
**Depends On:** —

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

`autoloads/EnemyRegistry.gd:20-31` and `autoloads/WeaponRegistry.gd:11-22` enumerate
`res://data/...` with `DirAccess` and load via dynamic-string `ResourceLoader.load()` —
the exact pattern CLAUDE.md bans for Android. In an exported APK,
`editor/export/convert_text_resources_to_binary` (default on) makes
`DirAccess.get_next()` return `*.tres.remap` filenames, so the `ends_with(".tres")`
filter matches nothing.

Impact on Android: `_enemies`/`_weapons` stay empty; every enemy silently fights with
`_FALLBACK_DECK` (EnemyRegistry.gd:41) regardless of type/boss, and all
weapon/armor/ring/trinket lookups return null — silent because of the fallbacks.

## Research Notes

- The in-repo reference implementations are `autoloads/CardRegistry.gd:5-50` and
  `autoloads/SkillRegistry.gd` — one `const _X := preload("res://data/...")` per file,
  iterated in an `_ensure_loaded()` that casts and keys by id. MapRegistry follows the
  same pattern. Convert both registries to match exactly.
- Enumerate the current files first: `ls data/enemies/*.tres data/weapons/*.tres`
  (WeaponRegistry may cover armor/rings/trinkets too — check its scan paths at
  WeaponRegistry.gd:11-22 for every directory it walks).
- Keep the public API identical (`get_enemy()`, `get_weapon()`, etc.) so no call sites
  change.
- While here (same file, trivial): `is_boss()` and `get_is_boss()` in
  EnemyRegistry.gd:62-66 vs 76-80 are identical duplicates — keep one, alias or delete
  the other after checking call sites.
- Add a CLAUDE.md-style note is NOT needed (rule already documented); just follow it.
- Verify with the existing registry tests under `tests/` and run the full suite.
- This also resolves audit finding that all enemy decks silently degrade to
  `_FALLBACK_DECK` — after conversion, consider a `push_warning` in the fallback path
  so future regressions are loud.

## Plan

Replace `DirAccess`+`ResourceLoader.load()` in both registries with explicit `const` preloads following CardRegistry's pattern. Keep public API identical. Alias `get_is_boss` → `is_boss` (both called externally). Add `push_warning` in `get_deck` fallback path.

## Changes Made

- **`autoloads/EnemyRegistry.gd`**: Replaced `DirAccess`/`ResourceLoader.load()` in `_ensure_loaded()` with 8 explicit `const _E_* := preload(...)` consts iterated in an array. `get_is_boss()` now delegates to `is_boss()`. Added `push_warning` in `get_deck()` fallback path. Added `push_error` if registry ends up empty.
- **`autoloads/WeaponRegistry.gd`**: Same pattern — 16 explicit `const _W_* := preload(...)` consts. Added `push_error` if registry ends up empty.

## Documentation Updates

None required.
