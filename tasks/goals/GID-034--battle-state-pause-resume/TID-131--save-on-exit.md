# TID-131: Save battle state on exit and app background

**Goal:** GID-034
**Type:** agent
**Status:** pending
**Depends On:** TID-130

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

Two code paths in `BattleScene.gd` need to persist the current `GameState` before relinquishing control:

1. **Return to Menu** — the "Yes, leave" button callback (`_confirm_return_to_menu`, line 630) calls `SceneManager.go_to_menu()` immediately, discarding the live `_state`.
2. **App background** — `_notification(NOTIFICATION_APPLICATION_FOCUS_OUT)` (line ~619) auto-pauses but does not save state. On Android the OS may kill the process after this.

Both paths must serialize `_state` into `SaveManager.pending_battle_state` before control leaves BattleScene.

## Research Notes

**File to modify:** `scenes/battle/BattleScene.gd`

**"Yes, leave" callback (lines 630-633):**
```gdscript
yes_btn.pressed.connect(func() -> void:
    get_tree().paused = false
    SceneManager.go_to_menu()
)
```
Change to:
```gdscript
yes_btn.pressed.connect(func() -> void:
    SceneManager.save_manager.set_pending_battle_state(_state.to_dict())
    SceneManager.save_manager.save()
    get_tree().paused = false
    SceneManager.go_to_menu()
)
```

**Confirmation dialog label (line 614):**
```gdscript
lbl.text = "Your battle progress will be lost.\nReturn to menu?"
```
Update to reflect that state is now saved:
```gdscript
lbl.text = "Return to menu?\nYour battle will be saved."
```

**App background notification (locate with grep `NOTIFICATION_APPLICATION_FOCUS_OUT` in BattleScene.gd):**
Find the `_notification` override and add a state save before the paused check:
```gdscript
func _notification(what: int) -> void:
    if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
        if _state != null:
            SceneManager.save_manager.set_pending_battle_state(_state.to_dict())
            SceneManager.save_manager.save()
        if not _paused:
            _show_pause_overlay()
```

**`_state` variable:** BattleScene holds the live `GameState` in a member variable. Confirm its name by grepping for `GameState.new()` or `var _state` in BattleScene.gd. The research showed it is `_state`.

**SceneManager access:** BattleScene already references `SceneManager` (e.g. line 450 uses `SceneManager.save_manager`), so no new import is needed.

**`GameState.to_dict()`** is added by TID-129 and available as an instance method.

## Plan

_Written during Plan phase._

## Changes Made

_Filled after Build phase._

## Documentation Updates

_What was updated in agent docs._
