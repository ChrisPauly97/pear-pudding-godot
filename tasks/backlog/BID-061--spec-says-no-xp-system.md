# BID-061: Spec says "No XP system planned" but XP shipped

**Category:** spec-gap
**Discovered During:** GID-136 research

## Description

`docs/human/specification.md` → Open Questions — Resolved states "No XP system planned", but XP, levels and skill
points shipped in GID-030 (`SaveManager.xp`, `xp_for_level`, `_compute_level`) and GID-136 builds on them.

## Evidence

- `docs/human/specification.md` ("Battle rewards beyond card drops" bullet)
- `autoloads/SaveManager.gd` PERSISTED_FIELDS (`xp`, `skill_points`, `unlocked_skills`)

## Suggested Resolution

Human edit of the spec; drafted as part of TID-539.
