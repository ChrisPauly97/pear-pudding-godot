# TID-588: Combat Gates Follow the Ladder

**Goal:** GID-141
**Type:** agent
**Status:** pending
**Depends On:** TID-587

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

Battles currently offer skills, the hand of minion cards, spells and the companion from the start (after a 3-fight ramp).
They must instead show only what the player has learned.

## Research Notes

- `game_logic/battle/CombatOnboarding.gd` stages by *fight count* (strike → +mend → +kick → hand). Replace with ladder
  reads: skills filtered by `learned_abilities` (already via `SkillBar._init(bar, learned)`), hand shown only once
  `feat_minions` learned, spell cards playable only once `feat_spells` learned (hand filtered: minion cards only before
  that). Keep the slow clock for the very first fights (fight-count based is fine for that alone).
- Apply sites: `scenes/battle/modules/BattleOnboarding.gd` (applies CombatOnboarding), `BattleRealtime.gd`,
  `BattleSkillBar.gd`, `BattleConsumables.gd` (potion button → after Mend tier per ladder).
- Companion: `SaveManager.active_companion` (L536, set L1502) and `BattleModifiers._apply_companion_battle_start`
  (L102) — gate on `feat_companion`. `BarkRules.is_eligible` (Maiteln barks) keys on companion + onboarding stage; keep
  barks working in early fights (Maiteln can coach without being a battle companion — check behaviour).
- Deck: before `feat_minions`, the starter deck still exists; the battle just doesn't deal a hand. Enemy AI unaffected.
- Turn-based mode (non-realtime setting) needs the same gates — hand hidden means auto-attack/skills only; verify the
  turn-based path can't soft-lock with no hand (if not viable, force realtime until `feat_minions`).
- Tests: update `tests/unit/test_combat_onboarding*` and add gating tests; run `tests/battle_*smoke*` scene smokes.

## Plan

_Written during Plan phase._

## Changes Made

_Filled after Build phase._

## Documentation Updates

_What was updated in agent docs._
