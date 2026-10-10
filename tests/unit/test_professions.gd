# gdlint: disable=max-public-methods
# Test suite: every test_* case is a public method, so max-public-methods doesn't apply.
## Unit tests for ProfessionDefs and SaveManager.professions (GID-182 / TID-759).
extends "res://tests/framework/test_case.gd"

const _SaveMigrations = preload("res://game_logic/save/SaveMigrations.gd")
const ProfessionDefs = preload("res://game_logic/professions/ProfessionDefs.gd")
const SaveManagerScript = preload("res://autoloads/SaveManager.gd")

var _sm: SaveManagerScript


func before_each() -> void:
	_sm = SaveManagerScript.new()
	_sm._loaded = true
	_sm.profession_xp = {}
	_sm.materials = {}
	_sm.plants = {}
	_sm.potions = {}
	_sm.foods = {}


func after_each() -> void:
	_sm.free()


# ---- Tables ----

func test_every_recipe_is_well_formed() -> void:
	for id: String in ProfessionDefs.RECIPES:
		var r: Dictionary = ProfessionDefs.RECIPES[id]
		assert_true(ProfessionDefs.PROFESSIONS.has(str(r["profession"])), id + " profession")
		var req: int = int(r["skill_req"])
		assert_true(req >= 1 and req <= ProfessionDefs.MAX_LEVEL, id + " skill_req")
		assert_gt(int(r["xp"]), 0, id + " xp")
		var inputs: Dictionary = r["inputs"]
		assert_false(inputs.is_empty(), id + " has inputs")
		for inp: String in inputs:
			assert_true(ProfessionDefs.is_input(inp), id + " input " + inp)
			assert_gt(int(inputs[inp]), 0, id + " input count")
		assert_true(ProfessionDefs.output_valid(r["output"]), id + " output")


func test_every_material_has_a_known_source() -> void:
	for id: String in ProfessionDefs.MATERIALS:
		var m: Dictionary = ProfessionDefs.MATERIALS[id]
		assert_true(ProfessionDefs.SOURCES.has(str(m["source"])), id)


func test_every_profession_has_a_recipe_or_is_crafting() -> void:
	for p: String in ProfessionDefs.PROFESSIONS:
		if p == ProfessionDefs.CRAFTING:
			continue  # gear recipes arrive with TID-765
		assert_false(ProfessionDefs.recipes_for(p).is_empty(), p)


# ---- XP curve ----

func test_xp_curve_is_monotonic_and_round_trips() -> void:
	assert_eq(ProfessionDefs.xp_for_level(1), 0)
	assert_eq(ProfessionDefs.xp_for_level(2), ProfessionDefs.XP_BASE)
	for lv: int in range(1, ProfessionDefs.MAX_LEVEL):
		assert_lt(ProfessionDefs.xp_for_level(lv), ProfessionDefs.xp_for_level(lv + 1))
		assert_eq(ProfessionDefs.level_for_xp(ProfessionDefs.xp_for_level(lv)), lv)
		assert_eq(ProfessionDefs.level_for_xp(ProfessionDefs.xp_for_level(lv + 1) - 1), lv)


func test_level_caps_at_max() -> void:
	assert_eq(ProfessionDefs.level_for_xp(10000000), ProfessionDefs.MAX_LEVEL)


func test_recipe_xp_falls_off_with_level() -> void:
	var id: String = "brew_healing_draught"  # skill_req 1
	var base: int = int(ProfessionDefs.def(id)["xp"])
	assert_eq(ProfessionDefs.band(id, 1), "orange")
	assert_eq(ProfessionDefs.recipe_xp(id, 1), base)
	assert_eq(ProfessionDefs.recipe_xp(id, 1 + ProfessionDefs.BAND_GREEN), base / 2)
	assert_eq(ProfessionDefs.recipe_xp(id, 1 + ProfessionDefs.BAND_GREY), 0)
	assert_eq(ProfessionDefs.band("brew_clarity_brew", 1), "locked")


# ---- SaveManager.professions ----

func test_craft_consumes_inputs_and_grants_output_and_xp() -> void:
	_sm.professions.add_material("silverleaf", 3)
	var res: Dictionary = _sm.professions.craft("brew_healing_draught")
	assert_true(bool(res["ok"]))
	assert_eq(_sm.professions.count("silverleaf"), 1)
	assert_eq(int(_sm.potions.get("healing_draught", 0)), 1)
	assert_eq(_sm.professions.xp(ProfessionDefs.ALCHEMY), int(res["xp"]))
	assert_gt(int(res["xp"]), 0)


func test_craft_food_goes_to_foods() -> void:
	_sm.professions.add_material("wild_grain", 3)
	assert_true(bool(_sm.professions.craft("cook_travel_bread")["ok"]))
	assert_eq(int(_sm.foods.get("travel_bread", 0)), 2)
	assert_false(_sm.materials.has("wild_grain"), "spent stack removed")


func test_craft_refuses_without_inputs_or_skill() -> void:
	assert_eq(_sm.professions.craft_block("brew_healing_draught"), "inputs")
	_sm.professions.add_material("duskbloom", 2)
	assert_eq(_sm.professions.craft_block("brew_clarity_brew"), "skill")
	assert_false(bool(_sm.professions.craft("brew_clarity_brew")["ok"]))
	assert_eq(_sm.professions.count("duskbloom"), 2, "nothing consumed on refusal")
	assert_eq(_sm.professions.craft_block("nope"), "unknown")


func test_craft_reports_level_up() -> void:
	_sm.profession_xp[ProfessionDefs.ALCHEMY] = ProfessionDefs.XP_BASE - 1
	_sm.professions.add_material("silverleaf", 2)
	var res: Dictionary = _sm.professions.craft("brew_healing_draught")
	assert_eq(int(res["level"]), 2)
	assert_eq(_sm.professions.level(ProfessionDefs.ALCHEMY), 2)


func test_unknown_material_is_ignored() -> void:
	_sm.professions.add_material("not_a_thing", 5)
	assert_true(_sm.materials.is_empty())


func test_migration_backfills_profession_fields() -> void:
	var data: Dictionary = {"version": 48}
	_SaveMigrations.apply(data)
	assert_true(data.has("profession_xp"))
	assert_true(data.has("materials"))
	assert_eq(int(data["version"]), _SaveMigrations.CURRENT_VERSION)
