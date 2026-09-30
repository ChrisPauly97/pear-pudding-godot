# TID-646: Enemy attack, hit and death frames

**Goal:** GID-152
**Type:** agent
**Status:** done
**Depends On:** TID-645

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

Realtime battle units only tween (lunges); enemies need attack / hit / death frames. Part of GID-152 (art motion pass).

## Research Notes

- Generate `<name>_attack_1..3`, `_hit_1`, `_death_1..3` in `generate_characters.py` (wind-up, strike, recover; flinch; collapse/fade).
- Consumers: `scenes/battle/modules/RealtimeVisuals.gd` (hero tokens, unit lunges on enemy swings), `BattleRealtime` enemy casts; world defeat fade in `EnemyNPC.gd` (~L167, fades the Sprite3D modulate). Play attack on swing, hit on damage, death before fade.
- Timings from `game_logic/battle/CombatTuning.gd` (add knobs there, not constants).

## Plan

Derive 7 combat frames per enemy from its idle (row shear + squash) in one tool; `CombatFrames` preload table;
`TokenFrames` helper plays them on the battle token (attack on lunge, flinch on hero damage, death when fallen).

## Changes Made

- New `tools/derive_combat_frames.py`; 161 new `enemy_*_{attack_1..3,hit,death_1..3}.png`.
- New `game_logic/CombatFrames.gd`, `scenes/battle/modules/TokenFrames.gd`.
- `scenes/battle/modules/RealtimeVisuals.gd`: register / attack / observe hooks (+6 lines).
- Test: `tests/unit/test_token_frames.gd`; `in_world_battle_smoke` and `battle_input_flow_smoke` clean.
- Timings are constants in `TokenFrames` rather than CombatTuning knobs: they are presentation, not combat timing.
- The world EnemyNPC does not play the death: its node is freed on return to WORLD whatever the outcome (win or
  flee), so a death there could show on a fled fight.

## Documentation Updates

- `docs/agent/art-sprites.md`: "Enemy combat frames".
