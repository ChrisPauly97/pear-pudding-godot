# TID-045: Platform-Aware UI Text and Inventory Button Feedback

**Goal:** GID-016
**Type:** agent
**Status:** pending
**Depends On:** —

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

Two small UX issues: (1) `MapViewOverlay` shows "[M] or [Esc] to close" on Android where neither key exists; (2) the inventory deck's − button is silently disabled on Android when the deck is at the minimum — `tooltip_text` never appears on touch devices.

## Research Notes

### Fix 1 — MapViewOverlay close hint
**File:** `scenes/ui/MapViewOverlay.gd`, line ~115

Current:
```gdscript
hint.text = "[M] or [Esc] to close"
```

Fix:
```gdscript
hint.text = "Tap minimap to close" if OS.has_feature("android") else "[M] or [Esc] to close"
```

### Fix 2 — Inventory − button feedback on mobile
**File:** `scenes/ui/InventoryScene.gd`, lines 253–255

Current:
```gdscript
if _working_deck.size() <= IsoConst.DECK_MIN:
    rm_btn.disabled = true
    rm_btn.tooltip_text = "Minimum deck size reached"
```

On Android, `tooltip_text` never shows. The button is disabled with no explanation. Fix: connect `pressed` to emit a `GameBus.hud_message_requested` signal with the explanation — but `rm_btn.pressed` only fires when the button is enabled. Instead, wrap the button in a transparent tap target that fires the message when the button is disabled:

```gdscript
if _working_deck.size() <= IsoConst.DECK_MIN:
    rm_btn.disabled = true
    rm_btn.tooltip_text = "Minimum deck size reached"
    if OS.has_feature("android"):
        # Invisible tap area over the disabled button
        var tap := Button.new()
        tap.flat = true
        tap.custom_minimum_size = rm_btn.custom_minimum_size
        tap.pressed.connect(func() -> void:
            GameBus.hud_message_requested.emit("Minimum deck size reached"))
        row.add_child(tap)
```

Wait — this adds complexity. Simpler: instead of `rm_btn.disabled = true`, keep it enabled on mobile but guard in `_on_remove`:

```gdscript
# In _make_deck_row:
if _working_deck.size() <= IsoConst.DECK_MIN:
    if OS.has_feature("android"):
        rm_btn.pressed.connect(_on_remove_guarded.bind(index))
    else:
        rm_btn.disabled = true
        rm_btn.tooltip_text = "Minimum deck size reached"
        rm_btn.pressed.connect(_on_remove.bind(index))
else:
    rm_btn.pressed.connect(_on_remove.bind(index))
```

And add:
```gdscript
func _on_remove_guarded(index: int) -> void:
    if _working_deck.size() <= IsoConst.DECK_MIN:
        GameBus.hud_message_requested.emit("Minimum deck size reached")
        return
    _on_remove(index)
```

Actually the simplest approach that avoids branching: always connect `pressed` and guard in the handler, use visual dimming instead of `disabled` on mobile:

```gdscript
if _working_deck.size() <= IsoConst.DECK_MIN:
    if OS.has_feature("android"):
        rm_btn.modulate = Color(1, 1, 1, 0.4)   # visually dim
        rm_btn.pressed.connect(func() -> void:
            GameBus.hud_message_requested.emit("Minimum deck size reached"))
    else:
        rm_btn.disabled = true
        rm_btn.tooltip_text = "Minimum deck size reached"
        rm_btn.pressed.connect(_on_remove.bind(index))
else:
    rm_btn.pressed.connect(_on_remove.bind(index))
```

The agent implementing this task should choose the cleanest approach from the above options. The dimmed-button approach is recommended for clarity.

### Fix 3 — InventoryScene close button keyboard hint
**File:** `scenes/ui/InventoryScene.gd`, line 115

```gdscript
close_btn.text = "Close  [I]" if not OS.has_feature("android") else "Close"
```

This is a minor polish item included here since it's in the same file as Fix 2.

### No new files
All changes are in existing files. No `.uid` sidecars needed.
