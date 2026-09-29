# TID-588: Combat Gates Follow the Ladder

**Goal:** GID-141
**Type:** agent
**Status:** done
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

1. Rewrite `CombatOnboarding` to read `learned_abilities` (stage, hand, spells, slow first clock, forced
   real-time mode) instead of counting fights.
2. `BattleOnboarding` applies it; the bar is already learned-only.
3. Spell cards stripped from the battle deck until `feat_spells`; companion passives until `feat_companion`.
4. `SaveManager.battle_mode()` replaces direct `battle_mode` setting reads.
5. Maiteln barks: eligibility by level (he joins at L6, after the ramp).

## Changes Made

- `game_logic/battle/CombatOnboarding.gd` rewritten (`stage_for(learned)`, `shows_hand`, `allows_spells`,
  `slow_clock`, `battle_mode`).
- `scenes/battle/modules/BattleOnboarding.gd`: ladder-based `begin`, no skill filtering, skill tips on first sight.
- `scenes/battle/modules/BattleModifiers.gd`: `_apply_combat_unlocks()`, `_active_companion()` (used by the three
  companion hooks), realtime check via `battle_mode()`.
- `scenes/battle/BattleScene.gd`: one call to `_apply_combat_unlocks`.
- `scenes/battle/modules/BattleRealtime.gd`: `modifiers_companion()`, bark eligibility by level, real-time enemy
  level from the zone level when present (TID-536), mode via `battle_mode()`.
- `autoloads/SaveManager.gd`: `battle_mode()`. `autoloads/SceneManager.gd`: in-world eligibility via it.
- `game_logic/battle/BarkRules.gd`: `is_eligible(companion, level)`, `COACH_MAX_LEVEL`.
- Tests: `test_combat_onboarding.gd` rewritten, `test_bark_rules.gd` updated, `realtime_battle_smoke.gd`
  onboarding scenario clears learned abilities. Suite green, all CI smokes clean, gdlint + unsafe-hits clean.

## Documentation Updates

`docs/agent/combat-model.md` onboarding + barks sections; `starter-zone-and-training.md`; CLAUDE.md BattleRealtime row.
