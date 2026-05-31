# TID-116: Extend SkillData + SaveManager Data Model

**Goal:** GID-031
**Type:** agent
**Status:** pending
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

**No GameBus signals in this task** — those are added in TID-120 alongside the earn methods.

**Files to modify:**
- `data/SkillData.gd`
- `autoloads/SkillRegistry.gd`
- `autoloads/SaveManager.gd`

## Plan

_Written during Plan phase._

## Changes Made

_Filled after Build phase._

## Documentation Updates

_What was updated in agent docs._
