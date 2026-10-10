## Unit tests for crafted gear (GID-182 / TID-765): recipes name real equipment,
## the skill → rarity table caps at epic, and a craft grants the item and roll.
extends "res://tests/framework/test_case.gd"

const _CraftedGear = preload("res://game_logic/professions/CraftedGear.gd")
const _GearRolls = preload("res://game_logic/items/GearRolls.gd")
const ProfessionDefs = preload("res://game_logic/professions/ProfessionDefs.gd")
const WeaponRegistry = preload("res://autoloads/WeaponRegistry.gd")
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
	_sm.gear_rolls = {}
	_sm.owned_helmets.clear()
	_sm.owned_weapons.clear()


func after_each() -> void:
	_sm.free()


func _gear_recipes() -> Array[String]:
	var out: Array[String] = []
	for id: String in ProfessionDefs.RECIPES:
		if str((ProfessionDefs.RECIPES[id] as Dictionary)["output"]["kind"]) == "gear":
			out.append(id)
	return out


# ---- Recipes ----

func test_gear_recipes_name_real_equipment() -> void:
	var ids: Array[String] = _gear_recipes()
	assert_gt(ids.size(), 0, "crafting has gear recipes")
	for id: String in ids:
		var r: Dictionary = ProfessionDefs.def(id)
		var out: Dictionary = r["output"]
		assert_eq(str(r["profession"]), ProfessionDefs.CRAFTING, id + " is a crafting recipe")
		var item: String = str(out["id"])
		assert_true(WeaponRegistry.has_weapon(item), id + " names real equipment " + item)
		assert_true(ProfessionDefs.output_valid(out), id + " output valid")
		assert_eq(int(out.get("count", 1)), 1, id + " crafts one piece")


func test_gear_output_rejects_unknown_items() -> void:
	assert_false(ProfessionDefs.output_valid({"kind": "gear", "id": "no_such_gear"}))
	assert_true(ProfessionDefs.output_valid({"kind": "gear", "id": "iron_helm"}))


# ---- Skill → rarity ----

func test_skill_maps_to_tier_in_steps() -> void:
	assert_eq(_CraftedGear.tier_for_skill(1), 1)
	assert_eq(_CraftedGear.tier_for_skill(14), 1)
	assert_eq(_CraftedGear.tier_for_skill(15), 2)
	assert_eq(_CraftedGear.tier_for_skill(30), 3)
	assert_eq(_CraftedGear.tier_for_skill(45), 4)
	assert_eq(_CraftedGear.tier_for_skill(50), 4)


func test_weights_fold_legendary_into_epic() -> void:
	for skill: int in [1, 15, 30, 50]:
		var w: Array[int] = _CraftedGear.weights_for_skill(skill)
		assert_eq(w.size(), 3, "common / rare / epic only at skill %d" % skill)
		var src: Array = _GearRolls.TIER_WEIGHTS[_CraftedGear.tier_for_skill(skill) - 1]
		assert_eq(w[2], int(src[2]) + int(src[3]), "epic absorbs legendary at skill %d" % skill)


func test_crafted_rolls_never_exceed_epic_and_improve_with_skill() -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 11
	var low_epic: int = 0
	var high_epic: int = 0
	for _i: int in range(2000):
		var lo: Dictionary = _CraftedGear.roll(1, 5, rng)
		var hi: Dictionary = _CraftedGear.roll(50, 5, rng)
		assert_ne(str(lo["rarity"]), "legendary")
		assert_ne(str(hi["rarity"]), "legendary", "crafting caps at epic")
		if str(lo["rarity"]) == "epic":
			low_epic += 1
		if str(hi["rarity"]) == "epic":
			high_epic += 1
	assert_gt(high_epic, 0, "a master crafter makes epics")
	assert_true(high_epic > low_epic, "epics come more often at high skill")


func test_roll_item_level_follows_recipe_level() -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 3
	assert_eq(int(_CraftedGear.roll(5, 12, rng)["ilvl"]), 12)
	assert_eq(int(_CraftedGear.roll(5, 0, rng)["ilvl"]), 1)


# ---- Craft grants ----

func test_craft_grants_item_and_roll() -> void:
	_sm.professions.add_material("rough_hide", 2)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 5
	var res: Dictionary = _sm.professions.craft("stitch_leather_cap", rng)
	assert_true(bool(res["ok"]), str(res.get("reason", "")))
	assert_eq(str(res["grant"]), "new")
	assert_true(_sm.get_owned_by_slot("helmet").has("leather_cap"), "item owned")
	assert_eq(_sm.professions.count("rough_hide"), 0, "inputs consumed")
	var saved: Dictionary = _sm.gear_rolls.get("leather_cap", {})
	assert_eq(str(saved.get("rarity")), str((res["roll"] as Dictionary)["rarity"]), "roll saved")
	assert_eq(int(saved.get("ilvl")), 1, "item level is the recipe level")
	assert_gt(int(res["xp"]), 0)


func test_duplicate_craft_keeps_the_better_roll() -> void:
	_sm.professions.add_material("rough_hide", 2)
	_sm.professions.add_material("rough_hide", 2)
	_sm.gear_rolls["leather_cap"] = {"rarity": "legendary", "ilvl": 60}
	_sm.owned_helmets.append("leather_cap")
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 9
	var res: Dictionary = _sm.professions.craft("stitch_leather_cap", rng)
	assert_true(bool(res["ok"]))
	assert_eq(str(res["grant"]), "kept", "a worse crafted roll does not replace a legendary one")
	assert_eq(str((_sm.gear_rolls["leather_cap"] as Dictionary)["rarity"]), "legendary")
	assert_eq(int(_sm.owned_helmets.count("leather_cap")), 1, "no duplicate copy")


func test_duplicate_craft_upgrades_a_weaker_roll() -> void:
	_sm.professions.add_material("rough_hide", 2)
	_sm.gear_rolls["leather_cap"] = {"rarity": "common", "ilvl": 1}
	_sm.owned_helmets.append("leather_cap")
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 2
	var res: Dictionary = _sm.professions.craft("stitch_leather_cap", rng)
	var new_roll: Dictionary = res["roll"]
	var saved: Dictionary = _sm.gear_rolls["leather_cap"]
	assert_eq(str(res["grant"]) == "upgraded", _GearRolls.better(new_roll, {"rarity": "common", "ilvl": 1}),
			"upgrade exactly when the crafted roll is better")
	assert_true(_GearRolls.mult(saved) >= _GearRolls.mult(new_roll) - 0.0001, "never keeps a worse roll")
	assert_true(_GearRolls.mult(saved) >= _GearRolls.mult({"rarity": "common", "ilvl": 1}) - 0.0001)


func test_gear_craft_refused_without_inputs() -> void:
	assert_eq(_sm.professions.craft_block("forge_iron_helm"), "inputs")
	assert_false(bool(_sm.professions.craft("forge_iron_helm")["ok"]))
	assert_false(_sm.get_owned_by_slot("helmet").has("iron_helm"))
