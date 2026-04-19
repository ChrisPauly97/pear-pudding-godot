# GID-022: Weapon System Content

## Objective

Expand from 1 weapon to 7, add a weapon comparison UI in inventory, and make weapons discoverable as chest drops, boss drops, and shop items.

## Context

WeaponRegistry and battle integration are complete (GID-014) but only starter_dagger is defined. Players have no reason to look for weapons or make weapon choices. This goal fills the framework with content and wires weapon discovery into the world economy.

## Tasks

| ID | Name | Type | Status | Depends On |
|----|------|------|--------|------------|
| TID-073 | Create 6 new weapon .tres files | agent | pending | — |
| TID-074 | Weapon comparison UI in InventoryScene | agent | pending | TID-073 |
| TID-075 | Weapons as chest and boss drop rewards | agent | pending | TID-073 |
| TID-076 | Add weapons to ShopScene | agent | pending | TID-073 |

## Acceptance Criteria

- [ ] 6 new weapons exist, covering all WeaponData effect types
- [ ] InventoryScene shows equipped weapon stats alongside inspected weapon for comparison
- [ ] Weapons can drop from chests and boss encounters
- [ ] ShopScene lists available weapons with coin prices
- [ ] All tests pass headless
