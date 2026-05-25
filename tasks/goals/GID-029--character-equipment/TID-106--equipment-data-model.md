# TID-106: Equipment Data Model

**Goal:** GID-029
**Type:** agent
**Status:** done
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

1. Add `slot: String = "weapon"` to `data/WeaponData.gd` — existing `.tres` files omit the field and receive the default, staying backwards-compatible.
2. Add `get_by_slot()` to `WeaponRegistry.gd`.
3. Extend `SaveManager.gd`: 6 new fields, `new_game()` init, `load_save()` read, `save()` write, `_migrate_v10_to_v11()`, `_apply_migrations()` entry, `add_equipment()`, `equip_item()`, `get_owned_by_slot()`, `get_equipped_by_slot()` helpers. Bump `CURRENT_SAVE_VERSION` to 11.
4. Rename `BattleScene._apply_weapon_effect()` → `_apply_equipment_effects()`, generalising it to loop over all 4 slot IDs.

## Changes Made

- `data/WeaponData.gd`: added `@export var slot: String = "weapon"` — all 7 existing weapon `.tres` files are unaffected (they omit the field; Godot uses the default).
- `autoloads/WeaponRegistry.gd`: added `get_by_slot(slot) -> Array[String]`.
- `autoloads/SaveManager.gd`:
  - `CURRENT_SAVE_VERSION` bumped 10 → 11.
  - 6 new vars: `equipped_armor`, `equipped_ring`, `equipped_trinket`, `owned_armor`, `owned_rings`, `owned_trinkets`.
  - `new_game()`, `load_save()`, `save()` all updated for the new fields.
  - `_migrate_v10_to_v11()` added; registered in `_apply_migrations()`.
  - New public API: `add_equipment(id, slot)`, `equip_item(id, slot)`, `get_owned_by_slot(slot)`, `get_equipped_by_slot(slot)`.
- `scenes/battle/BattleScene.gd`: `_apply_weapon_effect()` renamed to `_apply_equipment_effects()`; now loops over all 4 equipped slot IDs. Deck shuffle deferred until after all slots are processed (single shuffle at end). Call site updated.

## Documentation Updates

Updated `docs/agent/inventory-and-deck.md` — Weapon System section extended to document the new `slot` field, the four equipment slot fields in SaveManager, the generalised `_apply_equipment_effects()` in BattleScene, and the new helper API.
