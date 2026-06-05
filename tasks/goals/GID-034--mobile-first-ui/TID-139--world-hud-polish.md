# TID-139: World HUD & Navigation Mobile Polish

**Goal:** GID-034
**Type:** agent
**Status:** done
**Depends On:** TID-134

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

The in-game world HUD shows coin count, level, XP bar, a minimap, and an interact prompt. On mobile the interact prompt is text-only ("Press USE") with no visible tap target, and all HUD labels are sized for desktop. This task converts the interact prompt to a proper tap button on mobile, increases all HUD label fonts, and slightly enlarges the minimap tap zone.

## Research Notes

### WorldScene HUD (`scenes/world/WorldScene.gd`)

Key elements (lines ~108–127 based on research):

| Variable | Type | Current behaviour |
|----------|------|------------------|
| `_interact_label` | Label | Shows "Press E" / "Press USE" when near interactable |
| `_coin_label` | Label | Updates each frame from `SaveManager.coins` |
| `_dialogue_label` | Label | NPC dialogue, auto-fades after 4s |
| `_tip_label` | Label | Yellow one-shot hints, 5s auto-hide |
| `_level_label` | Label | Character level |
| `_xp_bar` | ProgressBar | Experience |
| `_minimap` | Minimap node | Top-right, diameter `vh * 0.18` |

### Interact prompt → tap button on mobile

On Android, replace the `_interact_label` with a styled `Button` that emits `interact` action when pressed. On desktop keep the label.

Pattern:
```gdscript
func _build_hud() -> void:
    if OS.has_feature("android"):
        _interact_btn = Button.new()
        _interact_btn.text = "USE"
        var vh: float = get_viewport().get_visible_rect().size.y
        _interact_btn.custom_minimum_size = Vector2(vh * 0.14, vh * 0.07)
        _interact_btn.add_theme_font_size_override("font_size", int(vh * 0.030))
        _interact_btn.pressed.connect(_on_interact_pressed)
        $HUD.add_child(_interact_btn)
        _interact_btn.visible = false   # shown only when near interactable
    else:
        # existing _interact_label setup
```

Show/hide logic: wherever `_interact_label.visible = true/false` is set, also set `_interact_btn.visible` on Android.

`_on_interact_pressed`:
```gdscript
func _on_interact_pressed() -> void:
    Input.action_press("interact")
    await get_tree().process_frame
    Input.action_release("interact")
```

### HUD font size targets

| Element | Current (est.) | Target |
|---------|---------------|--------|
| `_coin_label` | `vh * 0.022` | `vh * 0.028` |
| `_level_label` | `vh * 0.022` | `vh * 0.028` |
| `_tip_label` | `vh * 0.022` | `vh * 0.025` |
| `_dialogue_label` | `vh * 0.022` | `vh * 0.025` |
| XP bar height | `vh * 0.012` | `vh * 0.018` |

### Minimap tap zone

`Minimap.gd` exposes a tap button layered above the ring. Its hit area is the minimap circle (diameter `vh * 0.18`). Increase diameter to `vh * 0.20` and ring width proportionally. This is cosmetic only — the minimap tap opens `MapViewOverlay`.

### Map label (map name toast)

`_map_label` fades in on map load. Increase font to `vh * 0.032` from current `vh * 0.022`.

### Files to modify

- `scenes/world/WorldScene.gd` — HUD layout and sizing
- `scenes/world/Minimap.gd` — diameter fraction

## Plan

### Actual current values (from reading source)

| Element | Actual current | Change |
|---------|---------------|--------|
| Most HUD labels (coin, map, interact, dialogue, tip) | `vh * 0.03` | Already fine — no change |
| `_map_label` | `vh * 0.03` (via `font_size`) | Bump to `vh * 0.032` |
| `_level_label` | `vh * 0.02` | → `vh * 0.028` |
| `xp_lbl` (XP fraction text) | `vh * 0.018` | → `vh * 0.025` |
| `_xp_bar` height | `vh * 0.025` | → `vh * 0.032` |
| Minimap diameter | `vh * 0.18` | → `vh * 0.20` |
| Android interact prompt | Label only, "[Tap] Interact" | Add tappable `Button` |

### WorldScene.gd

1. Add `var _interact_btn: Button = null` near `_interact_label` declarations.
2. In `_ready()`, after joystick creation: if Android, create `_interact_btn` (18% vh wide × 8% vh tall, font 3.2% vh), position center-bottom, connect `.pressed` → `_handle_interact()`, hide initially. Also hide `_interact_label` immediately (button replaces it on Android).
3. In `_check_interactions()`, show/hide `_interact_btn` in sync with `_interact_label`.
4. Set `_map_label` font to `int(vh * 0.032)` instead of `font_size`.
5. Set `_level_label` font to `int(vh * 0.028)`.
6. Set `xp_lbl` font to `int(vh * 0.025)`.
7. Set `_xp_bar` height to `vh * 0.032`.

### Minimap.gd

Change `int(vh * 0.18)` → `int(vh * 0.20)`. All layout uses `sz` derived from this so it scales automatically.

## Changes Made

### `scenes/world/WorldScene.gd`
- Added `var _interact_btn: Button = null` field.
- On Android: creates a `Button` ("USE", `vh * 0.18 × vh * 0.08`, font `vh * 0.032`) centred horizontally at `vh * 0.80`. Its `pressed` signal calls `_handle_interact()` directly. Hidden initially.
- `_check_interactions()`: on Android shows `_interact_btn` instead of `_interact_label`; always hides both on no nearby interactable.
- `_map_label` font raised from `vh * 0.03` to `vh * 0.032`.
- `_level_label` font raised from `vh * 0.02` to `vh * 0.028`; min-width from `vh * 0.06` to `vh * 0.08`.
- `_xp_bar` height raised from `vh * 0.025` to `vh * 0.032`.
- XP fraction label font raised from `vh * 0.018` to `vh * 0.025`.
- `minimap_bottom` offset updated from `vh * 0.18` to `vh * 0.20` to match new minimap diameter.

### `scenes/world/Minimap.gd`
- Minimap diameter changed from `int(vh * 0.18)` to `int(vh * 0.20)`. All layout (position, tap button size, entity overlay) derives from `sz` so scales automatically.

## Documentation Updates

- `docs/agent/ui-and-scene-management.md`: updated HUD section to reflect `_interact_btn` on Android, new font fractions, and minimap diameter.
