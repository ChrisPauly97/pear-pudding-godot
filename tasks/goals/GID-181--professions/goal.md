# GID-181: Professions — Alchemy, Cooking, Crafting

## Objective

Add gatherable materials and three levelled professions (Alchemy, Cooking, Crafting) that turn them into potions, buff foods and gear.

## Context

User request 2026-10-09: "we should add professions like crafting, potion making, cooking etc." Builds on the garden/potion system (`GardenDefs`, `docs/agent/home-garden-potions.md`), merchant-only foods (`HeroVitality.FOODS`), gear rolls (`GearRolls`, GID-136) and trainer unlocks (`UnlockLadder`, GID-141). Decisions taken as defaults (the user approved the breakdown without picking): professions are learned from trainers for gold; fishing and mining are material sources, not separate professions; crafted gear competes with drops but caps at epic.

## Tasks

| ID | Name | Type | Status | Depends On |
|----|------|------|--------|------------|
| TID-748 | Profession core: defs, save fields, module | agent | pending | — |
| TID-749 | Gathering nodes in the world | agent | pending | TID-748 |
| TID-750 | Material drops from enemies | agent | pending | TID-748 |
| TID-751 | Crafting station panel + stations | agent | pending | TID-748 |
| TID-752 | Cooking recipes + well-fed buffs | agent | pending | TID-750, TID-751 |
| TID-753 | Alchemy: potions move to profession recipes | agent | pending | TID-749, TID-751 |
| TID-754 | Crafting: gear from ore and hide | agent | pending | TID-749, TID-750, TID-751 |
| TID-755 | Profession trainers, unlocks, Character tab, docs | agent | pending | TID-752, TID-753, TID-754 |

## Acceptance Criteria

- [ ] One data table (`ProfessionDefs`) defines professions, materials and recipes; tests validate it
- [ ] Materials come from world gathering nodes and enemy drops; both are deterministic and co-op safe
- [ ] Each profession levels through crafting; recipes are gated by skill
- [ ] Cooking yields foods with well-fed battle buffs; Alchemy owns all potions; Crafting makes rolled gear
- [ ] Professions unlock through trainers (UnlockLadder) and show on the Character screen
- [ ] Persisted via `PERSISTED_FIELDS` + migration; full test suite, gdlint and unsafe-hits clean
- [ ] `docs/agent/professions.md` written and indexed
