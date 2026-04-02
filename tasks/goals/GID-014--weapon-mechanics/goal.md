# GID-014: Weapon Mechanics System

## Objective

Add equippable weapons that Saimtar carries in the overworld and that modify TCG battles via deck injection, starting conditions, and passive bonuses.

## Context

The battle system currently has no hero-level equipment. Weapons give Saimtar persistent identity and progression across battles — a Rusty Dagger floods the deck with auto-firing Dagger Throw spells; an Arcane Tome starts with bonus mana; a Heavy Shield adds HP. Mana scaling is intentionally excluded: max mana stays capped at 10 forever and weapons never raise it permanently. Progression happens through better weapons and better cards, not inflating the mana ceiling. See `docs/agent/inventory-and-deck.md` for existing card/deck patterns.

## Tasks

| ID | Name | Type | Status | Depends On |
|----|------|------|--------|------------|
| TID-034 | WeaponData resource + WeaponRegistry | agent | done | — |
| TID-035 | SaveManager: equipped_weapon field | agent | pending | — |
| TID-036 | Auto-resolve spell cards + dagger_throw | agent | pending | TID-034 |
| TID-037 | BattleScene weapon effect hook | agent | pending | TID-034, TID-035, TID-036 |
| TID-038 | Docs: inventory-and-deck.md update | agent | pending | TID-037 |

## Acceptance Criteria

- [ ] `WeaponData.gd` resource class exists with fields: id, display_name, battle_effect_type, battle_effect_value, injected_card_id, injected_card_count
- [ ] `WeaponRegistry.gd` autoload scans `data/weapons/` and resolves weapons by id
- [ ] `rusty_dagger.tres` weapon resource exists in `data/weapons/`
- [ ] `SaveManager` has `equipped_weapon: String` field with v4→v5 migration
- [ ] `CardData.gd` has `auto_resolve: bool` field
- [ ] `dagger_throw.tres` card exists (cost=0, spell_effect="deal_damage_random", auto_resolve=true)
- [ ] Drawing an auto_resolve card fires its effect immediately and discards it (never enters hand)
- [ ] BattleScene applies weapon deck injection at battle start (weapon cards shuffled into draw pile)
- [ ] BattleScene applies starting_mana, starting_hp, passive_atk weapon effects correctly
- [ ] Mana cap remains at 10; no weapon raises max_mana permanently
- [ ] `docs/agent/inventory-and-deck.md` documents the full weapon system
- [ ] All new `.tres` and `.gdshader`-equivalent resource files have `.uid` sidecars
