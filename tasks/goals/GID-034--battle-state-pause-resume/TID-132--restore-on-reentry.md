# TID-132: Restore saved battle state on battle re-entry

**Goal:** GID-034
**Type:** agent
**Status:** done
**Depends On:** TID-131

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

When the player taps "Continue" after leaving a battle mid-fight, `WorldScene` detects `pending_battle_enemy_data` and re-emits `enemy_engaged`. `SceneManager._on_enemy_engaged` instantiates a fresh `BattleScene` and sets `enemy_data` on it. This task wires up the restoration path so BattleScene checks for a saved `GameState` snapshot and restores it instead of initializing fresh.

Also clears `pending_battle_state` on normal battle end so stale data doesn't bleed into future battles.

## Research Notes

**Files to modify:**
- `scenes/battle/BattleScene.gd` — check for saved state on startup and restore it
- `autoloads/SceneManager.gd` — clear `pending_battle_state` on battle won/lost

---

**BattleScene initialization flow:**
BattleScene._ready() creates the GameState. Locate the exact line with:
```
grep -n "GameState.new\|_state = \|var _state" scenes/battle/BattleScene.gd
```
The restore must happen immediately after `_state` would normally be constructed. Pattern:

```gdscript
# After the normal _state creation block, replace or wrap:
var saved := SceneManager.save_manager.pending_battle_state
if not saved.is_empty():
    _state = GameState.from_dict(saved)
    SceneManager.save_manager.clear_pending_battle_state()
else:
    # existing fresh-state initialization code
    _state = GameState.new()
    # ... existing deck building for player and enemy
```

`GameState.from_dict()` is added by TID-129.

**Important:** `pending_battle_state` must be cleared immediately after restoring — before any other code runs — so a subsequent crash doesn't restore stale state from the resumed battle.

---

**BattleScene._hero_power_used flag:** this bool tracks whether the active skill has been used this battle. When restoring, it should default to `false` (it is not persisted; the player gets it back on resume, which is acceptable).

---

**SceneManager — clear on battle end:**

`_on_battle_won` (line 253 area) and `_on_battle_lost` (line ~303 area) both call `save_manager.clear_pending_battle()`. Add a matching call to clear the state snapshot:

```gdscript
# In _on_battle_won and _on_battle_lost, alongside clear_pending_battle():
save_manager.clear_pending_battle_state()
```

---

**WorldScene pending battle detection (lines 237-238):**
```gdscript
if not SceneManager.save_manager.pending_battle_enemy_data.is_empty():
    GameBus.enemy_engaged.emit.call_deferred(SceneManager.save_manager.pending_battle_enemy_data)
```
No change needed here — it still fires `enemy_engaged` which SceneManager handles. The state restoration happens inside BattleScene itself after instantiation.

---

**GDScript preload note:** `GameState.from_dict()` is a static method. BattleScene already uses `GameState` — check whether it accesses it via `class_name` or a `preload` const. If via `class_name`, add:
```gdscript
const GameState = preload("res://game_logic/battle/GameState.gd")
```
at the top of BattleScene.gd per the CLAUDE.md `class_name` guidance.

## Plan

1. In `BattleScene._ready()`, wrap the entire fresh-initialization block (`_state = GameState.new()` through `_state.players[0].start_turn(1)`) in an `else` branch; add an `if` branch that calls `GameState.from_dict(saved)` and clears the state immediately.
2. Move signal connections (`_end_turn_btn.pressed.connect`, etc.) out of the conditional so they always run.
3. In `SceneManager._on_battle_won()` and `_on_battle_lost()`, add `save_manager.clear_pending_battle_state()` alongside the existing `clear_pending_battle()`.

## Changes Made

- `scenes/battle/BattleScene.gd`:
  - `_ready()` now checks `SceneManager.save_manager.pending_battle_state`. If non-empty, calls `GameState.from_dict()` and `clear_pending_battle_state()` immediately. Otherwise runs the existing fresh deck-build and `start_turn(1)` path.
  - Signal connections moved out of the conditional — they always run regardless of restore vs fresh path.
  - `_refresh_all()` always runs after, rendering the restored state correctly.
  - `GameState` was already `preload`ed at the top of the file.
- `autoloads/SceneManager.gd`:
  - `_on_battle_won()` and `_on_battle_lost()` both now call `save_manager.clear_pending_battle_state()`.
- Tests: 283 passed / 6 failed (no regression).

## Documentation Updates

None — agent docs updated in TID-133.
