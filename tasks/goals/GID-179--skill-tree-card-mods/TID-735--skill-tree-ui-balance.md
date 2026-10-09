# TID-735: Skill tree UI text, save repair, balance re-baseline, docs

**Goal:** GID-179
**Type:** agent
**Status:** done
**Depends On:** TID-734

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

See goal.md (user request 2026-10-09).

## Research Notes

- SkillTreeScene shows skill_type (line 303). Balance: `tools/balance_sim.gd`, `tests/balance_bands.gd`, `--write-baseline`.

## Plan

Skill-tree labels; sim `--skills`; measure nodes; tune; first skill point at level 10 (user, 2026-10-09).

## Changes Made

- `SkillTreeScene`: type label "Technique card" / "Card modifier".
- `tools/balance_sim.gd --skills id,…`.
- `SkillMods.power_for`: no +1 floor (it made +15 % on Strike +50 %).
- Recycle nodes toned down: Clarity / Fault Line 15 → 10 %, Void Tempo 25 → 15 %.
- User (mid-task): "skill points gain from 10+ maybe?" → `XpCurve.FIRST_SKILL_POINT_LEVEL = 10`, `skill_points_at(level)`; `add_xp`, load cap and head start use it; level-up toast skips the skill line at 0 points; Skills trainer text updated. Skills stays learnable at L7 (pick magic, browse) so the ladder / Old Bones quest are unchanged.
- Measured (L9 +1, 80 fights, scout / hag / stag): none 79 / 51 / 68 %; four Thorn nodes 86 / 63 / 73 %. Bands pass; L1–9 bands never include nodes now.
- Save repair needs no refund: node ids are unchanged; load caps unspent points at `skill_points_at(level)`.

## Documentation Updates

- `combat-model.md`, `skill-trees.md`, `starter-zone-and-training.md`, `balance-sim.md`.
