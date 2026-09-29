## Unit tests for gear rarity / item level (GID-136 / TID-538).
extends "res://tests/framework/test_case.gd"

const _GearRolls = preload("res://game_logic/items/GearRolls.gd")
const _SideQuests = preload("res://game_logic/quests/SideQuests.gd")
const _SaveQuests = preload("res://autoloads/save_manager/SaveQuests.gd")
const _UpgradeDefs = preload("res://game_logic/UpgradeDefs.gd")
const WeaponRegistry = preload("res://autoloads/WeaponRegistry.gd")
const SaveManagerScript = preload("res://autoloads/SaveManager.gd")

var _sm: SaveManagerScript


func before_each() -> void:
	_sm = SaveManagerScript.new()
	_sm._loaded = true


func after_each() -> void:
	_sm.free()


func test_normalize_rejects_junk() -> void:
	assert_eq(_GearRolls.normalize(null), _GearRolls.default_roll())
	assert_eq(_GearRolls.normalize({"rarity": "mythic", "ilvl": "x"}), _GearRolls.default_roll())
	assert_eq(int(_GearRolls.normalize({"rarity": "epic", "ilvl": 999.0})["ilvl"]), _GearRolls.MAX_ILVL)


func test_higher_tiers_roll_better() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var low: float = 0.0
	var high: float = 0.0
	for _i in range(400):
		low += _GearRolls.mult(_GearRolls.roll(1, 1, rng))
		high += _GearRolls.mult(_GearRolls.roll(4, 1, rng))
	assert_true(high > low * 1.15, "tier 4 should average clearly better (%.1f vs %.1f)" % [high, low])
	assert_eq(int(_GearRolls.roll(2, 17, rng)["ilvl"]), 17, "item level follows the source level")


func test_mult_and_better() -> void:
	assert_eq(_GearRolls.mult(_GearRolls.default_roll()), 1.0)
	var rare5 := {"rarity": "rare", "ilvl": 5}
	assert_almost_eq(_GearRolls.mult(rare5), 1.25 * 1.08, 0.0001)
	assert_true(_GearRolls.better(rare5, {"rarity": "common", "ilvl": 10}))
	assert_true(_GearRolls.better({"rarity": "common", "ilvl": 30}, rare5), "item level can beat rarity")
	assert_false(_GearRolls.better(rare5, rare5))


func test_rolled_stats_scale_and_never_drop_below_base() -> void:
	var helm = WeaponRegistry.get_weapon("iron_helm")
	assert_eq(_UpgradeDefs.effective_stat(helm, 0), helm.battle_effect_value)
	assert_eq(_UpgradeDefs.effective_stat(helm, 0, 2.0), helm.battle_effect_value * 2)
	assert_eq(_UpgradeDefs.effective_stat(helm, 0, 0.5), helm.battle_effect_value, "never below base")


func test_grant_new_upgrade_and_keep() -> void:
	assert_eq(_sm.gear.grant("iron_helm", {"rarity": "rare", "ilvl": 3}), "new")
	assert_true(_sm.owned_helmets.has("iron_helm"))
	assert_eq(str(_sm.gear.roll_of("iron_helm")["rarity"]), "rare")
	assert_eq(_sm.gear.grant("iron_helm", {"rarity": "common", "ilvl": 3}), "kept")
	assert_eq(_sm.gear.grant("iron_helm", {"rarity": "epic", "ilvl": 3}), "upgraded")
	assert_eq(str(_sm.gear.roll_of("iron_helm")["rarity"]), "epic")
	assert_eq(_sm.gear.grant("dusk_blade", {}), "new", "weapons too")
	assert_eq(_sm.gear.grant("no_such_item", {}), "")
	assert_eq(_sm.gear.roll_of("travel_boots"), _GearRolls.default_roll(), "unrolled items are common ilvl 1")
	assert_true(SaveManagerScript.PERSISTED_FIELDS.has("gear_rolls"))


func test_quest_gear_choices_are_real_items() -> void:
	var found: int = 0
	for q: Dictionary in _SideQuests.QUESTS:
		var choice: Array = (q.get("rewards", {}) as Dictionary).get("gear_choice", [])
		for id: Variant in choice:
			assert_true(WeaponRegistry.has_weapon(str(id)), "%s offers unknown %s" % [q["id"], id])
		if not choice.is_empty():
			found += 1
	assert_true(found >= 3, "a few quests offer a gear choice")
	var q: Dictionary = _SideQuests.def("first_spark")
	assert_eq(str(_SaveQuests.quest_gear_roll(q)["rarity"]), _GearRolls.QUEST_RARITY)
	# The pick is granted as a quest roll; a bogus pick falls back to the first choice.
	_sm.quests_active["first_spark"] = {"progress": [99, 99, 99, 99]}
	if _sm.quests.is_ready("first_spark"):
		var got: Dictionary = _sm.quests.turn_in("first_spark", "iron_greaves")
		assert_eq(str(got.get("gear", "")), "iron_greaves")
		assert_eq(str(_sm.gear.roll_of("iron_greaves")["rarity"]), _GearRolls.QUEST_RARITY)
