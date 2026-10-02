# TID-657: Puzzle Content — Tales, Spots, Brew Scene, Reward

**Goal:** GID-153
**Type:** agent
**Status:** pending
**Depends On:** TID-654, TID-655, TID-656

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

Fill the systems with the actual legend content from `goal.md` and TID-653, and wire the chain end to end.

## Research Notes

- Tellers: old soldier (Madrian), child (Maykalene), tavern bard (Blancogov), farmer (Larik). Reuse existing NPCs
  where one fits; otherwise `scripts/add_map_npc.py`. Gate later tales on earlier legend flags so the order reads.
- Spots:
  1. Standing-stone trio — dusk + Skeleton Dig → `legend_recipe` (Burnt Recipe scroll text shown).
  2. Golden pear tree on a cliff in the wilds (fixed stitched-overworld tile, reachable via a non-obvious path) →
     `legend_golden_pear`.
  3. Spectre's Sigh — hook BattleVictory (where bounty `defeat_enemy_type` increments) for `spectre_wisp` /
     `spectre_haunt` while `legend_recipe` is set → `legend_sigh`. Spectres spawn via Night Hunts
     (`NocturnalSpawner`, gated by `UnlockLadder` night hunts).
  4. Ruined well — rain + all three ingredient flags → brew scene (simple modal via `WorldScene._build_modal`) →
     `legend_pudding_owned`, grant the item (TID-656), `GameBus` toast.
- Co-op: legend flags are per-character story flags; do not sync to the party.
- Tests: `tests/unit/test_pear_pudding_legend.gd` — run the whole chain with stubbed conditions, assert nothing
  happens out of condition, item granted once, no QuestLog/ObjectiveTracker entries.
- Run `scripts/unsafe-hits.sh`, gdlint, headless import, full test runner (check log for `SCRIPT ERROR`).

## Plan

_Written during Plan phase._

## Changes Made

_Filled after Build phase._

## Documentation Updates

_What was updated in agent docs._
