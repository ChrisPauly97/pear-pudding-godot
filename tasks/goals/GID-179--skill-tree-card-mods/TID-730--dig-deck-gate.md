# TID-730: Dig: deck + cooldown gate on every dig path

**Goal:** GID-179
**Type:** agent
**Status:** done
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

One pure gate (`CantripManager.use_blocker`: deck family + cooldown) run by Phase, mound Dig and riddle-spot Dig.

## Changes Made

- `CantripManager.use_blocker(id, deck, cooldowns, now)` → message or "".
- `Cantrips`: Phase uses it; Dig with no mound checks `Legend.has_dig_spot`, then the gate, then digs, sets the cooldown, emits `cantrip_used`.
- `Legend`: `has_dig_spot` / `_dig_spot` split out of `try_dig`.
- `BurialMound.interact` uses the gate.
- Tests: 3 `use_blocker` cases in `test_cantrip_manager`.

## Documentation Updates

- `card-cantrips.md`, `legends-pear-pudding.md`: riddle dig is deck + cooldown gated.
