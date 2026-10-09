# TID-731: Design: card-modifier vocabulary + 48 node table

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

- Tree shape per branch: col 0 and col 3, rows 0–1 passive, row 2 active (16 actives, 32 passives). Prereqs chain down a column.
- Branch card counts: dawn 29, dusk 24, ember 19, ash 18, bloom/thorn/flux/fracture 3 each → Verdant/Rift nodes should use generic filters.
- Hooks: `PlayerCaster.begin` (cast time), `_after_technique` (recycle), `SpellEffectResolver.resolve_spell` power line (power/crit), card.cost (cost), `RealtimeCombat.next_card_instant` (instant).
- Techniques: `TechniqueDefs.DEFS` (rt_value, recycle, cast, off_gcd), DECK_MAX 3.

## Plan

_TBD._

## Changes Made

_TBD._

## Documentation Updates

_TBD._
