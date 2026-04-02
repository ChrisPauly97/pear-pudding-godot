# TID-044: Add Touch Cancel for BattleScene Card Drag

**Goal:** GID-016
**Type:** agent
**Status:** pending
**Depends On:** —

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

Right-clicking during a card drag calls `_cancel_hand_drag()` (BattleScene.gd:162). Mobile has no right-click. Players who start dragging the wrong card on Android have no way to cancel — the card must be dropped somewhere, either playing it unintentionally or it snapping back if no valid target.

## Research Notes

### File
`scenes/battle/BattleScene.gd`

### Current cancel (line 162)
```gdscript
elif mb.button_index == MOUSE_BUTTON_RIGHT:
    _cancel_hand_drag()
```

### Fix: show a Cancel button while dragging
When `_drag_visual` becomes non-null (a drag starts, line 188), show a small "✕" Button in the HUD. Hide/free it when `_cancel_hand_drag()` is called for any reason.

```gdscript
var _cancel_btn: Button = null

func _show_cancel_btn() -> void:
    if _cancel_btn != null:
        return
    var vh: float = get_viewport().get_visible_rect().size.y
    _cancel_btn = Button.new()
    _cancel_btn.text = "✕ Cancel"
    _cancel_btn.custom_minimum_size = Vector2(vh * 0.14, vh * 0.06)
    _cancel_btn.add_theme_font_size_override("font_size", int(vh * 0.028))
    # Top-centre of screen, out of the way of card zones
    var vw: float = get_viewport().get_visible_rect().size.x
    _cancel_btn.position = Vector2((vw - vh * 0.14) * 0.5, vh * 0.02)
    _cancel_btn.pressed.connect(_cancel_hand_drag)
    add_child(_cancel_btn)

func _hide_cancel_btn() -> void:
    if _cancel_btn != null:
        _cancel_btn.queue_free()
        _cancel_btn = null
```

Call `_show_cancel_btn()` right after `_drag_visual` is created (around line 191).
Call `_hide_cancel_btn()` at the top of `_cancel_hand_drag()` (line 177).

### Existing drag start (line 188 area)
```gdscript
_drag_visual = _make_card_ghost(card)
_drag_visual.position = from_pos - _drag_visual.size * 0.5
_drag_visual.mouse_filter = Control.MOUSE_FILTER_IGNORE
add_child(_drag_visual)
move_child(_drag_visual, get_child_count() - 1)
# ← add: _show_cancel_btn()
```

### _cancel_hand_drag() (line 177)
```gdscript
func _cancel_hand_drag() -> void:
    # ← add: _hide_cancel_btn()
    if _drag_visual:
        _drag_visual.queue_free()
        _drag_visual = null
```

### Button visibility on desktop
The button appears on desktop too when dragging — this is fine and useful. It will not interfere with right-click cancel since both paths call `_cancel_hand_drag()`.

### Size per CLAUDE.md parity rule
Use `vh`-relative sizing (14% wide, 6% tall) — no fixed pixels.
