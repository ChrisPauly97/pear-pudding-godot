# TID-723: Re-tune quest / kill XP and gold to the new curve; pacing test

**Goal:** GID-177
**Type:** agent
**Status:** pending
**Depends On:** TID-721, TID-722

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

Make the whole starter chain land on the pacing targets and keep training affordable.

**Pacing targets (user, 2026-10-08):**
- Levelling is much slower; there's no rush to level 10.
- Level 1 takes about **10 minutes** of play, and each level after takes longer ("graduating up"). Working model: +5 min per level, so L1 10, L2 15, L3 20 … L9 50 min, about 4.5 h to level 10. Confirm the step when the first numbers are in.
- From level 3 on, a level takes **a few quests** (about 3–4) plus the kills along the way.

## Research Notes

- `tests/unit/test_side_quests.gd` `test_starter_chain_paces_levels_and_gold` simulates the chain with quest + camp kill XP (`StarterZone.camp_for_level`, `ZoneLevels.scaled_xp`) and asserts that each UnlockLadder training is affordable when its quest asks for it, and level 6 + companion gold at the end. Rework it into a time-based pacing check against the targets (L1 ≈ 10 min, +5 min / level) using the TID-721 time model.
- Gold: UnlockLadder costs (15 … 1000) must still be affordable at each level given the slower pace, since players get more kills per level now. Re-check coin rewards.
- Docs: starter-zone-and-training.md (pacing table), save-system (migration).

## Plan

_Written during Plan phase._

## Changes Made

_Filled after Build phase._

## Documentation Updates

_What was updated in agent docs._
