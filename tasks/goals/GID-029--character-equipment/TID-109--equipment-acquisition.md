# TID-109: Equipment Acquisition

**Goal:** GID-029
**Type:** agent
**Status:** done
**Depends On:** TID-106, TID-107

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

Equipment is useless if players can't find it. This task adds two acquisition paths: random chest drops (discovery) and ShopScene purchases (intentional spend). Coins get a wider spend pool and chests become more exciting.

## Research Notes

**Chest drop logic:**
- Current: `Chest.gd` or `WorldScene` picks a random card from `CardRegistry` and calls `SaveManager.add_card()`.
- Find the actual chest open handler: `GameBus.chest_opened` signal → look in `WorldScene.gd` or `Chest.gd`.
- New behaviour: 20% chance to drop a random equipment item instead of a card.
  ```gdscript
  if rng.randf() < 0.20:
      var all_equip: Array[String] = WeaponRegistry.get_all_ids()  # includes armor/ring/trinket now
      var equip_id: String = all_equip[rng.randi() % all_equip.size()]
      SaveManager.add_equipment(equip_id, WeaponRegistry.get_weapon(equip_id).slot)
      GameBus.equipment_dropped.emit(equip_id)  # new signal for optional toast
  else:
      # existing card drop logic
  ```
- Add a new `GameBus` signal `equipment_dropped(equip_id: String)` for a brief notification.

**ShopScene additions:**
- `ShopScene.gd` currently shows weapon rows via `_refresh_weapons()` / `_make_weapon_row()`.
- Add `_refresh_equipment()` that lists armor, ring, and trinket items not yet owned, with a "Buy" button.
- Pricing formula (extend `_weapon_price()`):
  - `starting_hp`: value × 4 coins
  - `starting_mana`: value × 20 coins
  - `passive_atk`: value × 20 coins
  - `deck_inject`: 30 + count × 5 coins
- On buy: call `SaveManager.add_equipment(id, slot)` and deduct coins via `SaveManager.add_coins(-price)`.
- Group into sections: "Weapons", "Armor", "Rings", "Trinkets" with a separator label between each.

**Files to modify:**
- `scenes/world/Chest.gd` or wherever chest open logic lives — add equipment drop branch
- `autoloads/GameBus.gd` — add `signal equipment_dropped(equip_id: String)`
- `scenes/ui/ShopScene.gd` — add equipment sections

**Finding the chest open handler:**
```bash
grep -rn "chest_opened\|add_card\|chest" scenes/ autoloads/ --include="*.gd" | grep -v ".uid"
```

## Plan

1. Add `signal equipment_dropped(equip_id: String)` to GameBus.gd.
2. Replace `_maybe_drop_weapon_from_chest` in WorldScene.gd with `_maybe_drop_equipment_from_chest` that pools all 4 equipment slots (weapons excluding rusty_dagger, plus unowned armor/ring/trinket).
3. Add Armor, Rings, Trinkets sections to ShopScene._refresh() via `_add_equipment_section()` helper.
4. Add `_make_equipment_row()` and `_on_buy_equipment()` to ShopScene.

## Changes Made

- `autoloads/GameBus.gd`: added `signal equipment_dropped(equip_id: String)`
- `scenes/world/WorldScene.gd`: renamed `_maybe_drop_weapon_from_chest` → `_maybe_drop_equipment_from_chest`; new impl builds candidate pool from all 4 slots (weapons filtered to non-starter, unowned armor/ring/trinket); calls `sm.add_weapon()` for weapons and `sm.add_equipment(id, slot)` for others; emits `GameBus.equipment_dropped` after drop
- `scenes/ui/ShopScene.gd`: `_refresh()` now appends Armor, Rings, Trinkets sections via `_add_equipment_section(slot, owned, coins)`; added `_add_equipment_section()`, `_make_equipment_row()`, `_on_buy_equipment(item_id, slot, price)` — buy calls `sm.add_equipment(item_id, slot)` and deducts coins

## Documentation Updates

No new agent docs needed; existing equipment system doc in `docs/agent/inventory-and-deck.md` covers the acquisition pattern.
