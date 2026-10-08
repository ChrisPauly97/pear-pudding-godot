# TID-708: Learning grants cards + save migration

**Goal:** GID-175
**Type:** agent
**Status:** done
**Depends On:** TID-707

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

Trainer-taught abilities become technique cards added to the collection; existing saves are migrated.

## Research Notes

- From TID-707: card ids are `tech_strike`, `tech_mend`, `tech_kick`, `tech_guard`, `tech_ember_lance`, `tech_mana_tap`, `tech_sweep`, `tech_daze` (old ability id → `tech_` + id). Level and coin prices are in `TechniqueDefs.DEFS`, with display order `TechniqueDefs.ORDER`. Deck rule: `TechniqueDefs.deck_violation(ids)`. They are not in `CardRegistry.get_all_ids()`.
- `SaveManager.learned_abilities` holds BOTH ability ids and UnlockLadder feat ids (`feat_*`). Only convert the ability ids.
- `SaveManager.skill_bar` (PERSISTED_FIELDS) is retired. The migration goes in `game_logic/save/SaveMigrations.gd` (bump `CURRENT_VERSION`, append a row): add the learned technique cards to the collection and the bar's techniques to the active deck/loadout if there is room.
- `UnlockLadder.gd` rows reference `SkillBar.ABILITIES` (line ~11). Point them at the technique card ids instead.
- Trainer panel: `scenes/world/modules/NpcInteractions.gd` (`show_trainer_panel`). "Learn" grants the card and shows its face (card-visuals).
- Starter deck: include Strike (new_game around SaveManager.gd:571; deck defaults).
- Deck builder: `docs/agent/inventory-and-deck.md`. Enforce the copy limit there.
- Tests: `test_save_manager` round-trip, a migration test, `test_unlock_ladder`.

## Plan

Medium complexity, but the design was already settled, so I proceeded without an approval stop.
1. Keep ability ids in `learned_abilities`, so no gating code changes.
2. Map them to cards via `TechniqueDefs.card_for`.
3. UnlockLadder prices come from TechniqueDefs.
4. `learn_ability` grants the card and deals it into the deck.
5. Strike goes in the starter decks.
6. Migration v46 queues the old bar, and the SaveManager load pass owns and deals the cards (idempotent repair).
7. The deck builder enforces the technique rules; auto-fill skips techniques.
8. Trainer toast.

## Changes Made

- `game_logic/battle/TechniqueDefs.gd`: `card_for`, `ability_for`, `known_cards`.
- `game_logic/progression/UnlockLadder.gd`: skill rows priced from TechniqueDefs (no SkillBar preload); Mend/Kick/Ember Lance how-to texts describe cards.
- `autoloads/SaveManager.gd`: `_own_technique`, `_add_technique_to_deck`, `_restore_technique_cards` (called from `_restore_derived_fields`); `learn_ability` grants the card instead of filling the bar; Strike in `new_game` / `ensure_coop_deck`.
- `game_logic/save/SaveMigrations.gd`: v46 `_m46_technique_cards`.
- `scenes/ui/InventoryScene.gd`: `_technique_violation_with` blocks illegal adds; auto-fill skips techniques. This adds about 12 lines to a file flagged as lint debt (BID-053).
- `scenes/world/modules/NpcInteractions.gd`: "card added" toast on learning a technique.
- Tests: new `tests/unit/test_technique_learning.gd` (6 tests); `test_unlock_ladder` learn test now checks the deck.
- Full suite PASS with 0 SCRIPT ERROR; world_scene_smoke and realtime_battle_smoke clean; gdlint and unsafe-hits clean.
- Not done here: the SessionState (multiplayer session character) starter deck has no Strike. Logged as BID-093.

## Documentation Updates

combat-model.md → "Learning & migration (TID-708)" replaces the migration stub.
