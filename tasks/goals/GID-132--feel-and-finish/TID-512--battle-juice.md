# TID-512: Battle Juice

**Goal:** GID-132
**Type:** agent
**Status:** done
**Depends On:** —

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

Battles feel static; few tweens.

## Research Notes

`scenes/battle/BattleFx.gd`, `CardViewBuilder.gd`, `modules/BattleInput.gd`. Respect settings `screen_shake`, `reduce_flashing`, `battle_speed`.

## Plan

New BattleJuice static helpers (pop labels, punch, sparks, pop-in) wired into existing BattleFx paths; board pop-in by diffing ids after refresh; Reduce Flashing respected.

## Changes Made

- New `scenes/battle/BattleJuice.gd`.
- `BattleFx`: amount-aware float labels + sparks, punch on hit, softer flash colour, `pop_new_board_cards`, `mark_board_seen`.
- `BattleScene`: pop-in after `_refresh_all`; travel ghost marks its card seen.
- Tests: new `test_battle_juice.gd`; PvP/co-op battle smoke tests clean. Visual check of label/punch/sparks on gl_compatibility.

## Documentation Updates

battle-system.md: Battle juice bullet.
