# BID-078: Enemy spell cards never resolve

**Category:** bug / design-gap
**Discovered During:** code review of TID-541 (2026-09-29)

## Description

Enemy decks that contain spells get nothing from them:
- **Turn-based:** `BasicAI` plays the card through `PlayerState.play_card`, which puts a spell straight into
  `discard` — no `SpellEffectResolver.resolve_spell` call. (`pending_auto_spells` only holds auto-resolve cards
  on draw.) Mana is spent for nothing.
- **Real time:** `RealtimeCombat.choose_enemy_card` skips `card_class == "spell"` entirely.

Affected today: every enemy deck with a spell, e.g. `forest_shade` (`insight`, …). It also blocks "solo" enemies that
fight with abilities (TID-541 tried an all-spell Warlord and had to revert it).

## Suggested Fix

Resolve enemy spells through the resolver with the enemy as caster: in turn-based, have `BasicAI`'s spell action
queue the card for `BattleScene` to `resolve_spell(card, ai_idx)` (targets: the player's hero or board); in real
time, allow spells in `choose_enemy_card` and resolve them on `enemy_cast` with an explicit target (the resolver's
`_state.opponent()` is relative to `current_player_idx`, which real time pins to the player). Re-balance enemy
decks that contain spells afterwards.
