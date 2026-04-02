# TID-036: Auto-resolve spell cards + dagger_throw

**Goal:** GID-014
**Type:** agent
**Status:** done
**Depends On:** TID-034

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

The Rusty Dagger injects "Dagger Throw" cards into the draw pile. These are 0-cost spells that fire automatically when drawn — the player never sees them in hand; they deal damage and disappear instantly. This requires two changes: (1) a new `auto_resolve` field on CardData/CardInstance and the draw-time logic to handle it, and (2) a new `deal_damage_random` spell effect handler in BattleScene.

## Research Notes

**Files to modify:**
- `data/CardData.gd` — add `@export var auto_resolve: bool = false`
- `game_logic/battle/CardInstance.gd` — propagate `auto_resolve` from template in `from_template()`
- `scenes/battle/BattleScene.gd` — add `deal_damage_random` handler; add auto-resolve draw logic
- `game_logic/battle/PlayerState.gd` — `draw_card()` may need to trigger auto-resolve

**New card to create:**
- `data/cards/dagger_throw.tres` with:
  - id = "dagger_throw"
  - card_name = "Dagger Throw"
  - cost = 0
  - card_class = "spell"
  - spell_effect = "deal_damage_random"
  - spell_power = 2
  - auto_resolve = true
  - description = "Thrown automatically — deals 2 damage to a random enemy."
- `data/cards/dagger_throw.tres.uid` — uid sidecar

**Auto-resolve draw logic:**
When `PlayerState.draw_card()` draws a card with `auto_resolve == true`:
- Do NOT push it to `hand`
- Instead emit a signal (or return a flag) so BattleScene can fire the spell effect
- Push to `discard` after effect resolves
- Then continue (draw another card? or just count as drawn — decide: count as drawn, no bonus draw)

Preferred approach: return the drawn CardInstance from `draw_card()` (currently void — change return type to `CardInstance`). BattleScene's draw-card path checks `if drawn_card.auto_resolve: _resolve_auto_spell(drawn_card)`.

**deal_damage_random handler:**
In BattleScene's spell dispatch (where "deal_damage_single", "deal_damage_all", etc. are handled):
```gdscript
"deal_damage_random":
    var targets := _state.opponent().board.get_cards()
    if targets.is_empty():
        _state.opponent().hero.take_damage(card.spell_power)
    else:
        var idx: int = randi() % targets.size()
        targets[idx].take_damage(card.spell_power)
```
(Mirrors the "deal damage to face if no targets" convention used by deal_damage_single.)

**Strict-mode notes:**
- `draw_card()` currently returns `void` — changing to `CardInstance` (nullable) is a one-line return type change; check all call sites in PlayerState and BattleScene
- `randi() % targets.size()` — `targets.size()` returns `int`, fine with explicit cast if needed
- CardInstance already has all CardData fields copied via `from_template()` — just add `auto_resolve` to both classes and the template dict

**Existing spell dispatch location:** search BattleScene.gd for `"deal_damage_all"` to find the match/switch block.

## Plan

1. **CardData.gd** — add `@export var auto_resolve: bool = false`
2. **CardInstance.gd** — add `var auto_resolve: bool = false`; copy from template in `from_template()`
3. **PlayerState.gd**:
   - Add `var pending_auto_spells: Array[CardInstance] = []`; clear in `build_deck()`
   - `can_play()` — skip `board.is_full()` check for spells
   - `play_card()` — spells go to discard, not board
   - `draw_card()` — if `card.auto_resolve`: skip `hand.append`, add to `discard` + `pending_auto_spells`
4. **BattleScene.gd**:
   - Add `_resolve_spell_effect(card, caster_pid)` — handles all 6 spell effects incl. new `deal_damage_random`
   - Add `_flush_auto_spells(player_idx)` — drains `pending_auto_spells` and resolves each
   - `_finish_hand_drag()` — capture card before `_cancel_hand_drag`; call `_resolve_spell_effect` for spells
   - `_ready()` — call `_flush_auto_spells(0)` after player `draw_opening_hand`
   - `_on_turn_ended()` — call `_flush_auto_spells(0)` + `_check_game_over()` when player's turn starts
5. **data/cards/dagger_throw.tres** + **.uid** — cost=0, spell, deal_damage_random, auto_resolve=true
Note: AI spell effect dispatch not implemented in this task — AI decks currently contain no spell cards.

## Changes Made

- `data/CardData.gd` — added `@export var auto_resolve: bool = false`; added to `to_template_dict()`
- `game_logic/battle/CardInstance.gd` — added `var auto_resolve: bool = false`; copied from template in `from_template()`
- `game_logic/battle/PlayerState.gd`:
  - Added `var pending_auto_spells: Array[CardInstance] = []`; cleared in `build_deck()`
  - `can_play()` — spells skip the `board.is_full()` check
  - `play_card()` — spells go to `discard` instead of `board`
  - `draw_card()` — auto_resolve cards skip `hand`, go to `discard` + `pending_auto_spells`
- `scenes/battle/BattleScene.gd`:
  - Added `const PlayerState` preload
  - Added `_resolve_spell_effect(card, caster_pid)` — dispatches all 6 spell effects incl. `deal_damage_random`
  - Added `_flush_auto_spells(player_idx)` — drains pending auto spells and resolves each
  - `_ready()` — calls `_flush_auto_spells(0)` after player opening hand
  - `_finish_hand_drag()` — captures played card before cancel; calls `_resolve_spell_effect` for spells
  - `_on_turn_ended()` — calls `_flush_auto_spells(0)` + `_check_game_over()` when player's turn starts
- `data/cards/dagger_throw.tres` — new card: cost=0, spell, deal_damage_random, spell_power=2, auto_resolve=true
- `data/cards/dagger_throw.tres.uid` — uid sidecar (uid://1m7k6jdyain4)

Note: AI spell effect dispatch not implemented — AI decks contain no spell cards currently.

## Documentation Updates

_No agent doc changes — TID-038 handles docs for the full weapon system._
