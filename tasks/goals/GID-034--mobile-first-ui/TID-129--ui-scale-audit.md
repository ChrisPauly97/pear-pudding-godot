# TID-129: UI Scale Audit & Global Size Increase

**Goal:** GID-034
**Type:** agent
**Status:** pending
**Depends On:** —

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

Every scene in the game sizes controls relative to the viewport height (`vh`), but several scenes use fractions that are too small for comfortable touch use on a phone. This task audits all UI scenes and raises every element that falls below the minimums defined in CLAUDE.md:

- Touch-target height minimum: `vh * 0.065`
- Touch-target width minimum: `vh * 0.10`
- Body font minimum: `vh * 0.025`
- Label font minimum: `vh * 0.022`

No fixed-pixel `custom_minimum_size` values should remain after this task.

## Research Notes

### Known violations (from research phase)

| Scene | Element | Current fraction | Target fraction |
|-------|---------|-----------------|-----------------|
| Multiple | Small action buttons (equip, sell, craft) | `vh * 0.038` height | `vh * 0.065` |
| Multiple | Tiny labels / stat text | `vh * 0.016–0.018` | `vh * 0.022` |
| Multiple | Body/description text | `vh * 0.019–0.022` | `vh * 0.025` |
| BattleScene.gd | Menu button height | `vh * 0.07` | OK, keep |
| BattleScene.gd | End Turn button height | `vh * 0.10` | OK, keep |
| VirtualJoystick.gd | Interact button radius | `vh * 0.043` | `vh * 0.055` |
| VirtualJoystick.gd | Jump button radius | `vh * 0.052` | `vh * 0.060` |

### Files to audit

- `scenes/ui/InventoryScene.gd`
- `scenes/ui/ShopScene.gd`
- `scenes/ui/CharacterScene.gd`
- `scenes/ui/SkillTreeScene.gd`
- `scenes/ui/MenuScene.gd`
- `scenes/ui/SettingsScene.gd` (pure code, no .tscn)
- `scenes/ui/BiomeSelectionScene.gd`
- `scenes/ui/AchievementsScene.gd`
- `scenes/ui/JournalScene.gd`
- `scenes/ui/RunSummaryScene.gd`
- `scenes/ui/TutorialPopup.gd`
- `scenes/ui/VirtualJoystick.gd`
- `scenes/battle/BattleScene.gd`

### Pattern to follow

```gdscript
# Bad — fixed pixels
button.custom_minimum_size = Vector2(80, 30)

# Bad — too small fraction
button.custom_minimum_size = Vector2(vh * 0.10, vh * 0.038)

# Good
button.custom_minimum_size = Vector2(vh * 0.14, vh * 0.065)
label.add_theme_font_size_override("font_size", int(vh * 0.025))
```

All sizing must live in `_ready()` / `_apply_sizes()` and re-applied in `_notification(NOTIFICATION_RESIZED)`.

### Separator: VirtualJoystick

The virtual joystick draws via `_draw()` and does not use `custom_minimum_size`. Update `_base_r`, `_knob_r`, `_jump_r`, `_interact_r` fractions in its `_ready()` call:

```gdscript
_jump_r    = vh * 0.060   # was 0.052
_interact_r = vh * 0.055  # was 0.043
```

## Plan

_Written during Plan phase._

## Changes Made

_Filled after Build phase._

## Documentation Updates

_What was updated in agent docs._
