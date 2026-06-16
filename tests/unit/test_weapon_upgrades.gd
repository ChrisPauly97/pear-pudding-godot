## Unit tests for weapon upgrade system (TID-191/GID-052).
## Covers: UpgradeDefs stat scaling, cost curve, can_afford_upgrade,
## save migration v29->v30, upgrade_weapon flow, save/load round-trip.
extends "res://tests/framework/test_case.gd"

const UpgradeDefs = preload("res://game_logic/UpgradeDefs.gd")
const SaveManagerScript = preload("res://autoloads/SaveManager.gd")
const WeaponData = preload("res://data/WeaponData.gd")

var _sm: Node

func _make_weapon(effect_type: String, base_value: int, inject_id: String = "", inject_count: int = 0) -> WeaponData:
	var w: WeaponData = WeaponData.new()
	w.id = "test_weapon"
	w.display_name = "Test Weapon"
	w.slot = "weapon"
	w.battle_effect_type = effect_type
	w.battle_effect_value = base_value
	w.injected_card_id = inject_id
	w.injected_card_count = inject_count
	return w

func before_each() -> void:
	_sm = SaveManagerScript.new()
	_sm._loaded = true
	_sm.coins = 0
	_sm.essence = 0

func after_each() -> void:
	_sm.free()

# ---------------------------------------------------------------------------
# UpgradeDefs.effective_stat
# ---------------------------------------------------------------------------

func test_effective_stat_level0_unchanged() -> void:
	var w: WeaponData = _make_weapon("starting_mana", 2)
	assert_eq(UpgradeDefs.effective_stat(w, 0), 2)

func test_effective_stat_level1_ten_percent() -> void:
	var w: WeaponData = _make_weapon("starting_mana", 10)
	assert_eq(UpgradeDefs.effective_stat(w, 1), 11)

func test_effective_stat_level5_fifty_percent() -> void:
	var w: WeaponData = _make_weapon("starting_hp", 10)
	assert_eq(UpgradeDefs.effective_stat(w, 5), 15)

func test_effective_stat_passive_atk_level3() -> void:
	var w: WeaponData = _make_weapon("passive_atk", 4)
	assert_eq(UpgradeDefs.effective_stat(w, 3), 5)  # 4 * 1.3 = 5.2 -> int = 5

func test_effective_stat_null_weapon_returns_zero() -> void:
	assert_eq(UpgradeDefs.effective_stat(null, 3), 0)

# ---------------------------------------------------------------------------
# UpgradeDefs.effective_inject_count
# ---------------------------------------------------------------------------

func test_inject_count_level0_unchanged() -> void:
	var w: WeaponData = _make_weapon("deck_inject", 0, "ghost", 2)
	assert_eq(UpgradeDefs.effective_inject_count(w, 0), 2)

func test_inject_count_level3_adds_level() -> void:
	var w: WeaponData = _make_weapon("deck_inject", 0, "ghost", 2)
	assert_eq(UpgradeDefs.effective_inject_count(w, 3), 5)

func test_inject_count_null_weapon_returns_zero() -> void:
	assert_eq(UpgradeDefs.effective_inject_count(null, 2), 0)

# ---------------------------------------------------------------------------
# UpgradeDefs cost curve — no out-of-bounds
# ---------------------------------------------------------------------------

func test_cost_arrays_have_five_entries() -> void:
	assert_eq(UpgradeDefs.UPGRADE_COST_COINS.size(), 5)
	assert_eq(UpgradeDefs.UPGRADE_COST_ESSENCE.size(), 5)

func test_cost_coins_level0_to_4_valid() -> void:
	for i: int in range(5):
		assert_true(UpgradeDefs.cost_coins(i) > 0)

func test_cost_coins_out_of_bounds_returns_zero() -> void:
	assert_eq(UpgradeDefs.cost_coins(5), 0)
	assert_eq(UpgradeDefs.cost_coins(-1), 0)

func test_cost_essence_out_of_bounds_returns_zero() -> void:
	assert_eq(UpgradeDefs.cost_essence(5), 0)

# ---------------------------------------------------------------------------
# UpgradeDefs.can_afford_upgrade
# ---------------------------------------------------------------------------

func test_can_afford_exact_funds() -> void:
	assert_true(UpgradeDefs.can_afford_upgrade(0, 100, 5))

func test_cannot_afford_insufficient_coins() -> void:
	assert_false(UpgradeDefs.can_afford_upgrade(0, 99, 5))

func test_cannot_afford_insufficient_essence() -> void:
	assert_false(UpgradeDefs.can_afford_upgrade(0, 100, 4))

func test_can_afford_at_max_level_returns_false() -> void:
	assert_false(UpgradeDefs.can_afford_upgrade(5, 9999, 9999))

# ---------------------------------------------------------------------------
# SaveManager migration v29 -> v30
# ---------------------------------------------------------------------------

func test_migration_converts_string_array_to_dict() -> void:
	var data: Dictionary = {
		"version": 29,
		"owned_weapons": ["rusty_dagger", "iron_sword"],
	}
	SaveManagerScript._migrate_v29_to_v30(data)
	assert_eq(data["version"], 30)
	var weapons: Array = data["owned_weapons"]
	assert_eq(weapons.size(), 2)
	assert_eq(str(weapons[0].get("weapon_id", "")), "rusty_dagger")
	assert_eq(int(weapons[0].get("upgrade_level", -1)), 0)
	assert_eq(str(weapons[1].get("weapon_id", "")), "iron_sword")

func test_migration_preserves_existing_dicts() -> void:
	var data: Dictionary = {
		"version": 29,
		"owned_weapons": [{"weapon_id": "rusty_dagger", "upgrade_level": 3}],
	}
	SaveManagerScript._migrate_v29_to_v30(data)
	var weapons: Array = data["owned_weapons"]
	assert_eq(int(weapons[0].get("upgrade_level", 0)), 3)

func test_migration_empty_array_ok() -> void:
	var data: Dictionary = {"version": 29, "owned_weapons": []}
	SaveManagerScript._migrate_v29_to_v30(data)
	assert_eq(int(data["owned_weapons"].size()), 0)

func test_migration_missing_key_ok() -> void:
	var data: Dictionary = {"version": 29}
	SaveManagerScript._migrate_v29_to_v30(data)
	assert_eq(data["version"], 30)

# ---------------------------------------------------------------------------
# SaveManager.upgrade_weapon
# ---------------------------------------------------------------------------

func test_upgrade_weapon_deducts_costs() -> void:
	_sm.owned_weapons.append({"weapon_id": "rusty_dagger", "upgrade_level": 0})
	_sm.coins = 500
	_sm.essence = 50
	_sm.upgrade_weapon("rusty_dagger")
	assert_eq(_sm.coins, 400)   # 500 - 100
	assert_eq(_sm.essence, 45)  # 50 - 5

func test_upgrade_weapon_increments_level() -> void:
	_sm.owned_weapons.append({"weapon_id": "rusty_dagger", "upgrade_level": 2})
	_sm.coins = 500
	_sm.essence = 50
	_sm.upgrade_weapon("rusty_dagger")
	var inst: Dictionary = _sm.get_owned_weapon_by_id("rusty_dagger")
	assert_eq(int(inst.get("upgrade_level", 0)), 3)

func test_upgrade_weapon_returns_true_on_success() -> void:
	_sm.owned_weapons.append({"weapon_id": "rusty_dagger", "upgrade_level": 0})
	_sm.coins = 200
	_sm.essence = 20
	var ok: bool = _sm.upgrade_weapon("rusty_dagger")
	assert_true(ok)

func test_upgrade_weapon_returns_false_insufficient_coins() -> void:
	_sm.owned_weapons.append({"weapon_id": "rusty_dagger", "upgrade_level": 0})
	_sm.coins = 50
	_sm.essence = 100
	var ok: bool = _sm.upgrade_weapon("rusty_dagger")
	assert_false(ok)

func test_upgrade_weapon_returns_false_at_max_level() -> void:
	_sm.owned_weapons.append({"weapon_id": "rusty_dagger", "upgrade_level": 5})
	_sm.coins = 9999
	_sm.essence = 9999
	var ok: bool = _sm.upgrade_weapon("rusty_dagger")
	assert_false(ok)

func test_upgrade_weapon_returns_false_not_found() -> void:
	_sm.coins = 9999
	_sm.essence = 9999
	var ok: bool = _sm.upgrade_weapon("nonexistent")
	assert_false(ok)

# ---------------------------------------------------------------------------
# SaveManager.get_owned_weapon_by_id
# ---------------------------------------------------------------------------

func test_get_owned_weapon_by_id_found() -> void:
	_sm.owned_weapons.append({"weapon_id": "rusty_dagger", "upgrade_level": 2})
	var inst: Dictionary = _sm.get_owned_weapon_by_id("rusty_dagger")
	assert_eq(int(inst.get("upgrade_level", -1)), 2)

func test_get_owned_weapon_by_id_not_found_returns_default() -> void:
	var inst: Dictionary = _sm.get_owned_weapon_by_id("missing_weapon")
	assert_eq(int(inst.get("upgrade_level", -1)), 0)
	assert_eq(str(inst.get("weapon_id", "")), "missing_weapon")

# ---------------------------------------------------------------------------
# SaveManager.get_owned_by_slot("weapon") returns string IDs
# ---------------------------------------------------------------------------

func test_get_owned_by_slot_weapon_returns_ids() -> void:
	_sm.owned_weapons.append({"weapon_id": "rusty_dagger", "upgrade_level": 0})
	_sm.owned_weapons.append({"weapon_id": "iron_sword", "upgrade_level": 1})
	var ids: Array[String] = _sm.get_owned_by_slot("weapon")
	assert_eq(ids.size(), 2)
	assert_true(ids.has("rusty_dagger"))
	assert_true(ids.has("iron_sword"))

# ---------------------------------------------------------------------------
# UpgradeDefs.get_display_string
# ---------------------------------------------------------------------------

func test_display_string_mana_level0() -> void:
	var w: WeaponData = _make_weapon("starting_mana", 2)
	assert_eq(UpgradeDefs.get_display_string(w, 0), "+2 starting mana")

func test_display_string_hp_level5() -> void:
	var w: WeaponData = _make_weapon("starting_hp", 10)
	assert_eq(UpgradeDefs.get_display_string(w, 5), "+15 starting HP")

func test_display_string_inject_level2() -> void:
	var w: WeaponData = _make_weapon("deck_inject", 0, "ghost", 1)
	assert_eq(UpgradeDefs.get_display_string(w, 2), "Inject 3× ghost")
