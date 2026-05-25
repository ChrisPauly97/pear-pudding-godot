# TID-110: XP & Leveling Foundation

**Goal:** GID-030
**Type:** agent
**Status:** done
**Depends On:** —

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

Battles currently award coins but no long-term progression metric. XP gives the player a visible growth curve. Each level-up grants 1 skill point (spent in the skill tree, TID-114). This task establishes the data layer, award hook, and level-up notification — everything else in GID-030 builds on top of it.

## Research Notes

**SaveManager additions:**
```gdscript
var xp: int = 0
var level: int = 1
var skill_points: int = 0
```
- Increment `CURRENT_SAVE_VERSION` to 12 (v11 is taken by TID-106; coordinate if both are in flight — whichever merges first claims 11, the other takes 12).
- `_migrate_v11_to_v12()`: backfill `xp = 0`, `level = 1`, `skill_points = 0`.
- `new_game()`: set all three to their defaults.
- `_load()` / `_to_dict()`: include all three fields.
- New method: `add_xp(amount: int) -> void` — adds XP, computes new level via `_compute_level()`, if level increased: increments `skill_points` by the number of levels gained, emits `GameBus.level_up(new_level)`, queues dirty save.

**Level thresholds (simple quadratic curve):**
```gdscript
static func xp_for_level(lvl: int) -> int:
    return lvl * lvl * 50  # level 1→2: 50, 2→3: 200, 3→4: 450, etc.

static func _compute_level(current_xp: int) -> int:
    var lvl: int = 1
    while current_xp >= xp_for_level(lvl):
        lvl += 1
    return lvl - 1
```

**XP awards on battle win:**
- Hook: `SceneManager._on_battle_won()` — already awards coins and card drops.
- Add: `save_manager.add_xp(xp_amount)` where `xp_amount` is based on enemy type.
- Simple approach: read `EnemyData` coin_reward as a proxy. Or define a fixed table:
  - `undead_basic`: 20 XP
  - `undead_horde`: 35 XP
  - `ghoul_pack`: 50 XP
  - `undead_elite`: 80 XP
  - default (unknown): 25 XP
- Store the XP table as a `const` Dictionary in `SceneManager` or a new `XPTable` const in `IsoConst`.

**GameBus signal:**
```gdscript
signal level_up(new_level: int)
```

**Level-up toast:**
- Reuse `AchievementToast` pattern: connect `GameBus.level_up` in SceneManager and show a slide-in panel "Level Up! → Level X" for 3 seconds.
- Check if `AchievementToast.gd` is generic enough to reuse directly (it may already accept arbitrary text).

**Files to modify:**
- `autoloads/SaveManager.gd`
- `autoloads/GameBus.gd` — add `signal level_up(new_level: int)`
- `autoloads/SceneManager.gd` — add XP award in `_on_battle_won`, connect `level_up` for toast
- `autoloads/IsoConst.gd` — optionally add XP table constants

## Plan

1. Add `xp`, `level`, `skill_points` vars to SaveManager; bump to v12; add migration, new_game, load, save entries; add `xp_for_level`, `_compute_level`, `add_xp` methods.
2. Add `signal level_up(new_level: int)` to GameBus.
3. Add `show_text(title, desc)` to AchievementToast and update `_show_next` to drain it.
4. Connect `GameBus.level_up` in SceneManager `_ready()`; add `_on_level_up` handler that calls `_toast.show_text`.
5. Award XP in SceneManager `_on_battle_won` using a fixed enemy-type table.

## Changes Made

- `autoloads/SaveManager.gd`: added `xp`, `level`, `skill_points` vars; bumped `CURRENT_SAVE_VERSION` to 12; added `_migrate_v11_to_v12` (backfills 0/1/0 defaults); added migration call to `_apply_migrations`; added fields to `new_game()`, `load_save()`, `save()`; added `xp_for_level(lvl)` (quadratic 50×lvl²), `_compute_level(xp)`, and `add_xp(amount)` which computes new level, grants skill points for each level gained, and emits `GameBus.level_up`
- `autoloads/GameBus.gd`: added `signal level_up(new_level: int)`
- `scenes/ui/AchievementToast.gd`: added `_text_queue: Array` for raw messages; added `show_text(title, desc)` public method; updated `_show_next` to drain `_text_queue` before `_queue`
- `autoloads/SceneManager.gd`: connected `GameBus.level_up` in `_ready()`; added `_on_level_up(new_level)` which calls `_toast.show_text("Level Up!", ...)`; added XP award block in `_on_battle_won` using `_XP_TABLE` dict (20–80 XP by enemy type, doubled for bosses)

## Documentation Updates

No new agent doc needed; save-system.md and signals-and-constants.md will be updated in TID-115 when the HUD XP bar is added.
