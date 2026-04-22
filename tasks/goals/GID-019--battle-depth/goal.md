# GID-019: Battle Depth — Targeting, Intent & Status Effects

## Objective

Add the three missing strategic layers that make card battles feel deep: spell targeting UI, enemy intent display, and a status effects system.

## Context

The battle loop is functionally complete but lacks depth. Spells auto-fire with no player target selection, enemy actions are invisible until they happen, and there are no persistent status effects. These three features are present in every major TCG (Hearthstone, Slay the Spire) and are the primary driver of turn-by-turn decision quality.

## Tasks

| ID | Name | Type | Status | Depends On |
|----|------|------|--------|------------|
| TID-058 | Spell targeting UI | agent | done | — |
| TID-059 | Enemy intent display | agent | done | — |
| TID-060 | Status effects data model | agent | done | — |
| TID-061 | Status effect turn processing | agent | done | TID-060 |
| TID-062 | Status effect UI indicators | agent | done | TID-060 |

## Acceptance Criteria

- [ ] Targeted spells show a target-selection overlay; untargeted spells still auto-resolve
- [ ] Enemy turn shows an intent banner indicating the AI's planned action
- [ ] Poison, armor, freeze, and stun can be applied to minions and heroes via card effects
- [ ] Status effects are processed at correct turn boundaries (start/end of turn)
- [ ] Active status effects are visually indicated on the affected card/hero
- [ ] All tests pass headless
