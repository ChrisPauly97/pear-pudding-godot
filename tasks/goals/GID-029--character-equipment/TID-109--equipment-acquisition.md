# TID-109: Equipment Acquisition

**Goal:** GID-029
**Type:** agent
**Status:** pending
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

_Written during Plan phase._

## Changes Made

_Filled after Build phase._

## Documentation Updates

_What was updated in agent docs._
