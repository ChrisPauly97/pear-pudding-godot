# TID-732: Spells and techniques can crit (real time)

**Goal:** GID-179
**Type:** agent
**Status:** todo
**Depends On:** TID-731

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

See goal.md (user request 2026-10-09).

## Research Notes

- Swing crits: `RealtimeCombat._resolve_swing` (seeded `rng`, tune `crit_chance` / `crit_mult`).
- Spell power computed at `SpellEffectResolver.resolve_spell` (TechniqueDefs.power). Resolver is shared by scene (BattleTargeting/BattleInput) and sim (PlayerCaster.play).

## Plan

_TBD._

## Changes Made

_TBD._

## Documentation Updates

_TBD._
