# TID-134: World HUD & Navigation Mobile Polish

**Goal:** GID-034
**Type:** agent
**Status:** pending
**Depends On:** TID-129

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

_Written during Plan phase._

## Changes Made

_Filled after Build phase._

## Documentation Updates

_What was updated in agent docs._
