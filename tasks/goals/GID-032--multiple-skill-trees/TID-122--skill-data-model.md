# TID-122: Extend SkillData + SaveManager Data Model

**Goal:** GID-032
**Type:** agent
**Status:** done
**Depends On:** —

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

Before any skill content or UI can reference magic branches or cross-magic costs, the data model must be extended. This task is a pure schema change — no UI, no skill files, no behaviour changes.

## Research Notes

**SkillData additions** (`data/SkillData.gd`):
```gdscript
## "ember", "dawn", "dusk", or "ash"
@export var magic_branch: String = ""
## 0 = not cross-purchasable. >0 = costs this many corruption/redemption points.
@export var alt_cost: int = 0
```
Existing `.tres` files omit these fields → Godot defaults them to `""` and `0`, so no migration needed for the resource files.

**SkillRegistry addition** (`autoloads/SkillRegistry.gd`):
```gdscript
static func get_by_branch(branch: String) -> Array[String]:
    _ensure_loaded()
    var result: Array[String] = []
    for k in _skills.keys():
        var s: SkillData = _skills[k] as SkillData
        if s != null and s.magic_branch == branch:
            result.append(str(k))
    return result
```

**SaveManager additions** (`autoloads/SaveManager.gd`):
```gdscript
## "light", "dark", or "" (not yet chosen)
var magic_type: String = ""
var corruption_points: int = 0
var redemption_points: int = 0
```
- Bump `CURRENT_SAVE_VERSION` to 13.
- Add `_migrate_v12_to_v13()`: backfill `magic_type = ""`, `corruption_points = 0`, `redemption_points = 0`.
- Add to `new_game()`, `_load()`, and `_to_dict()`.

**No GameBus signals in this task** — those are added in TID-126 alongside the earn methods.

**Files to modify:**
- `data/SkillData.gd`
- `autoloads/SkillRegistry.gd`
- `autoloads/SaveManager.gd`

## Plan

1. Add `magic_branch` and `alt_cost` export vars to `data/SkillData.gd`.
2. Add `get_by_branch(branch)` static func to `autoloads/SkillRegistry.gd`.
3. In `autoloads/SaveManager.gd`:
   a. Add `magic_type`, `corruption_points`, `redemption_points` vars after `unlocked_skills`.
   b. Bump `CURRENT_SAVE_VERSION` to 13.
   c. Add static `_migrate_v12_to_v13()`.
   d. Call it in `_apply_migrations()`.
   e. Set defaults in `new_game()`.
   f. Load from dict in `load_save()`.
   g. Persist in `save()` / `_to_dict`.
   h. Add `set_magic_type(t)` mutator.

## Changes Made

- `data/SkillData.gd`: added `@export var magic_branch: String = ""` and `@export var alt_cost: int = 0` after `tree_col`.
- `autoloads/SkillRegistry.gd`: added `get_by_branch(branch: String) -> Array[String]` static func between `get_all_ids` and `get_by_type`.
- `autoloads/SaveManager.gd`:
  - Added `magic_type: String`, `corruption_points: int`, `redemption_points: int` vars after `unlocked_skills`.
  - Bumped `CURRENT_SAVE_VERSION` to 13.
  - Added `_migrate_v12_to_v13()` static func; backfills `magic_type = ""`, `corruption_points = 0`, `redemption_points = 0`.
  - Added migration call `if ver < 13: _migrate_v12_to_v13(data)` in `_apply_migrations()`.
  - Set all three new fields to defaults in `new_game()`.
  - Load all three fields in `load_save()` with safe defaults.
  - Persist all three fields in `save()` dict.
  - Added `set_magic_type(t: String)` mutator.

## Documentation Updates

No agent docs updated in this task — TID-127 covers documentation for the full goal.
