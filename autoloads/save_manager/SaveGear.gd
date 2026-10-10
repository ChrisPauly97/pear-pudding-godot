## Gear rolls (GID-136 / TID-538): rarity + item level per owned equipment item,
## and granting drops so a duplicate upgrades the roll instead of being wasted.
##
## Owned by SaveManager (`SaveManager.gear`), created in its `_init`. The state
## (`gear_rolls`) stays on SaveManager because PERSISTED_FIELDS walks its
## properties. Rules in game_logic/items/GearRolls.gd.
extends RefCounted

const _SaveManager = preload("res://autoloads/SaveManager.gd")
const _GearRolls = preload("res://game_logic/items/GearRolls.gd")
const _WeaponRegistry = preload("res://autoloads/WeaponRegistry.gd")
const _WeaponData = preload("res://data/WeaponData.gd")

var _save: _SaveManager


func _init(save_manager: _SaveManager) -> void:
	_save = save_manager


## The item's roll (common, item level 1 when never rolled).
func roll_of(item_id: String) -> Dictionary:
	return _GearRolls.normalize(_save.gear_rolls.get(item_id, {}))


## Stat multiplier for `UpgradeDefs.effective_stat(weapon, level, mult)`.
func mult(item_id: String) -> float:
	return _GearRolls.mult(roll_of(item_id))


## Adds `item_id` with `roll`, or keeps the better roll when already owned.
## Returns "new", "upgraded", "kept", or "" for an unknown item.
func grant(item_id: String, roll: Dictionary) -> String:
	var w: _WeaponData = _WeaponRegistry.get_weapon(item_id)
	if w == null:
		return ""
	var r: Dictionary = _GearRolls.normalize(roll)
	var result: String = "kept"
	if not _save.get_owned_by_slot(w.slot).has(item_id):
		if w.slot == "weapon":
			_save.add_weapon(item_id)
		else:
			_save.add_equipment(item_id, w.slot)
		result = "new"
	elif _GearRolls.better(r, roll_of(item_id)):
		result = "upgraded"
	if result != "kept":
		_save.gear_rolls[item_id] = r
		_save._dirty = true
		if result == "upgraded" and _save.get_equipped_by_slot(w.slot) == item_id:
			GameBus.equipment_changed.emit(w.slot, item_id)
	return result


## A fresh drop roll for `item_id` from a source of `tier`. A convert affix (GID-181 / TID-754)
## can only roll on a weapon.
static func roll_for(item_id: String, tier: int, level: int, rng: RandomNumberGenerator) -> Dictionary:
	var w: _WeaponData = _WeaponRegistry.get_weapon(item_id)
	return _GearRolls.roll(tier, level, rng, w != null and w.slot == "weapon")


## HUD line for a granted drop: "Found: Rare Iron Helm (ilvl 5)!" etc. A school affix
## (GID-181 / TID-754) is named after the stats: "... (ilvl 5), +15% Dark damage".
static func drop_message(item_id: String, roll: Dictionary, result: String) -> String:
	var w: _WeaponData = _WeaponRegistry.get_weapon(item_id)
	var item_name: String = w.display_name if w != null else item_id
	var r: Dictionary = _GearRolls.normalize(roll)
	var what: String = "%s %s (ilvl %d)" % [str(r["rarity"]).capitalize(), item_name, int(r["ilvl"])]
	var affix_text: String = _GearRolls.affix_label(r)
	if affix_text != "":
		what += ", " + affix_text
	match result:
		"new":
			return "Found: %s!" % what
		"upgraded":
			return "Upgraded: %s!" % what
	return "Found another %s — yours is better." % item_name
