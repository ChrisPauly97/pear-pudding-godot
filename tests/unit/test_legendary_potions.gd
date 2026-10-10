## Unit tests for the legendary potion (GID-153 / TID-656): Perrine's Bottomless Pudding.
extends "res://tests/framework/test_case.gd"

const GardenDefs        = preload("res://game_logic/GardenDefs.gd")
const SaveManagerScript = preload("res://autoloads/SaveManager.gd")
const LegendaryPotions  = preload("res://game_logic/battle/LegendaryPotions.gd")
const QuickSlots        = preload("res://game_logic/battle/QuickSlots.gd")
const ProfessionDefs    = preload("res://game_logic/professions/ProfessionDefs.gd")
const HeroState         = preload("res://game_logic/battle/HeroState.gd")

const PUDDING: String = LegendaryPotions.PEAR_PUDDING

var _sm: SaveManagerScript

func get_suite_name() -> String:
	return "LegendaryPotions"

func before_each() -> void:
	_sm = SaveManagerScript.new()
	_sm._loaded = true
	_sm.potions = {}

func after_each() -> void:
	_sm.free()

func test_pudding_is_a_legendary_potion_without_recipe() -> void:
	assert_true(GardenDefs.POTIONS.has(PUDDING))
	assert_true(GardenDefs.is_legendary(PUDDING))
	assert_false(GardenDefs.is_legendary("healing_draught"))
	for id: String in ProfessionDefs.RECIPES:
		var out: Dictionary = ProfessionDefs.RECIPES[id]["output"]
		assert_ne(str(out["id"]), PUDDING, "never brewable (" + id + ")")

func test_grant_is_once_only() -> void:
	assert_true(_sm.garden.grant_legendary(PUDDING))
	assert_false(_sm.garden.grant_legendary(PUDDING))
	assert_eq(int(_sm.potions[PUDDING]), 1)

func test_quick_slots_keep_it_once_owned() -> void:
	assert_false(QuickSlots.resolve(["", ""], _sm.potions).has(PUDDING), "hidden until owned")
	_sm.garden.grant_legendary(PUDDING)
	assert_true(QuickSlots.resolve(["", ""], _sm.potions).has(PUDDING))

func test_one_sip_per_battle_and_refills() -> void:
	var battle1 := LegendaryPotions.new()
	assert_true(battle1.can_sip(PUDDING))
	battle1.mark_sipped(PUDDING)
	assert_false(battle1.can_sip(PUDDING))
	var battle2 := LegendaryPotions.new()
	assert_true(battle2.can_sip(PUDDING), "a new battle refills the flask")

func test_effect_full_heal_cleanse_mana() -> void:
	var hero := HeroState.new(0)
	hero.health = 3
	hero.apply_status("poison", 2)
	hero.apply_status("stun", 1)
	hero.apply_status("armor", 4)
	var mana_before: int = hero.mana
	LegendaryPotions.apply_pear_pudding(hero)
	assert_eq(hero.health, hero.max_health)
	assert_false(hero.has_status("poison"))
	assert_false(hero.has_status("stun"))
	assert_true(hero.has_status("armor"), "buffs are kept")
	assert_true(hero.mana >= mana_before)

func test_save_round_trip_keeps_it() -> void:
	_sm.garden.grant_legendary(PUDDING)
	var data: Dictionary = JSON.parse_string(JSON.stringify(_sm._collect_save_data()))
	var other := SaveManagerScript.new()
	other._restore_field(data, "potions", SaveManagerScript.PERSISTED_FIELDS["potions"])
	assert_eq(int(other.potions.get(PUDDING, 0)), 1)
	other.free()
