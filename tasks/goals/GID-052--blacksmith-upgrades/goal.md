# GID-052: Blacksmith Weapon Upgrades

## Objective

A blacksmith NPC who upgrades weapons through levels (+1…+5) for coins and essence, and salvages duplicate weapons, giving both currencies a steady mid-game drain.

## Context

Weapons (GID-014/022/029) are static once found, and essence from GID-028 only feeds card crafting. Upgrade levels give weapons a progression ladder; salvage turns duplicate drops into currency instead of dead inventory.

## Tasks

| ID | Name | Type | Status | Depends On |
|----|------|------|--------|------------|
| TID-191 | Weapon upgrade levels: data model, coin+essence cost curve, stat scaling, save fields | agent | done | — |
| TID-192 | Blacksmith NPC + upgrade screen UI | agent | done | TID-191 |
| TID-193 | Salvage duplicate weapons + upgraded-stat display in CharacterScene | agent | done | TID-191, TID-192 |

## Acceptance Criteria

- [ ] Owned weapons carry an upgrade level 0–5 persisted in SaveManager with migration; each level scales the weapon's battle effect by a defined curve, applied wherever weapon stats feed battles
- [ ] Upgrade costs follow a curve (e.g. level n: 100×(n+1) coins + 5×(n+1) essence — tune to the real economy); upgrades are refused with insufficient funds, with clear feedback
- [ ] A blacksmith NPC in a town opens an upgrade screen listing owned weapons with current level, next-level stats preview, cost, and an Upgrade button
- [ ] Duplicate weapons can be salvaged at the blacksmith for coins + essence (less than acquisition value); equipped weapons cannot be salvaged
- [ ] CharacterScene shows the upgrade level (+N) and upgraded stats on equipped weapons
- [ ] Fully touch-operable, viewport-relative sizing (mobile parity per CLAUDE.md)
- [ ] All tests pass headless
