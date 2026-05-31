# TID-121: Update Agent Documentation

**Goal:** GID-031
**Type:** agent
**Status:** pending
**Depends On:** TID-119, TID-120

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

GID-031 significantly changes the skill system: single tree → 4 branch trees, new currencies, new save fields, new UI flow. Agent docs must reflect the final state so future tasks can orient quickly.

## Research Notes

**Create** `docs/agent/skill-trees.md` covering:
- Key Features: 4 branch trees, home magic type selection, corruption/redemption currencies
- How It Works: SkillData fields (magic_branch, alt_cost), SkillRegistry.get_by_branch(), SkillTreeScene tab layout, cross-magic tab, currency spend paths
- SaveManager fields: magic_type, corruption_points, redemption_points, skill_points; version history
- Earn hooks: add_corruption_points / add_redemption_points / GameBus signals (not yet wired to dialogue)
- Integration with battle: passive skill application and active hero power unchanged — still keyed by skill ID
- Asset requirements: data/skills/*.tres + *.tres.uid, 6 per branch

**Update** `docs/agent/signals-and-constants.md`:
- Add `corruption_points_changed(new_amount: int)` and `redemption_points_changed(new_amount: int)` to the GameBus signal table

**Update** `docs/agent/save-system.md`:
- Add v13 migration entry
- Document the three new SaveManager fields

**Update** `CLAUDE.md` docs table:
- Add row for `docs/agent/skill-trees.md`

## Plan

_Written during Plan phase._

## Changes Made

_Filled after Build phase._

## Documentation Updates

_What was updated in agent docs._
