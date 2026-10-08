# TID-709: Real-time integration: hand replaces the bar

**Goal:** GID-175
**Type:** agent
**Status:** done
**Depends On:** TID-707

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

Remove the fixed skill bar from real-time fights so every technique is played from the hand.

## Research Notes

- From TID-707: use `TechniqueDefs.cast_time(id)` (≥ 0 overrides the spell cast formula in `run_cast`) and `TechniqueDefs.off_gcd(id)`. Kick/Daze currently resolve `stun_single`/`freeze_single` on a minion. In real time they must instead interrupt the enemy cast (Daze also stuns the hero), so hook them before `resolve_spell`. Identify a technique with `TechniqueDefs.is_technique(card.template_id)`.
- Remove `scenes/battle/modules/BattleSkillBar.gd` (`BattleRealtime.skills`) and its strip/keys 1-3 from the bottom action band. Keys 1-3 (or 1-7) may now target hand slots, with touch parity.
- Momentum: `MomentumHud.wrap_card` skips skill pseudo-cards (`cost_points` meta). Technique cards are the builders now: `RealtimeCombat.on_player_hit(dmg, builder)`, combo/proc rules.
- Cast-time techniques (Mend, Ember Lance) go through `BattleRealtime.run_cast`. An `off_gcd` card (Kick, Daze) must bypass the GCD gate.
- Kick pulse when an enemy casts: move it to the Kick card in the hand (`RealtimeVisuals.update_hand_sweep`, `self_modulate` pulses).
- Tuning: re-check `draw_interval` / `hand_cap` / opening `trim_hand` in `CombatTuning.gd` so a filler is usually in hand.
- Tests: `tests/realtime_battle_smoke.gd`, `test_combat_momentum.gd`. Run `scripts/unsafe-hits.sh` and gdlint.

## Plan

Medium–high complexity, but the design was already settled, so I proceeded without an approval stop.
1. Drop the BattleSkillBar construction and key handling.
2. Add technique hooks to BattleRealtime: cast override, off-GCD resolve, Kick/Daze reactive resolve, a builder hook after resolve, Kick pulse, `technique_control`.
3. Route hand taps in BattleInput.
4. Exempt techniques from combo spending and free-cast procs.
5. Onboarding: the hand is always shown, minions/spells are stripped until learned, and tips anchor to cards.
6. Mentor bark on technique return.
7. Rewrite the smoke test's skill-bar check for hand techniques.

## Changes Made

- New `scenes/battle/modules/RealtimeTechniques.gd` (`BattleRealtime.techniques`): `is_off_gcd`, `blocker`, `resolve_reactive`, `after_resolve`, `casting_enemy`, `control_for`, `pulse_reactive`. It was extracted because gdlint's max-public-methods limit (30) blocked adding them to BattleRealtime.
- `scenes/battle/modules/BattleRealtime.gd`: `skills` / BattleSkillBar removed; `run_off_gcd`; `run_cast` defaults to `TechniqueDefs.cast_time`.
- `scenes/battle/modules/BattleInput.gd`: `_off_gcd`, `_realtime_technique_tap`; `_cast_confirmed_spell` uses `resolve_reactive` and `run_off_gcd`.
- `game_logic/battle/PlayerState.gd`: techniques never consume `next_card_free`.
- `scenes/battle/modules/MomentumHud.gd`: techniques skip `wrap_card`, replacing the old `cost_points` pseudo-card check.
- `scenes/battle/modules/BattleModifiers.gd`: `_apply_combat_unlocks` keeps techniques and strips minions until `feat_minions`.
- `scenes/battle/modules/BattleOnboarding.gd`: the hand is no longer hidden; tips anchor via `technique_control`; out-of-mana tip fires below one cost unit.
- `scenes/battle/modules/MentorBarks.gd`, `game_logic/battle/BarkRules.gd`: `cooldown_ready` now means a technique came back into the hand.
- `scenes/battle/modules/BattleShortcuts.gd`: hand keys start at 1.
- `game_logic/TutorialRegistry.gd`: `rt_*` texts describe technique cards.
- `tests/unit/test_scene_module_guardrail.gd`: allow-list `_RealtimeTechniques.new(_battle, self)`.
- Tests: `tests/realtime_battle_smoke.gd` (technique checks replace the skill-bar checks; first fight is technique-only), plus a free-cast exemption test in `test_technique_cards.gd`.
- Validation: full suite PASS with 0 SCRIPT ERROR; CI smoke list clean; gdlint and unsafe-hits clean.
- Left for TID-710: the unused `BattleSkillBar.gd` / `SkillBar.gd` files, `skill_bar` save field, `SkillBarScene`, the trainer's "Skill Bar" button, and `FightStats` wording.

## Documentation Updates

combat-model.md → new "Real-time integration (TID-709)" subsection.
