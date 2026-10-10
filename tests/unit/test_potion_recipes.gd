## Unit tests for the potion stock and the alchemy recipes that brew it (GID-056 TID-205,
## moved to ProfessionDefs by GID-182 / TID-764).
##
## Covers: alchemy recipe data (every potion brewable, garden plants accepted as
## the alternative input set, no essence price), plant consumption, essence
## spending (a generic SaveManager helper), potion inventory accumulation.
extends "res://tests/framework/test_case.gd"

const GardenDefs        = preload("res://game_logic/GardenDefs.gd")
const ProfessionDefs    = preload("res://game_logic/professions/ProfessionDefs.gd")
const SaveManagerScript = preload("res://autoloads/SaveManager.gd")

const ALCHEMY_POTIONS: Array[String] = ["healing_draught", "clarity_brew", "ember_tonic",
		"stoneskin_tonic", "cleansing_salve", "mana_draught"]

var _sm: SaveManagerScript

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
# Alchemy recipe data (ProfessionDefs.RECIPES)
# ---------------------------------------------------------------------------

## The alchemy recipe id that brews `potion_id`, or "" when none does.
func _brew_for(potion_id: String) -> String:
	for id: String in ProfessionDefs.RECIPES:
		var out: Dictionary = ProfessionDefs.RECIPES[id]["output"]
		if str(out["id"]) == potion_id:
			return id
	return ""

func test_every_alchemy_potion_has_a_brew_recipe() -> void:
	for potion_id: String in ALCHEMY_POTIONS:
		assert_ne(_brew_for(potion_id), "", "no recipe brews " + potion_id)

func test_healing_draught_takes_silverleaf_or_sunpetal() -> void:
	var sets: Array[Dictionary] = ProfessionDefs.input_sets(ProfessionDefs.def("brew_healing_draught"))
	assert_eq(sets.size(), 2)
	assert_eq(int(sets[0]["silverleaf"]), 2)
	assert_eq(int(sets[1]["sunpetal_plant"]), 2)

func test_clarity_brew_takes_duskbloom_or_moonroot() -> void:
	var sets: Array[Dictionary] = ProfessionDefs.input_sets(ProfessionDefs.def("brew_clarity_brew"))
	assert_eq(int(sets[0]["duskbloom"]), 2)
	assert_eq(int(sets[1]["moonroot_plant"]), 2)

func test_ember_tonic_takes_emberwort_or_embercap() -> void:
	var sets: Array[Dictionary] = ProfessionDefs.input_sets(ProfessionDefs.def("brew_ember_tonic"))
	assert_eq(int(sets[0]["emberwort"]), 2)
	assert_eq(int(sets[1]["embercap_plant"]), 2)

func test_no_alchemy_recipe_has_an_essence_price() -> void:
	for id: String in ProfessionDefs.recipes_for(ProfessionDefs.ALCHEMY):
		assert_false(ProfessionDefs.def(id).has("essence_cost"), id)

func test_potion_definitions_carry_no_essence_price() -> void:
	for potion_id: String in ALCHEMY_POTIONS:
		var info: Dictionary = GardenDefs.POTIONS[potion_id]
		assert_false(info.has("essence_cost"), potion_id)

func test_potion_recipes_outputs_are_potions() -> void:
	for potion_id: String in ALCHEMY_POTIONS:
		var out: Dictionary = ProfessionDefs.def(_brew_for(potion_id))["output"]
		assert_eq(str(out["kind"]), "potion", potion_id)

# ---------------------------------------------------------------------------
# ---------------------------------------------------------------------------
# Plant consumption (SaveManager.remove_plants)
# ---------------------------------------------------------------------------

func test_remove_plants_reduces_count() -> void:
	_sm.garden.add_plants("sunpetal_plant", 3)
	_sm.garden.remove_plants("sunpetal_plant", 2)
	assert_eq(int(_sm.plants.get("sunpetal_plant", 0)), 1)

func test_remove_plants_returns_true_when_sufficient() -> void:
	_sm.garden.add_plants("moonroot_plant", 2)
	assert_true(_sm.garden.remove_plants("moonroot_plant", 2))

func test_remove_plants_returns_false_when_insufficient() -> void:
	_sm.garden.add_plants("embercap_plant", 1)
	assert_false(_sm.garden.remove_plants("embercap_plant", 2))

func test_remove_plants_does_not_deduct_when_insufficient() -> void:
	_sm.garden.add_plants("sunpetal_plant", 1)
	_sm.garden.remove_plants("sunpetal_plant", 2)
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
	_sm.garden.add_potions("healing_draught", 1)
	assert_eq(int(_sm.potions.get("healing_draught", 0)), 1)

func test_add_potions_accumulates() -> void:
	_sm.garden.add_potions("clarity_brew", 1)
	_sm.garden.add_potions("clarity_brew", 1)
	assert_eq(int(_sm.potions.get("clarity_brew", 0)), 2)

func test_remove_potions_deducts() -> void:
	_sm.garden.add_potions("ember_tonic", 2)
	_sm.garden.remove_potions("ember_tonic", 1)
	assert_eq(int(_sm.potions.get("ember_tonic", 0)), 1)

func test_remove_potions_returns_false_when_insufficient() -> void:
	_sm.garden.add_potions("healing_draught", 1)
	assert_false(_sm.garden.remove_potions("healing_draught", 2))

func test_remove_potions_does_not_deduct_when_insufficient() -> void:
	_sm.garden.add_potions("clarity_brew", 1)
	_sm.garden.remove_potions("clarity_brew", 2)
	assert_eq(int(_sm.potions.get("clarity_brew", 0)), 1)
