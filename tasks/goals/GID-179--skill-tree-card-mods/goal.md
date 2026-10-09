# GID-179: Skill Tree Modifies Cards

## Objective

Skill tree nodes change how cards play (recycle, cost, cast time, power, crits, on-crit triggers) instead of adding flat hero stats, and every active skill is a technique card in the deck. Dig is gated by the deck on every path.

## Context

User (2026-10-09), after an audit against spec → Identity ("the card is the atomic unit"): "let's fix dig … skills in the tree should do things like recycle 'frost' cards faster or w/e or instant cast when x skill crits on another skill". Decisions: actives become technique cards; card modifiers apply in **real-time fights only** (turn-based gets no skill-tree stats).

Today: 32 passives add hero HP / attack / mana / draw (`BattleSetup.apply_passives`); 16 actives drive a fixed hero-power button (`BattleConsumables`). Only swings crit. Burial-mound Dig is deck-gated but the legend riddle dig (`Legend.try_dig`) skips the deck and cooldown checks.

## Tasks

| ID | Name | Type | Status | Depends On |
|----|------|------|--------|------------|
| [TID-730](TID-730--dig-deck-gate.md) | Dig: deck + cooldown gate on every dig path | agent | done | — |
| [TID-731](TID-731--skill-mod-design.md) | Design: card-modifier vocabulary + 48 node table | agent | done | — |
| [TID-732](TID-732--spell-crits.md) | Spells and techniques can crit (real time) | agent | done | TID-731 |
| [TID-733](TID-733--skill-mods-engine.md) | SkillMods engine: recycle / cost / cast / power / crit / on-crit; passives removed | agent | done | TID-732 |
| [TID-734](TID-734--skill-techniques.md) | Skill .tres re-authored; actives → technique cards; hero power removed | agent | done | TID-733 |
| [TID-735](TID-735--skill-tree-ui-balance.md) | Skill tree UI text, save repair, balance re-baseline, docs | agent | todo | TID-734 |

## Acceptance Criteria

- [x] Dig at a riddle spot needs 4+ Skeleton-family cards and respects the cooldown
- [x] No skill adds flat hero HP / attack / mana / draw; no hero-power button
- [x] Each of the 16 active nodes grants a technique card
- [x] Spells/techniques crit in real time; an on-crit node can make the next card instant
- [ ] Balance bands pass; baseline re-written if numbers moved
