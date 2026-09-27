# gdlint: disable=max-public-methods
# Test suite: every test_* case is a public method, so max-public-methods doesn't apply.
## Unit tests for the off-hand equipment slot (GID-135 / TID-545).
## Covers: SaveManager slot CRUD, WeaponRegistry data, UpgradeDefs display/turn-based
## bonus, and BattleRealtime's pure off-hand-damage lookup.
extends "res://tests/framework/test_case.gd"

const SaveManagerScript = preload("res://autoloads/SaveManager.gd")
const WeaponData = preload("res://data/WeaponData.gd")
const WeaponRegistry = preload("res://autoloads/WeaponRegistry.gd")
const UpgradeDefs = preload("res://game_logic/UpgradeDefs.gd")
const _BattleRealtime = preload("res://scenes/battle/modules/BattleRealtime.gd")

var _sm: SaveManagerScript

func before_each() -> void:
	_sm = SaveManagerScript.new()
	_sm._loaded = true
	_sm.equipped_weapon = ""
	_sm.equipped_armor = ""
	_sm.equipped_ring = ""
	_sm.equipped_trinket = ""
	_sm.equipped_offhand = ""

func after_each() -> void:
	_sm.free()

# ---------------------------------------------------------------------------
# SaveManager: offhand slot CRUD
# ---------------------------------------------------------------------------

func test_add_equipment_offhand_adds_to_owned() -> void:
	_sm.add_equipment("parrying_dagger", "offhand")
	assert_true(_sm.owned_offhands.has("parrying_dagger"))

func test_add_equipment_offhand_deduplicates() -> void:
	_sm.add_equipment("parrying_dagger", "offhand")
	_sm.add_equipment("parrying_dagger", "offhand")
	assert_eq(_sm.owned_offhands.size(), 1)

func test_equip_item_offhand_sets_equipped_field() -> void:
	_sm.equip_item("buckler", "offhand")
	assert_eq(_sm.equipped_offhand, "buckler")

func test_equip_item_offhand_empty_string_unequips() -> void:
	_sm.equipped_offhand = "buckler"
	_sm.equip_item("", "offhand")
	assert_eq(_sm.equipped_offhand, "")

func test_get_owned_by_slot_offhand() -> void:
	_sm.owned_offhands.append("arcane_focus")
	var ids: Array[String] = _sm.get_owned_by_slot("offhand")
	assert_true(ids.has("arcane_focus"))

func test_get_equipped_by_slot_offhand() -> void:
	_sm.equipped_offhand = "arcane_focus"
	assert_eq(_sm.get_equipped_by_slot("offhand"), "arcane_focus")

func test_new_game_resets_offhand_slot() -> void:
	_sm.equipped_offhand = "buckler"
	_sm.owned_offhands.append("buckler")
	_sm.new_game()
	assert_eq(_sm.equipped_offhand, "")
	assert_eq(_sm.owned_offhands.size(), 0)

# ---------------------------------------------------------------------------
# WeaponRegistry: built-in off-hand items
# ---------------------------------------------------------------------------

func test_parrying_dagger_is_offhand_atk() -> void:
	var w: WeaponData = WeaponRegistry.get_weapon("parrying_dagger")
	assert_true(w != null)
	assert_eq(w.slot, "offhand")
	assert_eq(w.battle_effect_type, "offhand_atk")
	assert_true(w.battle_effect_value > 0)

func test_buckler_is_starting_armor() -> void:
	var w: WeaponData = WeaponRegistry.get_weapon("buckler")
	assert_true(w != null)
	assert_eq(w.slot, "offhand")
	assert_eq(w.battle_effect_type, "starting_armor")

func test_arcane_focus_is_starting_mana() -> void:
	var w: WeaponData = WeaponRegistry.get_weapon("arcane_focus")
	assert_true(w != null)
	assert_eq(w.slot, "offhand")
	assert_eq(w.battle_effect_type, "starting_mana")

func test_get_by_slot_offhand_lists_all_three() -> void:
	var ids: Array[String] = WeaponRegistry.get_by_slot("offhand")
	assert_true(ids.has("parrying_dagger"))
	assert_true(ids.has("buckler"))
	assert_true(ids.has("arcane_focus"))

# ---------------------------------------------------------------------------
# UpgradeDefs: turn-based equivalent + display strings
# ---------------------------------------------------------------------------

func test_offhand_turnbased_bonus_halves_value() -> void:
	assert_eq(UpgradeDefs.offhand_turnbased_bonus(4), 2)

func test_offhand_turnbased_bonus_minimum_one() -> void:
	assert_eq(UpgradeDefs.offhand_turnbased_bonus(1), 1)

func test_display_string_starting_armor() -> void:
	var w: WeaponData = WeaponData.new()
	w.battle_effect_type = "starting_armor"
	w.battle_effect_value = 5
	assert_eq(UpgradeDefs.get_display_string(w, 0), "+5 starting armor")

func test_display_string_offhand_atk_mentions_both_modes() -> void:
	var w: WeaponData = WeaponData.new()
	w.battle_effect_type = "offhand_atk"
	w.battle_effect_value = 4
	var s: String = UpgradeDefs.get_display_string(w, 0)
	assert_true(s.contains("4"))
	assert_true(s.contains("2"))  # turn-based equivalent

# ---------------------------------------------------------------------------
# BattleRealtime.offhand_damage_for_item (pure lookup)
# ---------------------------------------------------------------------------

func test_offhand_damage_for_item_empty_id_is_zero() -> void:
	assert_eq(_BattleRealtime.offhand_damage_for_item(""), 0)

func test_offhand_damage_for_item_unknown_id_is_zero() -> void:
	assert_eq(_BattleRealtime.offhand_damage_for_item("nonexistent_item"), 0)

func test_offhand_damage_for_item_parrying_dagger_matches_weapon_value() -> void:
	var w: WeaponData = WeaponRegistry.get_weapon("parrying_dagger")
	assert_eq(_BattleRealtime.offhand_damage_for_item("parrying_dagger"), w.battle_effect_value)

func test_offhand_damage_for_item_non_attack_offhand_is_zero() -> void:
	# Buckler is starting_armor, not offhand_atk — no real-time swing.
	assert_eq(_BattleRealtime.offhand_damage_for_item("buckler"), 0)
