## Unit tests for weapon salvage system (TID-193/GID-052).
## Covers: salvage value, equipped-weapon guard, display helper, round-trip.
extends "res://tests/framework/test_case.gd"

const UpgradeDefs = preload("res://game_logic/UpgradeDefs.gd")
const SaveManagerScript = preload("res://autoloads/SaveManager.gd")
const WeaponData = preload("res://data/WeaponData.gd")

var _sm: Node

func _make_weapon(effect_type: String, base_value: int) -> WeaponData:
	var w: WeaponData = WeaponData.new()
	w.id = "test_weapon"
	w.display_name = "Test Weapon"
	w.slot = "weapon"
	w.battle_effect_type = effect_type
	w.battle_effect_value = base_value
	return w

func before_each() -> void:
	_sm = SaveManagerScript.new()
	_sm._loaded = true
	_sm.coins = 0
	_sm.essence = 0
	_sm.equipped_weapon = ""
	_sm.equipped_armor = ""
	_sm.equipped_ring = ""
	_sm.equipped_trinket = ""

func after_each() -> void:
	_sm.free()

# ---------------------------------------------------------------------------
# salvage_weapon — basic flow
# ---------------------------------------------------------------------------

func test_salvage_removes_weapon_from_owned() -> void:
	_sm.owned_weapons.append({"weapon_id": "rusty_dagger", "upgrade_level": 0})
	_sm.salvage_weapon("rusty_dagger")
	assert_eq(_sm.owned_weapons.size(), 0)

func test_salvage_returns_coins_and_essence() -> void:
	_sm.owned_weapons.append({"weapon_id": "rusty_dagger", "upgrade_level": 0})
	var result: Dictionary = _sm.salvage_weapon("rusty_dagger")
	assert_eq(int(result.get("coins", -1)), UpgradeDefs.SALVAGE_COINS)
	assert_eq(int(result.get("essence", -1)), UpgradeDefs.SALVAGE_ESSENCE)

func test_salvage_adds_coins_to_save() -> void:
	_sm.owned_weapons.append({"weapon_id": "rusty_dagger", "upgrade_level": 0})
	_sm.salvage_weapon("rusty_dagger")
	assert_eq(_sm.coins, UpgradeDefs.SALVAGE_COINS)

func test_salvage_adds_essence_to_save() -> void:
	_sm.owned_weapons.append({"weapon_id": "rusty_dagger", "upgrade_level": 0})
	_sm.salvage_weapon("rusty_dagger")
	assert_eq(_sm.essence, UpgradeDefs.SALVAGE_ESSENCE)

func test_salvage_not_found_returns_empty() -> void:
	var result: Dictionary = _sm.salvage_weapon("nonexistent")
	assert_true(result.is_empty())

func test_salvage_not_found_no_coins_added() -> void:
	_sm.salvage_weapon("nonexistent")
	assert_eq(_sm.coins, 0)

# ---------------------------------------------------------------------------
# equipped-weapon guard
# ---------------------------------------------------------------------------

func test_salvage_equipped_weapon_refused() -> void:
	_sm.owned_weapons.append({"weapon_id": "rusty_dagger", "upgrade_level": 0})
	_sm.equipped_weapon = "rusty_dagger"
	var result: Dictionary = _sm.salvage_weapon("rusty_dagger")
	assert_true(result.is_empty())

func test_salvage_equipped_weapon_still_in_owned() -> void:
	_sm.owned_weapons.append({"weapon_id": "rusty_dagger", "upgrade_level": 0})
	_sm.equipped_weapon = "rusty_dagger"
	_sm.salvage_weapon("rusty_dagger")
	assert_eq(_sm.owned_weapons.size(), 1)

func test_salvage_unequipped_weapon_succeeds() -> void:
	_sm.owned_weapons.append({"weapon_id": "rusty_dagger", "upgrade_level": 0})
	_sm.equipped_weapon = "iron_sword"  # different weapon equipped
	var result: Dictionary = _sm.salvage_weapon("rusty_dagger")
	assert_false(result.is_empty())

func test_salvage_checks_armor_slot() -> void:
	_sm.owned_weapons.append({"weapon_id": "leather_vest", "upgrade_level": 0})
	_sm.equipped_armor = "leather_vest"
	var result: Dictionary = _sm.salvage_weapon("leather_vest")
	assert_true(result.is_empty())

# ---------------------------------------------------------------------------
# UpgradeDefs.get_display_string — all effect types
# ---------------------------------------------------------------------------

func test_display_string_passive_atk() -> void:
	var w: WeaponData = _make_weapon("passive_atk", 3)
	assert_eq(UpgradeDefs.get_display_string(w, 0), "+3 hero ATK")

func test_display_string_starting_mana_upgraded() -> void:
	var w: WeaponData = _make_weapon("starting_mana", 2)
	var s: String = UpgradeDefs.get_display_string(w, 2)
	assert_true(s.contains("mana"))

func test_display_string_starting_hp_upgraded() -> void:
	var w: WeaponData = _make_weapon("starting_hp", 5)
	var s: String = UpgradeDefs.get_display_string(w, 1)
	assert_eq(s, "+5 starting HP")  # 5 * 1.1 = 5.5 -> int 5

func test_display_string_null_returns_empty() -> void:
	assert_eq(UpgradeDefs.get_display_string(null, 0), "")

# ---------------------------------------------------------------------------
# Round-trip: add_weapon / upgrade / salvage
# ---------------------------------------------------------------------------

func test_add_weapon_creates_level0_instance() -> void:
	_sm.add_weapon("rusty_dagger")
	assert_eq(_sm.owned_weapons.size(), 1)
	assert_eq(int(_sm.owned_weapons[0].get("upgrade_level", -1)), 0)

func test_add_weapon_deduplicates() -> void:
	_sm.add_weapon("rusty_dagger")
	_sm.add_weapon("rusty_dagger")
	assert_eq(_sm.owned_weapons.size(), 1)

func test_upgrade_then_salvage_removes_upgraded_weapon() -> void:
	_sm.owned_weapons.append({"weapon_id": "rusty_dagger", "upgrade_level": 2})
	_sm.coins = 9999
	_sm.essence = 9999
	_sm.salvage_weapon("rusty_dagger")
	assert_eq(_sm.owned_weapons.size(), 0)
