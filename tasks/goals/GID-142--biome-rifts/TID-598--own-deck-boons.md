# TID-598: Own Deck + Draft Boons

**Goal:** GID-142
**Type:** agent
**Status:** pending
**Depends On:** TID-597

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

Rifts test *your* build. Drop the fixed starter deck; after each floor pick 1 of 3 temporary boons that last the run.

## Research Notes

- Current run deck: `SaveSpire.STARTER_DECK` (L13), `run_deck()` (L61), `add_drafted_card` (L90); draft UI
  `scenes/ui/SpireDraftScene.gd`, generation `game_logic/spire/SpireDraft.gd` (`generate_picks(floor, rng, pool)`,
  `tier_weights(floor)`); shown by `SceneManager._show_spire_draft(floor)` (post-swap only — see CLAUDE.md "Spire draft
  never appeared" rule).
- New run deck = `SaveManager.player_deck` snapshot at run start + drafted boons. Boons: either temporary card copies
  (not added to `owned_cards`; must never leak into the collection or veterancy stats) or run buffs (e.g. +max HP,
  +1 starting mana, skill cooldown −10%). Store in `spire_run["boons"]`.
- Battle hookup: where the spire battle builds the player deck (`BattleScene` spire branch / `BattleVictory`
  `_spire_battle_won`) — use run deck + apply buff boons via `BattleModifiers`.
- `RunSummaryScene.gd` shows drafted cards — show boons instead.
- Tests: boon picks never touch `owned_cards`; run deck = player deck + boons; buffs apply once.

## Plan

_Written during Plan phase._

## Changes Made

_Filled after Build phase._

## Documentation Updates

_What was updated in agent docs._
