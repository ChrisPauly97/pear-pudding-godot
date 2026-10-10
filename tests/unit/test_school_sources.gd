## Unit tests for the player's school sources (GID-181 / TID-754): outgoing school power
## (DamageResolver attacker side), the school-power / school-resist skill nodes, gear school
## affixes (roll, save, label, drop message), weapon convert, and the battle-side wiring.
## No sources means no effect, so the balance sim keeps its bands.
extends "res://tests/framework/test_case.gd"

const SkillData = preload("res://data/SkillData.gd")
const _CombatTuning = preload("res://game_logic/battle/CombatTuning.gd")
const _DamageResolver = preload("res://game_logic/battle/DamageResolver.gd")
const _DamageSchools = preload("res://game_logic/battle/DamageSchools.gd")
const _HeroState = preload("res://game_logic/battle/HeroState.gd")
const _PlayerState = preload("res://game_logic/battle/PlayerState.gd")
const _SkillMods = preload("res://game_logic/battle/SkillMods.gd")
const _SkillRegistry = preload("res://autoloads/SkillRegistry.gd")
const _BattleSetup = preload("res://game_logic/battle/BattleSetup.gd")
const _GearRolls = preload("res://game_logic/items/GearRolls.gd")
const _SaveGear = preload("res://autoloads/save_manager/SaveGear.gd")
const SaveManagerScript = preload("res://autoloads/SaveManager.gd")

var _sm: SaveManagerScript


func before_each() -> void:
	_sm = SaveManagerScript.new()
	_sm._loaded = true


func after_each() -> void:
	_sm.free()


func _side(school_power: Dictionary = {}, resist: Dictionary = {}) -> _PlayerState:
	var p := _PlayerState.new(0, true)
	p.school_power = school_power
	p.hero.school_resist = resist
	return p


func _hero(hp: int = 30) -> _HeroState:
	var h := _HeroState.new(1)
	h.health = hp
	h.max_health = hp
	return h


func _affix(kind: String, school: String, pct: float) -> Dictionary:
	return {"kind": kind, "school": school, "pct": pct}


func _item(id: String, affix: Dictionary) -> Dictionary:
	return {"id": id, "level": 0, "mult": 1.0, "affix": affix}


# ---------------------------------------------------------------------------
# DamageResolver: attacker school power
# ---------------------------------------------------------------------------

func test_attacker_power_scales_its_school_only() -> void:
	var defender := _side()
	var attacker := _side({"light": 0.2})
	assert_eq(_DamageResolver.scaled_amount(defender, 10, "light", null, attacker), 12)
	assert_eq(_DamageResolver.scaled_amount(defender, 10, "dark", null, attacker), 10, "other schools unchanged")


func test_no_attacker_or_no_power_changes_nothing() -> void:
	var defender := _side()
	assert_eq(_DamageResolver.scaled_amount(defender, 10, "light"), 10, "default attacker null")
	assert_eq(_DamageResolver.scaled_amount(defender, 10, "light", null, _side()), 10, "empty power")


func test_power_stacks_with_hero_resist_and_profile() -> void:
	var defender := _side({}, {"dark": 0.5})
	defender.school_profile = {"weak": {"dark": true}}
	var attacker := _side({"dark": 0.2})
	# 10 x 1.5 (weak) x 1.2 (power) x 0.5 (resist) = 9
	assert_eq(_DamageResolver.scaled_amount(defender, 10, "dark", null, attacker), 9)


func test_power_cannot_go_negative() -> void:
	var attacker := _side({"light": -3.0})
	assert_almost_eq(_DamageResolver.power_mult(attacker, "light"), 0.0)
	assert_eq(_DamageResolver.scaled_amount(_side(), 10, "light", null, attacker), 0)


func test_deal_uses_attacker_power_on_the_target() -> void:
	var hero := _hero(30)
	var r: Dictionary = _DamageResolver.deal(_side(), hero, 10, "light", null, _side({"light": 0.5}))
	assert_eq(int(r["dealt"]), 15)
	assert_eq(hero.health, 15)


# ---------------------------------------------------------------------------
# Weapon convert on PlayerState
# ---------------------------------------------------------------------------

func test_weapon_school_defaults_to_physical() -> void:
	var p := _PlayerState.new(0, true)
	assert_eq(p.weapon_school(), _DamageSchools.PHYSICAL)
	p.convert_school = "rift"
	assert_eq(p.weapon_school(), "rift")


# ---------------------------------------------------------------------------
# Skill nodes
# ---------------------------------------------------------------------------

func test_school_nodes_are_registered_and_sit_under_row_two() -> void:
	for id: String in ["ember_kindled_light", "dawn_sunward_ward", "dusk_umbral_edge", "bloom_rooted_ward"]:
		var sk: SkillData = _SkillRegistry.get_skill(id)
		assert_not_null(sk, id + " registered")
		assert_eq(sk.tree_row, 3, id + " is on row 3")
		assert_eq(sk.prerequisites.size(), 1)
		var pre: SkillData = _SkillRegistry.get_skill(sk.prerequisites[0])
		assert_not_null(pre, id + " prerequisite exists")
		assert_eq(pre.tree_row, 2, id + " hangs off row 2")
		assert_eq(pre.tree_col, sk.tree_col, id + " shares its column")


func test_school_nodes_sum_per_school() -> void:
	var ids: Array = ["ember_kindled_light", "dusk_umbral_edge", "bloom_rooted_ward", "ember_pyroblast"]
	assert_eq(_SkillMods.school_nodes(ids, "school_power"), {"light": 10, "dark": 10})
	assert_eq(_SkillMods.school_nodes(ids, "school_resist"), {"physical": 10})
	assert_eq(_SkillMods.school_nodes(["ember_kindled_light", "ember_kindled_light"], "school_power"),
			{"light": 20}, "two copies add")
	assert_eq(_SkillMods.school_nodes([], "school_power"), {})


func test_school_nodes_are_not_card_mods() -> void:
	var mods := _SkillMods.new()
	mods.add_skills(["ember_kindled_light", "bloom_rooted_ward"])
	assert_true(mods.is_empty(), "school nodes never become card modifiers")


# ---------------------------------------------------------------------------
# Battle wiring: outgoing power, convert, resist sources
# ---------------------------------------------------------------------------

func test_school_damage_affix_adds_power() -> void:
	var p := _PlayerState.new(0, true)
	var items: Array[Dictionary] = [_item("dusk_blade", _affix("school_dmg", "dark", 0.15))]
	_BattleSetup.apply_school_power(p, items, [])
	assert_almost_eq(float(p.school_power["dark"]), 0.15)
	assert_eq(p.weapon_school(), _DamageSchools.PHYSICAL, "a damage affix does not convert")


func test_convert_affix_sets_weapon_school() -> void:
	var p := _PlayerState.new(0, true)
	var items: Array[Dictionary] = [_item("dusk_blade", _affix("convert", "light", 0.0))]
	_BattleSetup.apply_school_power(p, items, [])
	assert_eq(p.weapon_school(), "light")
	assert_true(p.school_power.is_empty())


func test_school_power_nodes_add_to_affixes() -> void:
	var p := _PlayerState.new(0, true)
	var items: Array[Dictionary] = [_item("dusk_blade", _affix("school_dmg", "light", 0.05))]
	_BattleSetup.apply_school_power(p, items, ["ember_kindled_light"])
	assert_almost_eq(float(p.school_power["light"]), 0.15, 0.0001, "affix plus node")


func test_resist_sources_sum_affixes_and_nodes_then_cap() -> void:
	var items: Array[Dictionary] = [_item("iron_helm", _affix("school_resist", "physical", 0.1))]
	var raw: Dictionary = _BattleSetup.school_resist_sources(items, ["bloom_rooted_ward"])
	assert_almost_eq(float(raw["physical"]), 0.2)
	var capped: Dictionary = _DamageSchools.capped_resists({"rift": 2.0}, _CombatTuning.new())
	assert_almost_eq(float(capped["rift"]), _CombatTuning.new().get_f("max_player_resist"))


func test_no_sources_means_no_effect() -> void:
	var p := _PlayerState.new(0, true)
	_BattleSetup.apply_school_power(p, [], [])
	assert_true(p.school_power.is_empty())
	assert_eq(p.weapon_school(), _DamageSchools.PHYSICAL)
	assert_true(_BattleSetup.school_resist_sources([], []).is_empty())


func test_bad_affix_is_ignored_in_battle() -> void:
	var p := _PlayerState.new(0, true)
	var items: Array[Dictionary] = [_item("dusk_blade", _affix("school_dmg", "mythic", 0.5)),
			_item("iron_helm", {"kind": "boost"})]
	_BattleSetup.apply_school_power(p, items, [])
	assert_true(p.school_power.is_empty())
	assert_true(_BattleSetup.school_resist_sources(items, []).is_empty())


# ---------------------------------------------------------------------------
# GearRolls: validation, roll, label
# ---------------------------------------------------------------------------

func test_normalize_keeps_a_valid_affix() -> void:
	var n: Dictionary = _GearRolls.normalize({"rarity": "rare", "ilvl": 3,
			"affix": _affix("school_resist", "rift", 0.1)})
	assert_eq(str(n["affix"]["kind"]), "school_resist")
	assert_eq(str(n["affix"]["school"]), "rift")
	assert_almost_eq(float(n["affix"]["pct"]), 0.1)


func test_normalize_drops_malformed_affixes() -> void:
	assert_false(_GearRolls.normalize({"affix": _affix("boost", "dark", 0.1)}).has("affix"), "unknown kind")
	assert_false(_GearRolls.normalize({"affix": _affix("school_dmg", "mythic", 0.1)}).has("affix"), "unknown school")
	assert_false(_GearRolls.normalize({"affix": _affix("convert", "physical", 0.0)}).has("affix"), "convert to physical")
	assert_false(_GearRolls.normalize({"affix": "dark"}).has("affix"), "not a dictionary")


func test_old_saves_have_no_affix() -> void:
	var n: Dictionary = _GearRolls.normalize({"rarity": "epic", "ilvl": 5})
	assert_false(n.has("affix"))
	assert_eq(n, {"rarity": "epic", "ilvl": 5})


func test_pct_is_clamped_to_a_fraction() -> void:
	var n: Dictionary = _GearRolls.normalize({"affix": _affix("school_dmg", "dark", 7.0)})
	assert_almost_eq(float(n["affix"]["pct"]), 1.0)


func test_stat_roll_is_still_there_with_an_affix() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for _i in 400:
		var r: Dictionary = _GearRolls.roll(4, 9, rng, true)
		assert_eq(int(r["ilvl"]), 9, "item level still follows the source")
		assert_true(_GearRolls.RARITIES.has(str(r["rarity"])))


func test_affix_chance_rises_with_tier() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var low: int = 0
	var high: int = 0
	for _i in 4000:
		if _GearRolls.roll(1, 1, rng).has("affix"):
			low += 1
		if _GearRolls.roll(4, 1, rng).has("affix"):
			high += 1
	assert_between(float(low) / 4000.0, 0.03, 0.07, "tier 1 near 5%")
	assert_between(float(high) / 4000.0, 0.25, 0.35, "tier 4 near 30%")


func test_convert_only_rolls_on_weapons() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 23
	var armour_converts: int = 0
	var weapon_converts: int = 0
	for _i in 3000:
		var a: Dictionary = _GearRolls.roll(4, 1, rng, false)
		if a.has("affix") and str(a["affix"]["kind"]) == "convert":
			armour_converts += 1
		var w: Dictionary = _GearRolls.roll(4, 1, rng, true)
		if w.has("affix") and str(w["affix"]["kind"]) == "convert":
			weapon_converts += 1
			assert_true(_DamageSchools.is_school(str(w["affix"]["school"])))
			assert_true(str(w["affix"]["school"]) != _DamageSchools.PHYSICAL)
	assert_eq(armour_converts, 0)
	assert_gt(weapon_converts, 0)


func test_affix_label_text() -> void:
	assert_eq(_GearRolls.affix_label({"affix": _affix("school_dmg", "dark", 0.15)}), "+15% Dark damage")
	assert_eq(_GearRolls.affix_label({"affix": _affix("school_resist", "rift", 0.1)}), "+10% Rift resist")
	assert_eq(_GearRolls.affix_label({"affix": _affix("convert", "light", 0.0)}), "Strikes as Light")
	assert_eq(_GearRolls.affix_label({"rarity": "common", "ilvl": 1}), "")


# ---------------------------------------------------------------------------
# SaveGear: grant, persist, drop message, roll_for
# ---------------------------------------------------------------------------

func test_granted_affix_is_saved_and_read_back() -> void:
	_sm.gear.grant("dusk_blade", {"rarity": "rare", "ilvl": 2, "affix": _affix("school_dmg", "dark", 0.15)})
	var r: Dictionary = _sm.gear.roll_of("dusk_blade")
	assert_eq(str(r["affix"]["school"]), "dark")
	assert_almost_eq(float(r["affix"]["pct"]), 0.15)


func test_old_save_roll_reads_as_no_affix() -> void:
	_sm.gear_rolls = {"iron_helm": {"rarity": "rare", "ilvl": 2}}
	assert_false(_sm.gear.roll_of("iron_helm").has("affix"))


func test_drop_message_names_the_affix() -> void:
	var roll: Dictionary = {"rarity": "rare", "ilvl": 2, "affix": _affix("school_dmg", "dark", 0.15)}
	var msg: String = _SaveGear.drop_message("dusk_blade", roll, "new")
	assert_true(msg.contains("+15% Dark damage"), msg)
	var plain: String = _SaveGear.drop_message("dusk_blade", {"rarity": "rare", "ilvl": 2}, "new")
	assert_false(plain.contains("damage"), plain)


func test_roll_for_only_converts_weapons() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 41
	var helm_converts: int = 0
	var blade_converts: int = 0
	for _i in 3000:
		var h: Dictionary = _SaveGear.roll_for("iron_helm", 4, 1, rng)
		if h.has("affix") and str(h["affix"]["kind"]) == "convert":
			helm_converts += 1
		var b: Dictionary = _SaveGear.roll_for("dusk_blade", 4, 1, rng)
		if b.has("affix") and str(b["affix"]["kind"]) == "convert":
			blade_converts += 1
	assert_eq(helm_converts, 0)
	assert_gt(blade_converts, 0)
