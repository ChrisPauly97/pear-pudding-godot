# TID-137: Tap-and-Hold Onboarding Tutorial

**Goal:** GID-034
**Type:** agent
**Status:** done
**Depends On:** TID-135, TID-136

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

Long-press inspection (TID-136) is a hidden mechanic — players have no way to discover it. This task adds a one-shot tutorial popup on first battle entry that teaches the gesture. It reuses the existing `TutorialRegistry` / `TutorialPopup` system so no new UI infrastructure is needed.

## Research Notes

### TutorialRegistry (`game_logic/TutorialRegistry.gd`)

Holds a static `_DATA: Dictionary` keyed by popup id → `{ "title": ..., "body": ... }`.
New popups are added by appending to `_DATA` — no UI code changes needed.

Registered popups currently: `skill_tree`, `coins`, `essence`, `mana`, `card_rarity`.

Signal: `GameBus.tutorial_popup_requested(popup_id: String)` — `TutorialPopup` listens and shows the panel.

Save-flag pattern: each popup is gated by a story flag key in `SaveManager.story_flags`. The flag name is the popup id prefixed with `tutorial_`:

```gdscript
# Already used pattern in WorldScene.gd
if not SaveManager.get_flag("tutorial_inventory_tip"):
    SaveManager.set_flag("tutorial_inventory_tip", true)
    GameBus.tutorial_popup_requested.emit("inventory_tip")
```

### What to add

**1. New popup entry in `TutorialRegistry._DATA`:**

```gdscript
"tap_and_hold": {
    "title": "Inspect Cards",
    "body": "Hold any card for half a second to see its full details — stats, description, and abilities.\n\nWorks in battle, your inventory, and the shop.",
}
```

**2. Trigger in `BattleScene.gd` at battle start:**

```gdscript
func _on_battle_started() -> void:
    # ... existing code ...
    if not SaveManager.get_flag("tutorial_tap_and_hold"):
        SaveManager.set_flag("tutorial_tap_and_hold", true)
        GameBus.tutorial_popup_requested.emit("tap_and_hold")
```

Find the method in BattleScene that runs once when the scene loads / battle begins — likely `_ready()` or a `_start_battle()` helper.

**3. Flag key:** `tutorial_tap_and_hold` (follows existing naming convention).

### SaveManager flag storage

`SaveManager.story_flags` is a `Dictionary` persisted in `save.json`. `get_flag(key)` returns false if key absent; `set_flag(key, value)` marks dirty. No schema change needed — story_flags is an open dict.

### Files to modify

- `game_logic/TutorialRegistry.gd` — add `"tap_and_hold"` entry to `_DATA`
- `scenes/battle/BattleScene.gd` — emit popup request on first battle (gated by flag)

## Plan

1. Add `"tap_and_hold"` entry to TutorialRegistry._DATA.
2. Emit `GameBus.tutorial_popup_requested.emit("tap_and_hold")` in BattleScene._ready() after the existing battle tutorial check. SceneManager automatically gates it by `"seen_tutorial_tap_and_hold"` flag.

## Changes Made

- **`game_logic/TutorialRegistry.gd`**: Added `"tap_and_hold"` entry with title "Inspect Cards" and body explaining the hold gesture.
- **`scenes/battle/BattleScene.gd`**: Added emit at end of _ready() battle start block.

## Documentation Updates

No agent doc changes needed.
