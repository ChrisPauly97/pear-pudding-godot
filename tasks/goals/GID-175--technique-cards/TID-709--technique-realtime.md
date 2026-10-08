# TID-709: Real-time integration: hand replaces the bar

**Goal:** GID-175
**Type:** agent
**Status:** pending
**Depends On:** TID-707

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

Remove the fixed skill bar from real-time fights so every technique is played from the hand.

## Research Notes

- Remove `scenes/battle/modules/BattleSkillBar.gd` (`BattleRealtime.skills`) and its strip/keys 1-3 from the bottom action band. Keys 1-3 (or 1-7) may now target hand slots, with touch parity.
- Momentum: `MomentumHud.wrap_card` skips skill pseudo-cards (`cost_points` meta). Technique cards are the builders now: `RealtimeCombat.on_player_hit(dmg, builder)`, combo/proc rules.
- Cast-time techniques (Mend, Ember Lance) go through `BattleRealtime.run_cast`. An `off_gcd` card (Kick, Daze) must bypass the GCD gate.
- Kick pulse when an enemy casts: move it to the Kick card in the hand (`RealtimeVisuals.update_hand_sweep`, `self_modulate` pulses).
- Tuning: re-check `draw_interval` / `hand_cap` / opening `trim_hand` in `CombatTuning.gd` so a filler is usually in hand.
- Tests: `tests/realtime_battle_smoke.gd`, `test_combat_momentum.gd`. Run `scripts/unsafe-hits.sh` and gdlint.

## Plan

_Written during Plan phase._

## Changes Made

_Filled after Build phase._

## Documentation Updates

_What was updated in agent docs._
