## Unit tests for potion logic in battle (GID-056 TID-206).
##
## Tests pure logic that doesn't require scene tree: HP cap math, mana cap math,
## one-per-battle flag, inventory decrement, and empty-potions guard.
## PlayerState/HeroState use class_name and can't be instantiated headless; effects
## on those types are covered by the integration behaviour in the scene itself.
extends "res://tests/framework/test_case.gd"

const SaveManagerScript = preload("res://autoloads/SaveManager.gd")

var _sm: Node

func get_suite_name() -> String:
	return "BattlePotions"

func before_each() -> void:
	_sm = SaveManagerScript.new()
	_sm._loaded = true
	_sm.potions = {}

func after_each() -> void:
	_sm.free()

# ---------------------------------------------------------------------------
# Healing Draught — HP cap math
# ---------------------------------------------------------------------------

func test_heal_8_below_max() -> void:
	var health: int = 15
	var max_health: int = 30
	health = mini(health + 8, max_health)
	assert_eq(health, 23)

func test_heal_8_at_max_stays_at_max() -> void:
	var health: int = 30
	var max_health: int = 30
	health = mini(health + 8, max_health)
	assert_eq(health, 30)

func test_heal_8_would_overflow_caps_at_max() -> void:
	var health: int = 27
	var max_health: int = 30
	health = mini(health + 8, max_health)
	assert_eq(health, 30)

func test_heal_8_exactly_fills_to_max() -> void:
	var health: int = 22
	var max_health: int = 30
	health = mini(health + 8, max_health)
	assert_eq(health, 30)

# ---------------------------------------------------------------------------
# Ember Tonic — mana cap math
# ---------------------------------------------------------------------------

func test_ember_tonic_increases_mana_by_1() -> void:
	var mana: int = 3
	var max_mana: int = 10
	mana = mini(mana + 1, max_mana)
	assert_eq(mana, 4)

func test_ember_tonic_at_max_mana_stays_at_max() -> void:
	var mana: int = 10
	var max_mana: int = 10
	mana = mini(mana + 1, max_mana)
	assert_eq(mana, 10)

func test_ember_tonic_does_not_change_max_mana() -> void:
	var mana: int = 5
	var max_mana: int = 10
	mana = mini(mana + 1, max_mana)
	assert_eq(max_mana, 10)

# ---------------------------------------------------------------------------
# Inventory decrement (SaveManager.remove_potions)
# ---------------------------------------------------------------------------

func test_remove_potions_decrements_count() -> void:
	_sm.add_potions("healing_draught", 2)
	_sm.remove_potions("healing_draught", 1)
	assert_eq(int(_sm.potions.get("healing_draught", 0)), 1)

func test_remove_potions_returns_true_when_sufficient() -> void:
	_sm.add_potions("clarity_brew", 1)
	assert_true(_sm.remove_potions("clarity_brew", 1))

func test_remove_potions_returns_false_when_zero() -> void:
	_sm.add_potions("clarity_brew", 0)
	assert_false(_sm.remove_potions("clarity_brew", 1))

func test_remove_potions_returns_false_when_absent() -> void:
	assert_false(_sm.remove_potions("ember_tonic", 1))

func test_remove_potions_does_not_deduct_when_insufficient() -> void:
	_sm.add_potions("ember_tonic", 1)
	_sm.remove_potions("ember_tonic", 2)
	assert_eq(int(_sm.potions.get("ember_tonic", 0)), 1)

# ---------------------------------------------------------------------------
# One-per-battle flag simulation
# ---------------------------------------------------------------------------

func test_one_per_battle_flag_blocks_second_use() -> void:
	var used: bool = false
	_sm.add_potions("healing_draught", 3)
	# First use
	var first: bool = (not used) and _sm.remove_potions("healing_draught", 1)
	if first:
		used = true
	assert_true(first)
	# Second use blocked by flag
	var second: bool = (not used) and _sm.remove_potions("healing_draught", 1)
	assert_false(second)
	# Count only decremented once
	assert_eq(int(_sm.potions.get("healing_draught", 0)), 2)

# ---------------------------------------------------------------------------
# has-potions guard (logic only — mirrors _refresh_potion_button)
# ---------------------------------------------------------------------------

func test_empty_potions_dict_means_no_potions() -> void:
	_sm.potions = {}
	var has_any: bool = false
	for pid: String in _sm.potions:
		if int(_sm.potions[pid]) > 0:
			has_any = true
			break
	assert_false(has_any)

func test_all_zero_counts_means_no_potions() -> void:
	_sm.potions = {"healing_draught": 0, "clarity_brew": 0}
	var has_any: bool = false
	for pid: String in _sm.potions:
		if int(_sm.potions[pid]) > 0:
			has_any = true
			break
	assert_false(has_any)

func test_one_potion_with_count_means_has_potions() -> void:
	_sm.potions = {"ember_tonic": 1}
	var has_any: bool = false
	for pid: String in _sm.potions:
		if int(_sm.potions[pid]) > 0:
			has_any = true
			break
	assert_true(has_any)

func test_mixed_counts_means_has_potions() -> void:
	_sm.potions = {"healing_draught": 0, "clarity_brew": 2}
	var has_any: bool = false
	for pid: String in _sm.potions:
		if int(_sm.potions[pid]) > 0:
			has_any = true
			break
	assert_true(has_any)
