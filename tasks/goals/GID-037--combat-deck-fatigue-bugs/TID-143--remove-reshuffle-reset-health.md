# TID-143: Remove reshuffle; reset health on discard

**Goal:** GID-037
**Type:** agent
**Status:** pending
**Depends On:** —

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

`PlayerState.draw_card()` currently shuffles the discard pile back into the draw deck when the draw deck is empty. This causes dead minions (health = 0) to re-enter the game. The discard pile should be a permanent graveyard. Additionally, health should be reset to `max_health` whenever a card is discarded so that `resurrect_last` works correctly and future resurrection effects get full-health minions.

## Research Notes

**File to change: `game_logic/battle/PlayerState.gd`**

- Lines 44–58: `draw_card()` — delete the reshuffle block (lines 45–49):
  ```gdscript
  if draw_deck.is_empty():
      draw_deck.append_array(discard)
      discard.clear()
      draw_deck.shuffle()
  ```
  After removal, the second `if draw_deck.is_empty(): return null` at line 50 becomes the only check.

- Add a helper method `discard_card(card: CardInstance) -> void` that resets health and appends to discard:
  ```gdscript
  func discard_card(card: CardInstance) -> void:
      card.health = card.max_health
      discard.append(card)
  ```

- Line 54: `discard.append(card)` inside `draw_card()` (auto_resolve path) → replace with `discard_card(card)`
- Line 77: `discard.append(card)` inside `play_card()` (spell path) → replace with `discard_card(card)`

**File to change: `scenes/battle/BattleScene.gd`**

Replace every `<player>.discard.append(<card>)` call with `<player>.discard_card(<card>)`. Locations:
- Line 1119: `_state.players[1].discard.append(target)` — enemy minion killed by player attack
- Line 1122: `_state.players[0].discard.append(attacker)` — player minion killed by counterattack
- Line 1157: `_state.players[0].discard.append(attacker)` — player minion dies attacking enemy hero
- Line 1268: `opponent.discard.append(target_card)` — deal_damage_single spell
- Line 1279: `opponent.discard.append(targets[0])` — deal_damage_single fallback
- Line 1286: `opponent.discard.append(t)` — deal_damage_all spell
- Line 1296: `opponent.discard.append(targets[idx])` — deal_damage_random spell
- Line 1304: `opponent.discard.append(t)` — destroy_low_hp spell
- Line 1358: `opponent.discard.append(t)` — lifesteal_hit spell
- Line 1372: `opponent.discard.append(t)` — curse_minion spell

**File to change: `ai/BasicAI.gd`**

Lines 50 and 53 also append to discard — replace with `discard_card()`.

**Note:** `resurrect_last` (BattleScene.gd line 1310) already does `t.health = t.max_health` before putting a card back on the board — this remains correct and should be kept as-is.

## Plan

_Written during Plan phase._

## Changes Made

_Filled after Build phase._

## Documentation Updates

Update `docs/agent/battle-system.md` line 37: remove "shuffles discard into draw if empty" — replace with "draws from draw pile; if empty, fatigue triggers (see TID-144)".
