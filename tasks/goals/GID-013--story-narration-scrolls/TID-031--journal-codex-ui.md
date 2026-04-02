# TID-031: Journal / Codex UI overlay

**Goal:** GID-013
**Type:** agent
**Status:** pending
**Depends On:** TID-028

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

Players need a way to re-read lore text and replay narration audio without finding the scroll again. The Journal overlay (J key) lists all collected scrolls, shows the selected scroll's lore text, and has a replay button that re-triggers narration audio. Same lifecycle pattern as `InventoryScene`.

## Research Notes

**Overlay lifecycle pattern** (from `InventoryScene` and `SceneManager`):
1. `WorldScene` listens for `I` key → emits `GameBus.inventory_requested`
2. `SceneManager` listens → instantiates `InventoryScene` as full-screen overlay, adds to scene tree root
3. `InventoryScene` emits a close signal (or SceneManager listens for input) → overlay removed

For the Journal, add the same pattern:
- J key in `WorldScene._unhandled_input()` → emit `GameBus.journal_requested`
- `SceneManager` connects `GameBus.journal_requested` → instantiate and show `JournalScene`
- `JournalScene` close button / Escape key → remove overlay

**GameBus signal to add** (in TID-030's scope if editing GameBus, or add here):
```gdscript
signal journal_requested()
```

**JournalScene layout:**
Two-panel layout (same approach as InventoryScene):
- **Left panel** — scroll list: one button per collected scroll, showing title
  - If no scrolls collected: show "No lore scrolls found yet."
  - Buttons use viewport-relative sizing per CLAUDE.md rules
- **Right panel** — detail view for selected scroll:
  - Title label (large)
  - Lore text (`RichTextLabel` with `bbcode_enabled = true`, `scroll_following = true`, `autowrap_mode = TextServer.AUTOWRAP_WORD`)
  - "Replay Narration" button → calls `AudioManager.play_narration(_selected_id)`
  - "Not yet collected" state if nothing selected
- **Close button** (top-right X) or ESC key closes the overlay

**UI sizing** (CLAUDE.md rules — viewport-relative):
```gdscript
var vh: float = get_viewport().get_visible_rect().size.y
var vw: float = get_viewport().get_visible_rect().size.x

# Panel dimensions
left_panel.custom_minimum_size = Vector2(vw * 0.25, 0)
right_panel.custom_minimum_size = Vector2(vw * 0.65, 0)

# Buttons in list
btn.custom_minimum_size = Vector2(vw * 0.22, vh * 0.06)

# Font sizes
title_label.add_theme_font_size_override("font_size", int(vh * 0.035))
lore_label.add_theme_font_size_override("font_size", int(vh * 0.022))
```

**Populating the list:**
```gdscript
func _populate_scroll_list() -> void:
    for child in _scroll_list.get_children():
        child.queue_free()
    var all: Array[Dictionary] = ScrollRegistry.get_all_scrolls()
    for scroll in all:
        var sid: String = scroll["id"]
        if not SaveManager.is_scroll_collected(sid):
            continue
        var btn := Button.new()
        btn.text = scroll["title"]
        btn.pressed.connect(_on_scroll_selected.bind(sid))
        _scroll_list.add_child(btn)
```

**Replay button:**
```gdscript
func _on_replay_pressed() -> void:
    if _selected_id != "":
        AudioManager.play_narration(_selected_id)
```

**Showing "N / TOTAL scrolls found" counter** in the header:
```gdscript
var found: int = SaveManager.collected_scrolls.size()
_header_label.text = "Journal — %d / %d Scrolls" % [found, ScrollRegistry.SCROLL_COUNT]
```

**Escape to close:**
```gdscript
func _unhandled_input(event: InputEvent) -> void:
    if event.is_action_pressed("ui_cancel"):
        _close()

func _close() -> void:
    queue_free()
```

**SceneManager integration:**
- Connect `GameBus.journal_requested` in `SceneManager._ready()`
- In handler: `var j := _JournalScene.instantiate(); get_tree().root.add_child(j)`
- Preload: `const _JournalScene = preload("res://scenes/ui/JournalScene.tscn")`

**WorldScene integration:**
- In `_unhandled_input()`, add alongside the `I` key check:
  ```gdscript
  if event.is_action_pressed("ui_journal") or (event is InputEventKey and event.keycode == KEY_J):
      GameBus.journal_requested.emit()
  ```
- Mobile: add a Journal button to the HUD CanvasLayer (small book icon, same approach as the inventory button)

**Files to create:**
- `scenes/ui/JournalScene.tscn`
- `scenes/ui/JournalScene.gd`
- `scenes/ui/JournalScene.tscn.uid` — generate sidecar UID

**UID sidecar:** Generate 12-char random string for `.uid` file immediately after creating the `.tscn`.

**GDScript Variant note:** `var _selected_id: String = ""` not `:=` (string literal is fine for `:=` — but use explicit type for clarity in an overlay class).

## Plan

_Written during Plan phase._

## Changes Made

_Filled after Build phase._

## Documentation Updates

_What was updated in agent docs._
