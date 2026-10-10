# TID-753: Bestiary reveals school profiles

**Goal:** GID-181
**Type:** agent
**Status:** done
**Depends On:** TID-750, TID-752

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

Knowledge as progression: learning matchups is part of advancing. First encounter hints, defeat reveals the profile.

## Research Notes

- Save: `SaveManager.bestiary` (L284) is `type_id -> {seen, defeated}` — no new persisted field needed (derive: seen ≥1 → attack school known; defeated ≥1 → resist/weak known). Optionally reveal a single school when the player lands a Weak!/Resisted hit (would need a new field — add via PERSISTED_FIELDS + SaveMigrations only if chosen).
- Journal: `scenes/ui/JournalScene.gd` bestiary tab (see docs/agent/bestiary-codex.md) — add a Weak/Resist row with school icons, '?' when unknown.
- Gate TID-752 nameplate pips on this knowledge; floating Weak!/Resisted always shows (that's how players learn).
- Co-op: bestiary is per-player save; fine.

## Plan

1. Pure rule in `game_logic/battle/SchoolKnowledge.gd`: attack school known at `seen >= 1`, weak/resist
   profile known at `defeated >= 1`, both from the bestiary entry. No save field.
2. Gate `SchoolPips.known_profile(enemy_type, entry)` on that rule; `build` takes the entry.
3. Journal bestiary tiers 1 and 2 show the attack school and Weak / Resist rows, "?" when unknown.
4. Unit tests for the rule, the gated pips and the Journal text. Docs in damage-schools and bestiary-codex.

## Changes Made

- `game_logic/battle/SchoolKnowledge.gd` (new, pure): `attack_school_known`, `profile_known`,
  `known_attack_school`, `known_profile`, `journal_view`.
- `game_logic/battle/SchoolFeedback.gd`: `school_bbcode(school)` (colour dot + name) and
  `bestiary_lines(attack, profile, entry)` (the Journal text, "?" when unknown).
- `scenes/battle/modules/SchoolPips.gd`: `known_profile(enemy_type, entry)` gated on defeat; `build`
  takes the entry as its second argument.
- `scenes/battle/modules/RealtimeVisuals.gd`: passes `SaveManager.get_bestiary_entry(enemy_type)` to
  `SchoolPips.build` (`toast` passed directly as the tap callback, to keep the file at 500 lines).
- `scenes/ui/JournalScene.gd`: `_school_lines(type_id)` added to tier 1 and tier 2 bestiary detail.
- `tests/unit/test_school_knowledge.gd` (new): rule tiers, copy semantics, gated pips, Journal text.
- No save field, so no PERSISTED_FIELDS or SaveMigrations change. Floating Weak!/Resisted labels are unchanged.

## Documentation Updates

- `docs/agent/damage-schools.md`: new "Bestiary School Knowledge (TID-753)" section; pips accessor
  text updated; the planned-list entry for TID-753 removed.
- `docs/agent/bestiary-codex.md`: new "School Knowledge (GID-181 / TID-753)" subsection.
