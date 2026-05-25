# GID-029: Character Screen & Multi-Slot Equipment

## Objective

Expand the existing single weapon slot into a full 4-slot equipment system (weapon, armor, ring, trinket) and add a dedicated CharacterScene UI showing the player avatar with visual slot buttons.

## Context

The weapon system (GID-014, GID-022) established a clean pattern: `WeaponData` resources, `WeaponRegistry`, `equipped_weapon` in SaveManager, and `BattleScene._apply_weapon_effect()`. This goal generalises that single slot into four slots and surfaces them in a purpose-built character view. Coins currently have no spend path outside the shop; equipment gives them a second sink. The spec open question about "what are rewards beyond card drops?" is further answered by equipment drops from chests.

## Tasks

| ID | Name | Type | Status | Depends On |
|----|------|------|--------|------------|
| TID-106 | Data model — slot field, 3 new SaveManager fields, save v11 migration, BattleScene applies all 4 slots | agent | done | — |
| TID-107 | New equipment content — 2-3 armor, ring, and trinket `.tres` items with `.uid` sidecars | agent | done | TID-106 |
| TID-108 | CharacterScene UI — player avatar, 4 slot buttons, per-slot item picker, stats panel, C key + HUD button | agent | done | TID-106 |
| TID-109 | Equipment acquisition — chest drops occasionally grant equipment; ShopScene gains equipment rows | agent | pending | TID-106, TID-107 |

## Acceptance Criteria

- [ ] `WeaponData.gd` has a `slot: String` field defaulting to `"weapon"`; all 7 existing weapon `.tres` files continue to work unchanged
- [ ] SaveManager has `equipped_armor`, `equipped_ring`, `equipped_trinket` string fields and corresponding `owned_*` arrays; save v11 migration backfills empty defaults
- [ ] BattleScene applies all 4 equipped items' effects at battle start
- [ ] At least 2 armor, 2 ring, and 2 trinket `.tres` items exist with `.uid` sidecars
- [ ] CharacterScene overlay opens via C key on desktop and a HUD tap button on mobile
- [ ] CharacterScene shows a player avatar and 4 visual equipment slots; tapping a slot opens an item picker for that slot type
- [ ] Chests have a chance to drop equipment instead of a card
- [ ] ShopScene lists equipment for purchase alongside weapons
