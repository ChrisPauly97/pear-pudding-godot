# TID-285: Agent Docs Update

**Goal:** GID-076
**Type:** agent
**Status:** done
**Depends On:** TID-284

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

Update `docs/agent/battle-system.md` to document all 20 new `spell_effect` keys and the expanded spell catalogue per branch.

## Research Notes

### File to update
`docs/agent/battle-system.md`

### What to add/update

1. **Card Data section** — extend the `spell_effect` supported values list with all 20 new keys and their descriptions.

2. **Targeting arrays** — update the documented `_ENEMY_TARGETED_EFFECTS` and `_FRIENDLY_TARGETED_EFFECTS` lists.

3. **Spell catalogue table** (if one exists) — add rows for all 40 new spells grouped by branch.

4. Keep the existing doc structure; amend in-place rather than reorganizing.

## Plan

Update `docs/agent/battle-system.md`: extend spell_effect values list with 20 new keys, update targeting arrays, add 40-card spell catalogue section.

## Changes Made

- `docs/agent/battle-system.md`: added 20 new spell_effect descriptions to Card Data section
- `docs/agent/battle-system.md`: updated ENEMY_TARGETED_EFFECTS (now 7 entries) and FRIENDLY_TARGETED_EFFECTS (now 7 entries) in SpellEffectResolver section
- `docs/agent/battle-system.md`: added "Magic Subtype Spell Catalogue (GID-076)" section with 4 branch tables

## Documentation Updates

`docs/agent/battle-system.md` is now current for GID-076.
