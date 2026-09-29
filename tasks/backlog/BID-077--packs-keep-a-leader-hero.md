# BID-077: Pack encounters still have an enemy hero (no leaderless 'clear the board' packs)

**Category:** design-gap
**Discovered During:** TID-541

## Description

TID-541's first cut keeps GameState's win rule (enemy hero at 0 HP). combat-model.md's Pack shape — no enemy hero,
win by clearing the board — needs a GameState win-condition flag, BasicAI without a hero, capture conditions that
reference the hero, and real-time targeting/auto-attack without an enemy hero.

## Suggested Fix

A `GameState.board_clear_win` flag set by `_setup_solo_battle` for leaderless packs; `is_game_over()` checks the
enemy board instead of the hero; hide the enemy hero strip; audit CaptureTracker conditions.
