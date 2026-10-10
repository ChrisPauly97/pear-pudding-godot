# GID-181: Damage Schools & Matchups (Horizontal Progression)

## Objective

Make breadth — which schools, cards and loadouts the player can field — the main axis of progression, through damage schools, enemy resistances/weaknesses and matchup knowledge.

## Context

User request 2026-10-09: integrate horizontal progression from the start. User constraints: **no level cap**, **no XP/level scaling of the player or enemies to each other**. Chosen direction: "tools" expanded to elemental/school bonuses and resistances (e.g. enemies that resist Verdant abilities). Spec identity (`specification.md` → Identity): the card is the atomic unit; feature filter "does this make the deck matter more?" — schools live on cards, so the deck you bring for a matchup matters more.

Starting tuning: resist ×0.5, weak ×1.5, immune only on boss phases; all knobs in `CombatTuning`.

## Tasks

| ID | Name | Type | Status | Depends On |
|----|------|------|--------|------------|
| TID-748 | DamageSchools pure module + CombatTuning knobs | agent | done | — |
| TID-749 | Single school-aware damage resolver | agent | pending | TID-748 |
| TID-750 | Enemy school profiles + guardrail test | agent | done | TID-748 |
| TID-751 | Enemy attack schools + hero school resistances | agent | pending | TID-749, TID-750 |
| TID-752 | Combat UI: school-coloured numbers, Weak!/Resisted, nameplate icons | agent | pending | TID-749, TID-750 |
| TID-753 | Bestiary reveals school profiles | agent | pending | TID-750, TID-752 |
| TID-754 | Player school sources: skill-tree nodes, gear affixes, conversion | agent | pending | TID-749, TID-751 |
| TID-755 | Weather / battlefield / night school boosts | agent | pending | TID-749 |
| TID-756 | Matchup loadouts: quick deck swap before a fight | agent | pending | TID-753 |
| TID-757 | Balance sim school sweeps + bands + baseline | agent | pending | TID-750, TID-754, TID-755 |
| TID-758 | Add damage schools to specification.md | human-action | done | — |

## Acceptance Criteria

- [ ] Every damage event (turn-based, real-time, PvP/co-op, balance sim) passes through one `DamageSchools.mult()` call site
- [ ] Every enemy type has a school profile; no enemy resists every school; every biome roster mixes profiles
- [ ] Player sees Weak!/Resisted feedback and (once learned via bestiary) enemy school icons
- [ ] Player can gain school damage/resistance from skill tree and gear, and swap a matchup loadout before a fight
- [ ] Balance bands: mono-school decks stay in band vs mixed biome rosters; the right school measurably helps; no school dominates every biome
- [ ] No level cap added; no player↔enemy level scaling added
- [ ] `docs/agent/damage-schools.md` written and listed in CLAUDE.md
