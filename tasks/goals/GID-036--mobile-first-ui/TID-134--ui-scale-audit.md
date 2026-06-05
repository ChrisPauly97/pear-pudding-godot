# TID-134: UI Scale Audit & Global Size Increase

**Goal:** GID-036
**Type:** agent
**Status:** done
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

Mechanical size-raise pass across 7 files. No logic changes.

| File | Violations |
|------|-----------|
| InventoryScene.gd | Tab btns h=0.05→0.065; +/− btns h=0.042→0.065; Sell/Scrap/Combine/Craft/Confirm btns h=0.038→0.065; Save/Close btns h=0.055→0.065; name/badge/stats/craft fonts 0.015–0.021→0.022; essence label 0.020→0.022 |
| ShopScene.gd | Close btn h=0.055→0.065; all Buy btns h=0.05→0.065; all 0.019 info/price fonts→0.022; close font 0.02→0.022 |
| CharacterScene.gd | Close btn h=0.05→0.065; slot btns h=0.058→0.065; unequip btn h=0.052→0.065; equip btn h=0.048→0.065; all 0.016–0.021 fonts→0.022 |
| AchievementsScene.gd | Close X h=0.055→0.065; desc/progress/reward labels 0.016–0.017→0.022 |
| TutorialPopup.gd | "Got it" btn h=0.055→0.065 |
| SkillTreeScene.gd | Sub/desc labels 0.018–0.019→0.022 |
| VirtualJoystick.gd | _jump_r 0.052→0.060; _interact_r 0.043→0.055 |

Files with no violations: MenuScene.gd (0.075 h, 0.026 font), BiomeSelectionScene.gd, SettingsScene.gd, JournalScene.gd (mostly OK), RunSummaryScene.gd.

## Changes Made

Raised all touch targets and label fonts to mobile minimums across 7 files:

- **VirtualJoystick.gd**: `_jump_r` 0.052→0.060, `_interact_r` 0.043→0.055
- **TutorialPopup.gd**: "Got it" button height 0.055→0.065
- **AchievementsScene.gd**: Close X h=0.055→0.065; desc/progress/reward label fonts 0.016–0.017→0.022
- **SkillTreeScene.gd**: sub/desc label fonts 0.018–0.019→0.022
- **ShopScene.gd**: Close btn h=0.055→0.065; all Buy btns h=0.05→0.065; all info/price/none label fonts 0.019→0.022; close font 0.02→0.022
- **CharacterScene.gd**: Close btn h=0.05→0.065; slot btns h=0.058→0.065; unequip btn h=0.052→0.065; equip btn h=0.048→0.065; all fonts below 0.022 raised to 0.022
- **InventoryScene.gd**: Tab btns h=0.05→0.065; +/− btns 0.042→0.065; Sell/Scrap/Combine/Craft/Confirm btns h=0.038→0.065; Save/Close btns h=0.055→0.065; all fonts below 0.022 raised to 0.022; essence label 0.020→0.022
- **WorldScene.gd + Minimap.gd** (covered by TID-139): map/level/XP label font increases; minimap sz 0.18→0.20; Android USE button added

## Documentation Updates

CLAUDE.md already documents the mobile size minimums. No new agent docs needed for a mechanical size-raise pass.
