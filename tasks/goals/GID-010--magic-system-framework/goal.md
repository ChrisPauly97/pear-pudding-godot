# GID-010: Magic System Framework

## Objective

Define and implement the lore, sub-branch personalities, CardData schema extension, and Card/Spell `.tres` assets for the Light and Dark magic types and their first eight abilities.

## Context

The current battle system has four minion card types (Ghost, Skeleton, Zombie, Ghoul) with no magic taxonomy. The player requested a two-axis magic system — Light vs Dark at the top level, with sub-branches (Ember, Dawn, Dusk, Ash) that shape card playstyles. Eight spell abilities (Spark, Flicker, Ember, Scorch, Ash, Brittle, Char, Alight) map cleanly onto the Ember (Light) and Ash (Dark) offensive branches. Dawn and Ash are defined in lore only — no cards in this release.

Cards in this system are **Card / Spell** type: they cost mana, have a targeted or area effect, and do not occupy board slots.

## Tasks

| ID | Name | Type | Status | Depends On |
|----|------|------|--------|------------|
| TID-020 | Magic Lore & Design Doc | agent | done | — |
| TID-021 | Extend CardData with Magic Fields | agent | pending | TID-020 |
| TID-022 | Ember Branch Spell Cards | agent | pending | TID-021 |
| TID-023 | Ash Branch Spell Cards | agent | pending | TID-021 |

## Acceptance Criteria

- [ ] `docs/agent/magic-system.md` exists with Light/Dark lore, all four sub-branch personalities, and proposed stats for all 8 cards
- [ ] `CardData.gd` has `magic_type`, `magic_branch`, and `card_type` fields; `to_template_dict()` updated
- [ ] `.tres` + `.uid` sidecar files created for Spark, Flicker, Ember, Scorch (Ember branch)
- [ ] `.tres` + `.uid` sidecar files created for Ash, Brittle, Char, Alight (Ash branch)
- [ ] All new cards load without error in `CardRegistry`
