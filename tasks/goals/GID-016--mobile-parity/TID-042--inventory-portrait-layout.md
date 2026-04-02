# TID-042: Fix InventoryScene Portrait Layout

**Goal:** GID-016
**Type:** agent
**Status:** pending
**Depends On:** —

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

InventoryScene uses a three-column horizontal layout (Collection | VSeparator | Deck | button sidebar) inside a PanelContainer. On portrait phones the columns are extremely narrow and the ScrollContainers collapse for the same reason as ShopScene (no explicit `size` on the outer panel). The same `custom_minimum_size`-without-`size` bug applies.

## Research Notes

### File
`scenes/ui/InventoryScene.gd`

### Same size-pinning bug (lines 33–36)
```gdscript
var outer := PanelContainer.new()
var panel_w: float = _vw * 0.86
var panel_h: float = _vh * 0.86
outer.custom_minimum_size = Vector2(panel_w, panel_h)
outer.position = Vector2((_vw - panel_w) * 0.5, (_vh - panel_h) * 0.5)
```
Fix: add `outer.size = Vector2(panel_w, panel_h)`.

### Portrait layout switch
When `_vw < _vh` (portrait), the horizontal three-column layout becomes too cramped. Switch the root container to a `VBoxContainer` so Collection (top half) and Deck (bottom half) each get a full-width scrollable panel:

```gdscript
var is_portrait: bool = _vw < _vh
if is_portrait:
    # VBoxContainer: collection scroll (top) then deck scroll (bottom) then buttons (row)
    var root_vbox := VBoxContainer.new()
    ...
else:
    # existing HBoxContainer three-column layout
    var root_hbox := HBoxContainer.new()
    ...
```

In portrait mode:
- Collection VBox: `size_flags_vertical = SIZE_EXPAND_FILL`, `size_flags_stretch_ratio = 1.0`
- Deck VBox: `size_flags_vertical = SIZE_EXPAND_FILL`, `size_flags_stretch_ratio = 1.0`
- Button row: `HBoxContainer` with Save and Close buttons side by side, `SIZE_SHRINK_CENTER`

### ScrollContainer minimum heights
Both `left_scroll` and `right_scroll` need `custom_minimum_size = Vector2(0, _vh * 0.25)` in portrait mode to prevent collapse.

### Close button text
Line 115: `close_btn.text = "Close  [I]"` — the `[I]` key hint is meaningless on mobile. Change to:
```gdscript
close_btn.text = "Close  [I]" if not OS.has_feature("android") else "Close"
```

### Tooltip on − button (also covered by TID-045)
Line 254–255: `rm_btn.tooltip_text = "Minimum deck size reached"` — tooltips don't appear on touch. TID-045 handles the feedback; this task does not touch that logic.

### Relevant existing patterns
- ShopScene (TID-041) uses the same `custom_minimum_size` pattern — apply identical `size` pin here.
- Portrait check: `_vw < _vh` is reliable on Android; landscape games that the player rotates mid-session would require `_notification(NOTIFICATION_RESIZED)` but this game locks orientation so `_ready()` is sufficient.
