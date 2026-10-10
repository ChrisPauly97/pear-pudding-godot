## Unit tests for cooking recipes and well-fed buffs (GID-182 / TID-763).
extends "res://tests/framework/test_case.gd"

const _SaveMigrations = preload("res://game_logic/save/SaveMigrations.gd")
const ProfessionDefs = preload("res://game_logic/professions/ProfessionDefs.gd")
const HeroVitality = preload("res://game_logic/HeroVitality.gd")
const WellFed = preload("res://game_logic/professions/WellFed.gd")
const SaveManagerScript = preload("res://autoloads/SaveManager.gd")

const COOKED: Array[String] = ["cook_trout_fillet", "cook_herb_stew", "cook_bog_pie"]


func test_cooking_recipes_are_valid_and_craftable() -> void:
	for id: String in COOKED:
		assert_true(ProfessionDefs.RECIPES.has(id), id + " exists")
		var r: Dictionary = ProfessionDefs.def(id)
		assert_eq(str(r["profession"]), ProfessionDefs.COOKING, id + " is cooking")
		assert_true(ProfessionDefs.output_valid(r["output"]), id + " output is a real food")
		assert_eq(str(r["output"]["kind"]), "food", id + " outputs food")
		var inputs: Dictionary = r["inputs"]
		for inp: String in inputs:
			assert_true(ProfessionDefs.is_input(inp), id + " input " + inp + " exists")
	assert_eq(ProfessionDefs.recipes_for(ProfessionDefs.COOKING).size(), 5, "three new plus the two starters")


func test_cooked_foods_are_sold_only_by_crafting() -> void:
	for food: String in ["trout_fillet", "herb_stew", "bog_pie"]:
		assert_true(HeroVitality.FOODS.has(food), food + " is a food")
		assert_eq(int(HeroVitality.FOODS[food]["price"]), 0, food + " is not for sale")
		assert_gt(HeroVitality.meal_rate(food), 0.0, food + " heals over time")
	assert_gt(int(HeroVitality.FOODS["roast_fowl"]["price"]), 0, "merchant food stays on sale")


func test_well_fed_table_matches_foods() -> void:
	for food: String in ProfessionDefs.WELL_FED:
		assert_true(HeroVitality.FOODS.has(food), food + " names a real food")
		var spec: Dictionary = ProfessionDefs.WELL_FED[food]
		assert_eq(str(spec["stat"]), WellFed.STAT_MAX_HP, food + " buffs max HP")
		assert_gt(int(spec["amount"]), 0, food + " amount")
		assert_gt(int(spec["fights"]), 0, food + " fights")


func test_eating_a_cooked_food_sets_the_buff() -> void:
	var buff: Dictionary = WellFed.make("trout_fillet")
	assert_eq(str(buff["food"]), "trout_fillet")
	assert_true(WellFed.active(buff), "the buff is active after eating")
	assert_true(WellFed.make("travel_bread").is_empty(), "a plain food sets no buff")
	assert_true(WellFed.make("nothing").is_empty(), "an unknown food sets no buff")


func test_buff_applies_through_the_pure_function() -> void:
	var buff: Dictionary = WellFed.make("bog_pie")
	assert_eq(WellFed.hp_bonus(buff), 8, "bog pie adds 8 max HP")
	assert_eq(WellFed.hp_bonus({}), 0, "no buff adds nothing")
	assert_eq(WellFed.hp_bonus({"food": "x", "stat": "speed", "amount": 3, "fights": 1}), 0,
			"an unknown stat adds nothing")


func test_buff_expires_after_its_fights() -> void:
	var buff: Dictionary = WellFed.make("trout_fillet")  # two fights
	buff = WellFed.after_fight(buff)
	assert_true(WellFed.active(buff), "one fight left after the first")
	assert_eq(int(buff["fights"]), 1)
	assert_eq(WellFed.describe(buff), "Well fed: +3 max HP, 1 fight left")
	buff = WellFed.after_fight(buff)
	assert_true(buff.is_empty(), "the buff is gone after its last fight")
	assert_false(WellFed.active(buff))
	assert_eq(WellFed.hp_bonus(buff), 0)
	assert_eq(WellFed.describe(buff), "")


func test_migration_adds_well_fed() -> void:
	assert_eq(_SaveMigrations.CURRENT_VERSION, 50)
	var data: Dictionary = {"version": 49}
	_SaveMigrations.apply(data)
	assert_true(data.has("well_fed"), "v50 backfills well_fed")
	assert_true((data["well_fed"] as Dictionary).is_empty(), "no buff by default")
	assert_eq(int(data["version"]), 50)


func test_well_fed_is_a_persisted_field() -> void:
	assert_true(SaveManagerScript.PERSISTED_FIELDS.has("well_fed"), "well_fed is saved")
	var sm: SaveManagerScript = SaveManagerScript.new()
	sm.well_fed = WellFed.make("herb_stew")
	assert_eq(int(sm.well_fed["fights"]), 3)
	sm.free()
