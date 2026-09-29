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

## Open design questions (2026-09-29)

Not started on purpose — a choice is needed first:
- **Which enemies are leaderless?** `ghoul_pack` has a leader by name; `undead_horde` ("Horde Shambler") fits a
  leaderless horde, but its soulbind condition (`spell_final_blow`) is about the killing blow on the hero, so the
  capture condition would need a new meaning (e.g. "last pack member dies to a spell").
- **Real time:** the hero's auto-attack targets the enemy hero (`RealtimeCombat.target_enemy`); with no hero it
  must pick a pack member, and the enemy-side hero swing / heavy blow must be off.
- Cheapest mechanism: keep a hidden, invulnerable enemy hero and kill it when the board empties, so every
  existing win path still works.
