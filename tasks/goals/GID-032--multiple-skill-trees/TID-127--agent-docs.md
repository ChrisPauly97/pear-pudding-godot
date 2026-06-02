# TID-127: Update Agent Documentation

**Goal:** GID-032
**Type:** agent
**Status:** done
**Depends On:** TID-125, TID-126

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

GID-032 significantly changes the skill system: single tree → 4 branch trees, new currencies, new save fields, new UI flow. Agent docs must reflect the final state so future tasks can orient quickly.

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

1. Create `docs/agent/skill-trees.md` covering all new systems.
2. Add 4 signals to the table in `docs/agent/signals-and-constants.md`.
3. Add migration history table + 7 new fields to `docs/agent/save-system.md`.
4. Add row to the docs table in `CLAUDE.md`.

## Changes Made

- Created `docs/agent/skill-trees.md` — full coverage of branch trees, magic type selection, skill roster, SkillRegistry API, SkillTreeScene flow, SaveManager fields, cross-magic currencies, and battle integration.
- `docs/agent/signals-and-constants.md`: added `level_up`, `xp_changed`, `corruption_points_changed`, `redemption_points_changed` rows to signal reference table.
- `docs/agent/save-system.md`: added full migration history table (v1–v13); added `xp`, `level`, `skill_points`, `unlocked_skills`, `magic_type`, `corruption_points`, `redemption_points` to field descriptions.
- `CLAUDE.md`: added row for `docs/agent/skill-trees.md` in the documentation table.

## Documentation Updates

See Changes Made above.
