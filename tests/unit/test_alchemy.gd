## Unit tests for the Alchemy profession (GID-182 / TID-764): potion effects (pure),
## recipe validity, garden plants as the alternative input set, and the new herbs.
extends "res://tests/framework/test_case.gd"

const GardenDefs = preload("res://game_logic/GardenDefs.gd")
const GatherDefs = preload("res://game_logic/professions/GatherDefs.gd")
const HeroState = preload("res://game_logic/battle/HeroState.gd")
const PotionEffects = preload("res://game_logic/battle/PotionEffects.gd")
const ProfessionDefs = preload("res://game_logic/professions/ProfessionDefs.gd")
const SaveManagerScript = preload("res://autoloads/SaveManager.gd")
const StatusEffects = preload("res://game_logic/battle/StatusEffects.gd")

const NEW_HERBS: Array[String] = ["ironbark", "starsage", "emberwort"]

var _sm: SaveManagerScript
var _hero: HeroState


func get_suite_name() -> String:
	return "Alchemy"


func before_each() -> void:
	_sm = SaveManagerScript.new()
	_sm._loaded = true
	_sm.profession_xp = {}
	_sm.materials = {}
	_sm.plants = {}
	_sm.potions = {}
	_sm.foods = {}
	_sm.essence = 0
	_hero = HeroState.new(0)
	_hero.max_mana = 5
	_hero.mana = 1


func after_each() -> void:
	_sm.free()


# ---- Potion effects (PotionEffects.apply_hero) ----

func test_healing_draught_heals_and_caps_at_max() -> void:
	_hero.health = 10
	assert_true(PotionEffects.apply_hero("healing_draught", _hero))
	assert_eq(_hero.health, 18)
	_hero.health = 28
	PotionEffects.apply_hero("healing_draught", _hero)
	assert_eq(_hero.health, _hero.max_health, "never over max")


func test_ember_tonic_and_mana_draught_add_mana_up_to_max() -> void:
	assert_true(PotionEffects.apply_hero("ember_tonic", _hero))
	assert_eq(_hero.mana, 2)
	assert_true(PotionEffects.apply_hero("mana_draught", _hero))
	assert_eq(_hero.mana, 4)
	PotionEffects.apply_hero("mana_draught", _hero)
	assert_eq(_hero.mana, _hero.max_mana, "capped at max mana")


func test_stoneskin_tonic_grants_armor_that_soaks_damage() -> void:
	assert_true(PotionEffects.apply_hero("stoneskin_tonic", _hero))
	assert_eq(_hero.get_status_value("armor"), PotionEffects.STONESKIN_ARMOR)
	_hero.take_damage(6)
	assert_eq(_hero.health, _hero.max_health - 2, "4 soaked, 2 through")
	assert_false(_hero.has_status("armor"), "spent armor is removed")


func test_stoneskin_tonics_stack() -> void:
	PotionEffects.apply_hero("stoneskin_tonic", _hero)
	PotionEffects.apply_hero("stoneskin_tonic", _hero)
	assert_eq(_hero.get_status_value("armor"), 2 * PotionEffects.STONESKIN_ARMOR)


func test_cleansing_salve_clears_ailments_but_keeps_armor() -> void:
	_hero.apply_status("poison", 3)
	_hero.apply_status("freeze", 1)
	_hero.apply_status("stun", 1)
	_hero.apply_status("armor", 2)
	assert_true(PotionEffects.apply_hero("cleansing_salve", _hero))
	for id: String in StatusEffects.AILMENTS:
		assert_false(_hero.has_status(id), id)
	assert_eq(_hero.get_status_value("armor"), 2)


func test_apply_hero_refuses_ids_it_does_not_own() -> void:
	_hero.health = 5
	assert_false(PotionEffects.apply_hero("clarity_brew", _hero), "draws need the deck")
	assert_false(PotionEffects.apply_hero("pear_pudding", _hero), "legendary has its own gate")
	assert_false(PotionEffects.apply_hero("not_a_potion", _hero))
	assert_eq(_hero.health, 5, "nothing changed")


func test_every_hero_potion_has_a_float_label() -> void:
	for potion_id: String in PotionEffects.FLOATS:
		assert_true(GardenDefs.POTIONS.has(potion_id), potion_id)
		assert_false(str(PotionEffects.FLOATS[potion_id]["text"]).is_empty(), potion_id)


func test_pear_pudding_is_untouched_legendary() -> void:
	assert_true(GardenDefs.is_legendary("pear_pudding"))
	assert_eq(str(GardenDefs.POTIONS["pear_pudding"]["display_name"]), "Perrine's Bottomless Pudding")


# ---- Recipe validity ----

func test_every_alchemy_recipe_output_is_a_known_potion() -> void:
	for id: String in ProfessionDefs.recipes_for(ProfessionDefs.ALCHEMY):
		var out: Dictionary = ProfessionDefs.def(id)["output"]
		assert_true(ProfessionDefs.output_valid(out), id)
		assert_true(GardenDefs.POTIONS.has(str(out["id"])), id)


func test_every_input_set_is_valid_and_non_empty() -> void:
	for id: String in ProfessionDefs.recipes_for(ProfessionDefs.ALCHEMY):
		for input_set: Dictionary in ProfessionDefs.input_sets(ProfessionDefs.def(id)):
			assert_false(input_set.is_empty(), id + " has an input set")
			for inp: String in input_set:
				assert_true(ProfessionDefs.is_input(inp), id + " input " + inp)
				assert_gt(int(input_set[inp]), 0, id + " count")


func test_new_herbs_are_materials_from_the_herb_source() -> void:
	for id: String in NEW_HERBS:
		assert_true(ProfessionDefs.MATERIALS.has(id), id)
		assert_eq(str(ProfessionDefs.MATERIALS[id]["source"]), "herb", id)


func test_new_herbs_are_gatherable_in_some_biome() -> void:
	for id: String in NEW_HERBS:
		var found: bool = false
		for biome: Dictionary in GatherDefs.YIELDS:
			if biome.has(GatherDefs.HERB) and (biome[GatherDefs.HERB] as Array).has(id):
				found = true
		assert_true(found, id + " is in some herb yield")


func test_recipes_using_finds_plants_and_herbs_in_both_sets() -> void:
	assert_true(ProfessionDefs.recipes_using("sunpetal_plant").has("brew_healing_draught"))
	assert_true(ProfessionDefs.recipes_using("silverleaf").has("brew_healing_draught"))
	assert_true(ProfessionDefs.recipes_using("emberwort").has("brew_mana_draught"))
	assert_true(ProfessionDefs.recipes_using("not_an_input").is_empty())


# ---- Crafting with alternative input sets (SaveProfessions) ----

func test_primary_set_is_used_when_owned() -> void:
	_sm.professions.add_material("silverleaf", 2)
	_sm.garden.add_plants("sunpetal_plant", 2)
	assert_eq(_sm.professions.inputs_for("brew_healing_draught"), {"silverleaf": 2})
	assert_true(bool(_sm.professions.craft("brew_healing_draught")["ok"]))
	assert_eq(_sm.professions.count("silverleaf"), 0)
	assert_eq(_sm.professions.count("sunpetal_plant"), 2, "garden plants untouched")


func test_garden_plants_stand_in_for_the_herb() -> void:
	_sm.garden.add_plants("sunpetal_plant", 2)
	assert_eq(_sm.professions.craft_block("brew_healing_draught"), "")
	var res: Dictionary = _sm.professions.craft("brew_healing_draught")
	assert_true(bool(res["ok"]))
	assert_eq(_sm.professions.count("sunpetal_plant"), 0, "plants consumed")
	assert_eq(int(_sm.potions.get("healing_draught", 0)), 1)
	assert_gt(int(res["xp"]), 0)


func test_crafting_spends_no_essence() -> void:
	_sm.essence = 7
	_sm.professions.add_material("silverleaf", 2)
	assert_true(bool(_sm.professions.craft("brew_healing_draught")["ok"]))
	assert_eq(_sm.essence, 7)


func test_mixed_stock_still_blocks_when_neither_set_is_whole() -> void:
	_sm.professions.add_material("silverleaf", 1)
	_sm.garden.add_plants("sunpetal_plant", 1)
	assert_eq(_sm.professions.craft_block("brew_healing_draught"), "inputs")
	assert_false(bool(_sm.professions.craft("brew_healing_draught")["ok"]))
	assert_eq(_sm.professions.count("silverleaf"), 1, "nothing consumed on refusal")
	assert_eq(_sm.professions.count("sunpetal_plant"), 1)


func test_new_potion_crafts_into_the_potion_stock() -> void:
	_sm.profession_xp[ProfessionDefs.ALCHEMY] = ProfessionDefs.xp_for_level(4)
	_sm.professions.add_material("ironbark", 2)
	var res: Dictionary = _sm.professions.craft("brew_stoneskin_tonic")
	assert_true(bool(res["ok"]))
	assert_eq(int(_sm.potions.get("stoneskin_tonic", 0)), 1)
	assert_eq(str(res["id"]), "stoneskin_tonic")


func test_mana_draught_needs_skill_nine() -> void:
	_sm.professions.add_material("emberwort", 1)
	_sm.professions.add_material("starsage", 1)
	assert_eq(_sm.professions.craft_block("brew_mana_draught"), "skill")
	_sm.profession_xp[ProfessionDefs.ALCHEMY] = ProfessionDefs.xp_for_level(9)
	assert_eq(_sm.professions.craft_block("brew_mana_draught"), "")
