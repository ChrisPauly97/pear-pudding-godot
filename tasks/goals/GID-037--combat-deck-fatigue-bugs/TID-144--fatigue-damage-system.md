# TID-144: Implement fatigue damage system

**Goal:** GID-037
**Type:** agent
**Status:** pending
**Depends On:** TID-143

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

After TID-140 removes the reshuffle, `draw_card()` returns `null` whenever the draw deck is empty. This should trigger fatigue: each time a player fails to draw, their fatigue counter increments and their hero takes that many damage. First failed draw = 1 damage, second = 2, etc. Both player and enemy are subject to fatigue.

## Research Notes

**Turn/draw flow:**
1. `BattleScene._on_end_turn()` → `_state.end_turn()`
2. `GameState.end_turn()` switches `current_player_idx`, increments `turn_number`, calls `current_player().start_turn(turn_number)` (which calls `draw_card()`), then emits `turn_ended` signal
3. `BattleScene._on_turn_ended(player_idx)` handles the visual update. By the time it fires, the draw (and any fatigue damage) has already happened.

Additional draw sites in BattleScene (also need fatigue applied if null returned):
- `emergence_draw` effect: `BattleScene.gd` line 1242–1244 — loops `caster.draw_card()` N times
- `draw_card` spell effect: `BattleScene.gd` line 1374–1376 — loops `caster.draw_card()` N times

**Changes: `game_logic/battle/PlayerState.gd`**

1. Add field: `var fatigue_counter: int = 0`
2. Add field: `var last_fatigue_damage: int = 0` (set each draw attempt; reset to 0 if draw succeeds; BattleScene reads this to show notification)
3. In `draw_card()`, after TID-140 removes the reshuffle block, the empty-deck path becomes:
   ```gdscript
   if draw_deck.is_empty():
       fatigue_counter += 1
       last_fatigue_damage = fatigue_counter
       hero.take_damage(fatigue_counter)
       return null
   last_fatigue_damage = 0
   ```

4. In `to_dict()`: add `"fatigue_counter": fatigue_counter`
5. In `from_dict()`: add `ps.fatigue_counter = int(d.get("fatigue_counter", 0))`

**Changes: `scenes/battle/BattleScene.gd`**

In `_on_turn_ended(player_idx)`, after the existing start-of-turn status processing and before `_refresh_all()`, check for fatigue and show a notification:
```gdscript
var fatigue_dmg: int = _state.players[player_idx].last_fatigue_damage
if fatigue_dmg > 0:
    _show_intent_banner("Fatigue! -%d HP" % fatigue_dmg)
    await get_tree().create_timer(1.2, true).timeout
    _hide_intent_banner()
```

This covers the per-turn draw. For the extra draws from spells/emergence (lines 1242–1244, 1374–1376), fatigue damage is applied immediately inside `draw_card()` — the hero HP will update on the next `_refresh_all()` call which already follows those sites. No extra notification is needed there (the HP float label from `_snapshot_hp_positions` / `_spawn_float_labels_from_snapshot` will show the damage).

**`_check_game_over()` is already called after `_refresh_all()` in all relevant paths**, so a hero killed by fatigue will trigger the game-over flow correctly without additional changes.

## Plan

_Written during Plan phase._

## Changes Made

_Filled after Build phase._

## Documentation Updates

Update `docs/agent/battle-system.md` to document the fatigue mechanic: counter per player, damage = counter value, triggers on empty draw deck.
