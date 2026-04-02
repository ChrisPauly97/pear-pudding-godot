# TID-036: Auto-resolve spell cards + dagger_throw

**Goal:** GID-014
**Type:** agent
**Status:** pending
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

_Written during Plan phase._

## Changes Made

_Filled after Build phase._

## Documentation Updates

_What was updated in agent docs._
