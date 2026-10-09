# TID-733: SkillMods engine

**Goal:** GID-179
**Type:** agent
**Status:** done
**Depends On:** TID-732

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

See goal.md (user request 2026-10-09).

## Research Notes

- Remove `BattleSetup.apply_passives` + its caller `BattleModifiers._apply_passive_skills`.
- Cost: mutate CardInstance.cost at real-time battle build so card faces show it.

## Plan

Pure `SkillMods` on `PlayerState.skill_mods` (real time only); hooks in cost, cast, recycle, power.

## Changes Made

- `game_logic/battle/SkillMods.gd`: filters (branch / spell / technique / ally / damage / heal / id), `cost_for`, `cast_mult`, `recycle_mult`, `power_for`, `crit_bonus`, `instant_on_crit`, `refund_on_crit`, `can_crit`.
- `SkillData`: `filter`, `grants_card` fields; effect vocab comments.
- `PlayerState.skill_mods`; `effective_cost` uses `cost_for` (hand cards show the discount).
- `RealtimeCombat.instant_next`; `PlayerCaster.begin` applies cast mult and consumes `instant_next`; `_after_technique` applies recycle mult.
- `BattleSetup.apply_skill_mods` replaces `apply_passives` (sim `cfg.skills`); `BattleRealtime.maybe_start` applies it; `BattleModifiers._apply_passive_skills` + its call removed (turn-based gets no skill stats).
- Tests: `tests/unit/test_skill_mods.gd` (11).

## Documentation Updates

- `combat-model.md` → "Skill tree modifies cards".
