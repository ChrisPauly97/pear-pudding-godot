## Unit tests for potion recipe data and crafting logic (GID-056 TID-205).
##
## Covers: POTION_RECIPES data integrity, plant consumption, essence spending,
## insufficient-ingredient rejection, insufficient-essence rejection, and
## potion inventory accumulation.
extends "res://tests/framework/test_case.gd"

const GardenDefs        = preload("res://game_logic/GardenDefs.gd")
const SaveManagerScript = preload("res://autoloads/SaveManager.gd")

var _sm: Node

func get_suite_name() -> String:
	return "PotionRecipes"

func before_each() -> void:
	_sm = SaveManagerScript.new()
	_sm._loaded = true
	_sm.garden_plots.assign([{}, {}, {}])
	_sm.seeds = {}
	_sm.plants = {}
	_sm.potions = {}
	_sm.essence = 0

func after_each() -> void:
	_sm.free()

# ---------------------------------------------------------------------------
# POTION_RECIPES data integrity
# ---------------------------------------------------------------------------

func test_potion_recipes_has_healing_draught() -> void:
	assert_true(GardenDefs.POTION_RECIPES.has("healing_draught"))

func test_potion_recipes_has_clarity_brew() -> void:
	assert_true(GardenDefs.POTION_RECIPES.has("clarity_brew"))

func test_potion_recipes_has_ember_tonic() -> void:
	assert_true(GardenDefs.POTION_RECIPES.has("ember_tonic"))

func test_healing_draught_ingredient_is_sunpetal() -> void:
	var recipe: Dictionary = GardenDefs.POTION_RECIPES["healing_draught"]
	assert_true(recipe.has("ingredients"))
	assert_true(recipe["ingredients"].has("sunpetal_plant"))

func test_healing_draught_requires_2_sunpetal() -> void:
	var recipe: Dictionary = GardenDefs.POTION_RECIPES["healing_draught"]
	assert_eq(int(recipe["ingredients"]["sunpetal_plant"]), 2)

func test_clarity_brew_ingredient_is_moonroot() -> void:
	var recipe: Dictionary = GardenDefs.POTION_RECIPES["clarity_brew"]
	assert_true(recipe["ingredients"].has("moonroot_plant"))

func test_clarity_brew_requires_2_moonroot() -> void:
	var recipe: Dictionary = GardenDefs.POTION_RECIPES["clarity_brew"]
	assert_eq(int(recipe["ingredients"]["moonroot_plant"]), 2)

func test_ember_tonic_ingredient_is_embercap() -> void:
	var recipe: Dictionary = GardenDefs.POTION_RECIPES["ember_tonic"]
	assert_true(recipe["ingredients"].has("embercap_plant"))

func test_ember_tonic_requires_2_embercap() -> void:
	var recipe: Dictionary = GardenDefs.POTION_RECIPES["ember_tonic"]
	assert_eq(int(recipe["ingredients"]["embercap_plant"]), 2)

func test_all_recipes_have_essence_cost() -> void:
	for potion_id: String in GardenDefs.POTION_RECIPES:
		assert_true(GardenDefs.POTION_RECIPES[potion_id].has("essence_cost"), "missing essence_cost for %s" % potion_id)

func test_all_recipes_essence_cost_is_5() -> void:
	for potion_id: String in GardenDefs.POTION_RECIPES:
		assert_eq(int(GardenDefs.POTION_RECIPES[potion_id]["essence_cost"]), 5, "wrong essence_cost for %s" % potion_id)

func test_all_recipes_have_display_name() -> void:
	for potion_id: String in GardenDefs.POTION_RECIPES:
		var name_val: String = str(GardenDefs.POTION_RECIPES[potion_id].get("display_name", ""))
		assert_true(name_val.length() > 0, "missing display_name for %s" % potion_id)

# ---------------------------------------------------------------------------
# Plant consumption (SaveManager.remove_plants)
# ---------------------------------------------------------------------------

func test_remove_plants_reduces_count() -> void:
	_sm.add_plants("sunpetal_plant", 3)
	_sm.remove_plants("sunpetal_plant", 2)
	assert_eq(int(_sm.plants.get("sunpetal_plant", 0)), 1)

func test_remove_plants_returns_true_when_sufficient() -> void:
	_sm.add_plants("moonroot_plant", 2)
	assert_true(_sm.remove_plants("moonroot_plant", 2))

func test_remove_plants_returns_false_when_insufficient() -> void:
	_sm.add_plants("embercap_plant", 1)
	assert_false(_sm.remove_plants("embercap_plant", 2))

func test_remove_plants_does_not_deduct_when_insufficient() -> void:
	_sm.add_plants("sunpetal_plant", 1)
	_sm.remove_plants("sunpetal_plant", 2)
	assert_eq(int(_sm.plants.get("sunpetal_plant", 0)), 1)

# ---------------------------------------------------------------------------
# Essence spending (SaveManager.spend_essence)
# ---------------------------------------------------------------------------

func test_spend_essence_deducts_amount() -> void:
	_sm.essence = 10
	_sm.spend_essence(5)
	assert_eq(_sm.essence, 5)

func test_spend_essence_returns_true_when_sufficient() -> void:
	_sm.essence = 5
	assert_true(_sm.spend_essence(5))

func test_spend_essence_returns_false_when_insufficient() -> void:
	_sm.essence = 4
	assert_false(_sm.spend_essence(5))

func test_spend_essence_does_not_deduct_when_insufficient() -> void:
	_sm.essence = 3
	_sm.spend_essence(5)
	assert_eq(_sm.essence, 3)

# ---------------------------------------------------------------------------
# Potion inventory (SaveManager.add_potions / remove_potions)
# ---------------------------------------------------------------------------

func test_add_potions_increments_count() -> void:
	_sm.add_potions("healing_draught", 1)
	assert_eq(int(_sm.potions.get("healing_draught", 0)), 1)

func test_add_potions_accumulates() -> void:
	_sm.add_potions("clarity_brew", 1)
	_sm.add_potions("clarity_brew", 1)
	assert_eq(int(_sm.potions.get("clarity_brew", 0)), 2)

func test_remove_potions_deducts() -> void:
	_sm.add_potions("ember_tonic", 2)
	_sm.remove_potions("ember_tonic", 1)
	assert_eq(int(_sm.potions.get("ember_tonic", 0)), 1)

func test_remove_potions_returns_false_when_insufficient() -> void:
	_sm.add_potions("healing_draught", 1)
	assert_false(_sm.remove_potions("healing_draught", 2))

func test_remove_potions_does_not_deduct_when_insufficient() -> void:
	_sm.add_potions("clarity_brew", 1)
	_sm.remove_potions("clarity_brew", 2)
	assert_eq(int(_sm.potions.get("clarity_brew", 0)), 1)

# ---------------------------------------------------------------------------
# CraftingRegistry.get_potion_recipes roundtrip
# ---------------------------------------------------------------------------

func test_crafting_registry_returns_potion_recipes() -> void:
	const CraftingRegistry = preload("res://autoloads/CraftingRegistry.gd")
	var recipes: Dictionary = CraftingRegistry.get_potion_recipes()
	assert_true(recipes.has("healing_draught"))
	assert_true(recipes.has("clarity_brew"))
	assert_true(recipes.has("ember_tonic"))

func test_crafting_registry_recipe_matches_garden_defs() -> void:
	const CraftingRegistry = preload("res://autoloads/CraftingRegistry.gd")
	var recipes: Dictionary = CraftingRegistry.get_potion_recipes()
	assert_eq(recipes, GardenDefs.POTION_RECIPES)
