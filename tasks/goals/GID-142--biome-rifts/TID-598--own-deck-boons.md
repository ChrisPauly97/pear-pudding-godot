# TID-598: Own Deck + Draft Boons

**Goal:** GID-142
**Type:** agent
**Status:** done
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

Rift runs build the player deck from the collection + run picks; draft becomes 2 cards + 1 buff boon; boons apply at battle start; everything run-scoped.

## Changes Made

- `RiftDefs.gd`: `BOONS`, `is_boon`, `boon_total`.
- `SaveSpire.gd`: `uses_own_deck`, `drafted_cards`, `boons`, `add_boon` (Vigor heals the carried HP).
- `BattleModifiers._build_rift_deck()`; `BattleScene` spire branch calls it (one line changed).
- `SpireDraftScene.gd`: boon slot + boon panel, "Choose a Boon" header, boon picks go to `add_boon`.
- Tests: `test_rift_defs.gd` +1 (picks never enter the collection, boons reset per run); `spire_draft_smoke.gd`
  expects own deck + pick. Suite green; smokes clean; gdlint + unsafe-hits clean.

## Documentation Updates

`rifts.md` "Own deck + boons".
