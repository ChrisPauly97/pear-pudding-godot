# TID-708: Learning grants cards + save migration

**Goal:** GID-175
**Type:** agent
**Status:** pending
**Depends On:** TID-707

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

Trainer-taught abilities become technique cards added to the collection; existing saves are migrated.

## Research Notes

- `SaveManager.learned_abilities` holds BOTH ability ids and UnlockLadder feat ids (`feat_*`). Only convert the ability ids.
- `SaveManager.skill_bar` (PERSISTED_FIELDS) is retired. The migration goes in `game_logic/save/SaveMigrations.gd` (bump `CURRENT_VERSION`, append a row): add the learned technique cards to the collection and the bar's techniques to the active deck/loadout if there is room.
- `UnlockLadder.gd` rows reference `SkillBar.ABILITIES` (line ~11). Point them at the technique card ids instead.
- Trainer panel: `scenes/world/modules/NpcInteractions.gd` (`show_trainer_panel`). "Learn" grants the card and shows its face (card-visuals).
- Starter deck: include Strike (new_game around SaveManager.gd:571; deck defaults).
- Deck builder: `docs/agent/inventory-and-deck.md`. Enforce the copy limit there.
- Tests: `test_save_manager` round-trip, a migration test, `test_unlock_ladder`.

## Plan

_Written during Plan phase._

## Changes Made

_Filled after Build phase._

## Documentation Updates

_What was updated in agent docs._
