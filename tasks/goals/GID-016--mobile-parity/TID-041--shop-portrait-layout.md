# TID-041: Fix ShopScene Portrait Layout

**Goal:** GID-016
**Type:** agent
**Status:** pending
**Depends On:** —

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

On Android the merchant shop shows no cards. The root cause: `outer` (PanelContainer) has `custom_minimum_size` set but no explicit `size`, and is positioned manually (not anchored). In Godot 4, a `PanelContainer` sizes to its children unless constrained — the `ScrollContainer` inside the `VBoxContainer` has `SIZE_EXPAND_FILL` but has nothing to expand into because the PanelContainer grows to wrap its content rather than being a fixed height. Result: the ScrollContainer collapses to zero height and cards are invisible.

## Research Notes

### File
`scenes/ui/ShopScene.gd`

### Current broken pattern (lines 29–33)
```gdscript
var outer := PanelContainer.new()
var panel_w: float = _vw * 0.6
var panel_h: float = _vh * 0.82
outer.custom_minimum_size = Vector2(panel_w, panel_h)
outer.position = Vector2((_vw - panel_w) * 0.5, (_vh - panel_h) * 0.5)
add_child(outer)
```
`custom_minimum_size` alone is insufficient — `PanelContainer` will still expand to fit children. The `ScrollContainer` never receives a finite height to constrain against.

### Fix
Set `outer.size` explicitly in addition to `custom_minimum_size`, so the layout engine knows the panel is height-constrained. Also widen the panel on portrait screens:

```gdscript
# Portrait-aware width: use more of a narrow screen
var panel_w: float = minf(_vw * 0.90, _vh * 0.70)
var panel_h: float = _vh * 0.82
outer.custom_minimum_size = Vector2(panel_w, panel_h)
outer.size = Vector2(panel_w, panel_h)   # ← pin the size explicitly
outer.position = Vector2((_vw - panel_w) * 0.5, (_vh - panel_h) * 0.5)
```

### ScrollContainer: also set custom_minimum_size
The `scroll` ScrollContainer has `SIZE_EXPAND_FILL` (line 63). Add a minimum height so it never collapses even if the VBoxContainer's height resolution fails:
```gdscript
scroll.custom_minimum_size = Vector2(0, _vh * 0.30)
```

### Close button text: keyboard hint on mobile
Line 72: `close_btn.text = "Leave Shop"` — no keyboard reference, this is fine as-is.

### No other changes needed
The row layout (`_make_row`) uses viewport-relative sizes throughout and should display correctly once the scroll container has height.
