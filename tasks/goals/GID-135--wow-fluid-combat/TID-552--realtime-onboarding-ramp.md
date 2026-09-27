# TID-552: Real-Time Onboarding Ramp (Staged Control Unlocks)

**Goal:** GID-135
**Type:** agent
**Status:** done
**Depends On:** TID-550

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

User approved (2026-09-26): new players meet real-time combat one control at a time instead of timer, casts,
three skills and a hand all at once.

## Research Notes

- Skill bar: `SkillBar` / `BattleSkillBar` (TID-550). Clock speed: `BattleRealtime._speed_factor`.
- Existing turn-based first-battle tips fire from `BattleScene._ready` after `realtime.maybe_start`.

## Plan

Pure `CombatOnboarding` stage table keyed on a new `SaveManager.realtime_fights` counter (skipped above level 2):
fight 1 Strike + auto-attack, slow clock, no hand; fight 2 + Mend; fight 3 + Kick; fight 4+ full fight with cards.
`BattleOnboarding` (owned by BattleRealtime) applies it: filters the bar, hides hand + your unit slots, slows the
clock; the turn-based card tips are skipped while the hand is hidden.

## Changes Made

- `game_logic/battle/CombatOnboarding.gd` (new): `STAGES`, `stage_for`, `filter_skills`, `shows_hand`,
  `slow_clock`, `new_skills`.
- `scenes/battle/modules/BattleOnboarding.gd` (new): `begin` (counts the fight), `apply`, `filter_skills`.
- `BattleRealtime`: `onboarding` field, filtered bar, slow clock, `token()`, `unit_panel()`, `shows_card_tips()`.
- `RealtimeVisuals`: `token(side)`; skill strip centres when the hand is hidden.
- `BattleScene`: card tips gated on `realtime.shows_card_tips()`.
- `SaveManager.realtime_fights` persisted field.
- Tests: `test_combat_onboarding.gd`; `realtime_battle_smoke` first-fight phase; smokes skip the ramp.

## Documentation Updates

`docs/agent/combat-model.md` — "New-player onboarding" section.
