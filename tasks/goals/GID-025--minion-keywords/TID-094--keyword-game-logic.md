# TID-094: Keyword Game Logic — Ward, Surge, Shroud

**Goal:** GID-025
**Type:** agent
**Status:** done
**Depends On:** TID-093

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

With keywords stored on CardInstance (TID-093), this task implements the three rules in the battle loop.

## Research Notes

**Ward**
- Applies when any entity chooses an attack target among friendly minions
- In `scenes/battle/BattleScene.gd`, find attack target selection for both player and BasicAI
- Rule: if any friendly minion on the target's side has `keywords.has("ward")`, the attacker MUST target one of the Ward minions; non-Ward minions cannot be targeted while a Ward minion is alive
- Multiple Ward minions: attacker can choose any of them
- Hero can still be attacked directly only if NO Ward minion is alive on that side
- BasicAI attack selection needs the same Ward check — it currently picks targets freely; add a filter that restricts valid targets to Ward minions when any exist

**Surge**
- Applies at the moment a minion is placed on the board
- In `BattleScene.gd`, find where `summoning_sick` is set to `true` on placement
- Rule: if the placed CardInstance has `keywords.has("surge")`, set `summoning_sick = false` instead
- No other changes needed — the existing attack eligibility check already uses `summoning_sick`

**Shroud**
- Applies when a minion with `shroud_active == true` takes damage
- In the damage-application function (wherever minion health is reduced), add a check BEFORE applying damage:
  - If `card_instance.shroud_active == true`: set `shroud_active = false`; absorb all damage (health unchanged); emit a signal or call the UI to remove the Shroud badge
  - If `shroud_active == false`: apply damage normally
- Shroud absorbs the entire first hit regardless of damage amount
- Shroud does NOT protect the hero — only minions

## Plan

**Shroud** — `CardInstance.take_damage()`: if `shroud_active` is true, set it false and return early (absorb entire hit), before armor/health reduction. This is the single damage path for all callers.

**Surge** — `PlayerState.play_card()`: after `board.add_card(card)`, if `card.keywords.has(Keywords.SURGE)`, set `card.summoning_sick = false`. Preload `Keywords.gd`.

**Ward** — Two sites:
1. `BasicAI.decide_turn()` and `describe_turn()`: after collecting `targets := state.opponent().board.get_cards()`, filter to Ward minions when any exist. The empty-board hero-attack check naturally stays blocked when Ward minions live. Preload `Keywords.gd`.
2. `BattleScene._on_enemy_card_input()`: after identifying the attacker, filter valid enemy targets via Ward. If player clicks a non-Ward enemy while Ward minions exist, silently return (keep attacker selected so the player can retry on the correct target). `BattleScene._on_enemy_hero_input()`: if any enemy minion has Ward, return early (hero cannot be attacked). Add `_get_ward_valid_targets()` helper. Preload `Keywords.gd`.

## Changes Made

- **`game_logic/battle/CardInstance.gd`** — `take_damage()`: if `shroud_active` is true, set false and return early (entire hit absorbed), before armor/health reduction. Comment updated to reflect Shroud + armor ordering.
- **`game_logic/battle/PlayerState.gd`** — added `const Keywords = preload(...)`. In `play_card()`: after `board.add_card(card)`, if `card.keywords.has(Keywords.SURGE)`, set `card.summoning_sick = false`.
- **`ai/BasicAI.gd`** — added `const Keywords = preload(...)`. Both `decide_turn()` and `describe_turn()`: collect `ward_targets` from `state.opponent().board.get_cards()` and use them as the target list when non-empty (Ward filter). The `targets.is_empty()` hero-attack check naturally handles the case where Ward minions are present (they appear in `targets`, so the branch falls to minion-attack instead of hero-attack).
- **`scenes/battle/BattleScene.gd`** — added `const Keywords = preload(...)`. Added `_get_ward_valid_targets()` helper. In `_on_enemy_card_input()`: after attacker validation, filter valid targets; if clicked card is not in the filtered list, return early (keep attacker selected, player must click a Ward minion). In `_on_enemy_hero_input()`: if any enemy minion has Ward, return early (hero is shielded).

## Documentation Updates

- Updated `docs/agent/battle-system.md` — added keyword game logic section covering Ward (targeting rule, player + AI), Surge (summoning_sick override), and Shroud (hit absorption in `take_damage`).
