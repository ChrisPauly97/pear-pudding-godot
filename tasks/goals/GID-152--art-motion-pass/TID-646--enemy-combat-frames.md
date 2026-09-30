# TID-646: Enemy attack, hit and death frames

**Goal:** GID-152
**Type:** agent
**Status:** pending
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

_Written during Plan phase._

## Changes Made

_Filled after Build phase._

## Documentation Updates

_What was updated in agent docs._
