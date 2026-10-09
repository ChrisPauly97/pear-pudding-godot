# TID-730: Dig: deck + cooldown gate on every dig path

**Goal:** GID-179
**Type:** agent
**Status:** todo
**Depends On:** —

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

See goal.md (user request 2026-10-09).

## Research Notes

- `Cantrips.activate_skeleton_dig` (scenes/world/modules/Cantrips.gd:47) checks only `has_learned(FEAT_DIG)`, then tries a mound (`BurialMound.interact` re-checks learned, deck via `CantripManager.is_available("skeleton_dig", deck)`, cooldown) else `legend.try_dig` (no deck / cooldown check).
- Phase does the deck check in Cantrips (line 28). Mirror it; keep the D-key `quiet` path silent.
- BurialMound keeps its own checks (it's also reachable by interact).

## Plan

_TBD._

## Changes Made

_TBD._

## Documentation Updates

_TBD._
