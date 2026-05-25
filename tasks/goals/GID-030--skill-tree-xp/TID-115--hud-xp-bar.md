# TID-115: HUD XP Bar

**Goal:** GID-030
**Type:** agent
**Status:** done
**Depends On:** TID-110

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

Players should always be able to see their current level and XP progress without opening any overlay. A compact XP bar in the world HUD satisfies this and makes level-up moments feel immediate and rewarding.

## Research Notes

**HUD location:** Find where the existing HUD is defined — likely `WorldScene.gd` or a dedicated `HUD.gd`/`HUD.tscn`. Look for where the coin counter, minimap, and existing buttons live.

```bash
grep -rn "coins\|minimap\|hud\|HUD" scenes/world/ --include="*.gd" | head -20
```

**XP bar layout (added to HUD):**
```
HBoxContainer (_xp_bar_row)
  Label (_level_label)     — "Lv.X"
  ProgressBar (_xp_bar)    — value = current_xp_in_level, max_value = xp_needed_for_next_level
  Label (_xp_label)        — "XXX / YYY XP"  (optional, can be omitted for small screens)
```

Position: bottom of screen or top-right corner — wherever it fits without overlapping minimap or existing buttons. Use `AnchorPreset` = bottom-left or top-right depending on existing HUD layout.

**ProgressBar sizing:**
```gdscript
var _vh: float = get_viewport().get_visible_rect().size.y
_xp_bar.custom_minimum_size = Vector2(_vh * 0.25, _vh * 0.025)
_level_label.add_theme_font_size_override("font_size", int(_vh * 0.02))
```

**Populating the bar:**
```gdscript
func _refresh_xp_bar() -> void:
    var sm := SceneManager.save_manager
    var lvl: int = sm.level
    var xp_this_level: int = sm.xp - SaveManager.xp_for_level(lvl - 1)  # XP earned within current level
    var xp_to_next: int = SaveManager.xp_for_level(lvl) - SaveManager.xp_for_level(lvl - 1)
    _level_label.text = "Lv.%d" % lvl
    _xp_bar.max_value = xp_to_next
    _xp_bar.value = xp_this_level
```

Note: `SaveManager.xp_for_level()` is a static method added in TID-110. Call it as `SaveManager.xp_for_level(n)`.

**Update trigger:**
- Call `_refresh_xp_bar()` in `_ready()` (initial state).
- Connect `GameBus.level_up` → `_refresh_xp_bar` (also refreshes on XP gain that crosses a level boundary).
- Optionally connect a `GameBus.xp_changed` signal emitted by `SaveManager.add_xp()` for smooth updates between level-ups — add this signal to `GameBus.gd` if desired.

**Mobile:** The bar must not overlap the virtual joystick. Verify position on small screen layout. Use `AnchorPreset` constants, not fixed pixel positions.

**Files to modify:**
- Wherever the world HUD is built (WorldScene.gd or HUD.gd) — add `_xp_bar_row`, `_level_label`, `_xp_bar`
- `autoloads/GameBus.gd` — optionally add `signal xp_changed(new_xp: int, new_level: int)`
- `autoloads/SaveManager.gd` — emit `GameBus.xp_changed` from `add_xp()` if signal is added

## Plan

1. Add `signal xp_changed(new_xp, new_level)` to GameBus; emit from SaveManager.add_xp().
2. Add `SaveManager` preload to WorldScene for static `xp_for_level()` calls.
3. Add `_level_label` and `_xp_bar` vars to WorldScene.
4. In `_update_hud()`: build HBoxContainer at bottom-left (vh*0.88) with level label, ProgressBar, XP text label; connect `GameBus.xp_changed` to refresh both.
5. Add `_refresh_xp_bar()` to update bar value and level label.

## Changes Made

- `autoloads/GameBus.gd`: added `signal xp_changed(new_xp: int, new_level: int)`
- `autoloads/SaveManager.gd`: `add_xp()` now emits `GameBus.xp_changed(xp, level)` after every XP gain
- `scenes/world/WorldScene.gd`: added `SaveManager` preload for static method access; added `_level_label: Label` and `_xp_bar: ProgressBar` vars; `_update_hud()` builds HBoxContainer at `y=vh*0.88` with "Lv.X" label + ProgressBar + "XP/XP" text; `GameBus.xp_changed` lambda refreshes bar and text on every gain; added `_refresh_xp_bar()` computing XP within current level using `xp_for_level()`

## Documentation Updates

No separate doc update needed; XP and skill tree systems are self-contained.
