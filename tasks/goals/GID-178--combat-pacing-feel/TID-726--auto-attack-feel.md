# TID-726: Auto-attack wind-up and hit effect

**Goal:** GID-178
**Type:** agent
**Status:** done
**Depends On:** —

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

See goal.md (user request 2026-10-08).

## Research Notes

_TBD._

## Plan

Hero tokens get a wind-up tell over the end of their swing timer; every swing gets an impact effect at the target.

## Changes Made

- `scenes/battle/modules/SwingFx.gd`: `wind_up` (lean, swell, glow over the last 35 % of the swing, eased in) and `impact` (slash Line2D + 7 sparks, gold / red, delayed to meet the lunge).
- `RealtimeVisuals.update` drives the wind-up for every hero token; `BattleRealtime._animate_swing` spawns the impact for every swing.
- `tests/unit/test_swing_fx.gd`.

## Documentation Updates

- `docs/agent/combat-model.md`: "Auto-attack feel".
