# TID-106: Equipment Data Model

**Goal:** GID-029
**Type:** agent
**Status:** pending
**Depends On:** —

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

The weapon system uses `WeaponData.gd` (slot-agnostic: id, display_name, description, battle_effect_type, battle_effect_value, injected_card_id, injected_card_count). Currently there is one save field (`equipped_weapon: String`) and `BattleScene._apply_weapon_effect()` reads only that slot. This task generalises the model to support four equipment slots: weapon, armor, ring, trinket.

## Research Notes

**Files to modify:**
- `data/WeaponData.gd` — add `@export var slot: String = "weapon"`. No other changes. The 7 existing `.tres` files omit this field, so Godot will use the default `"weapon"`, keeping them working.
- `autoloads/SaveManager.gd` — add 6 new fields:
  - `equipped_armor: String = ""`
  - `equipped_ring: String = ""`
  - `equipped_trinket: String = ""`
  - `owned_armor: Array[String] = []`
  - `owned_rings: Array[String] = []`
  - `owned_trinkets: Array[String] = []`
  - Increment `CURRENT_SAVE_VERSION` to 11.
  - Add `_migrate_v10_to_v11()` backfilling empty strings/arrays.
  - Add corresponding `new_game()` initialisations and `_load()`/`_to_dict()` entries.
  - Add helpers: `add_equipment(id, slot)` (routes to correct owned array), `equip_item(id, slot)` (sets correct equipped field).
- `scenes/battle/BattleScene.gd` — rename `_apply_weapon_effect()` to `_apply_equipment_effects()` and loop over all 4 slots, calling the same match block for each.
- `autoloads/WeaponRegistry.gd` — add `get_by_slot(slot: String) -> Array[String]` convenience method that filters `_weapons` by `slot` field.

**Existing pattern:**
```gdscript
# SaveManager existing migration pattern (add after _migrate_v9_to_v10):
static func _migrate_v10_to_v11(data: Dictionary) -> void:
    if not data.has("equipped_armor"):  data["equipped_armor"] = ""
    if not data.has("equipped_ring"):   data["equipped_ring"] = ""
    if not data.has("equipped_trinket"): data["equipped_trinket"] = ""
    if not data.has("owned_armor"):     data["owned_armor"] = []
    if not data.has("owned_rings"):     data["owned_rings"] = []
    if not data.has("owned_trinkets"):  data["owned_trinkets"] = []
    data["version"] = 11
```

**BattleScene pattern:**
```gdscript
func _apply_equipment_effects(player: PlayerState) -> void:
    var slots := [
        SceneManager.save_manager.equipped_weapon,
        SceneManager.save_manager.equipped_armor,
        SceneManager.save_manager.equipped_ring,
        SceneManager.save_manager.equipped_trinket,
    ]
    for item_id in slots:
        if item_id == "":
            continue
        var weapon: WeaponData = WeaponRegistry.get_weapon(item_id)
        if weapon == null:
            continue
        # ... same match block as before
```

**GDScript strict-mode note:** `slots` should be typed `Array[String]` to avoid Variant inference errors.

## Plan

_Written during Plan phase._

## Changes Made

_Filled after Build phase._

## Documentation Updates

_What was updated in agent docs._
