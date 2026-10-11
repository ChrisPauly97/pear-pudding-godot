## GID-187 / TID-778: balance player profiles (typical / modest / bare).
extends "res://tests/framework/test_case.gd"

const BalanceProfiles = preload("res://game_logic/battle/BalanceProfiles.gd")
const GearDrops = preload("res://game_logic/items/GearDrops.gd")
const XpCurve = preload("res://game_logic/progression/XpCurve.gd")
const SkillRegistry = preload("res://autoloads/SkillRegistry.gd")
const SkillData = preload("res://data/SkillData.gd")
const TechniqueDefs = preload("res://game_logic/battle/TechniqueDefs.gd")
const UnlockLadder = preload("res://game_logic/progression/UnlockLadder.gd")
const BattleSetup = preload("res://game_logic/battle/BattleSetup.gd")
const GameState = preload("res://game_logic/battle/GameState.gd")
const PlayerState = preload("res://game_logic/battle/PlayerState.gd")

func test_bare_is_the_old_hero() -> void:
	var c: Dictionary = BalanceProfiles.cfg(20, "light", "bare")
	assert_false(c.has("gear"))
	assert_false(c.has("skills"))
	assert_false(c.has("deck"))

func test_typical_wears_the_expected_loadout() -> void:
	var c: Dictionary = BalanceProfiles.cfg(30, "dark")
	var loadout: Dictionary = GearDrops.expected_loadout(30)
	assert_eq(str(c["weapon"]), str(loadout["weapon"]))
	assert_eq(str(c["offhand"]), str(loadout["offhand"]))
	assert_eq((c["gear"] as Array).size(), loadout.size() - 2)

func test_modest_lags_a_band_and_half_the_points() -> void:
	var t: Dictionary = BalanceProfiles.cfg(30, "verdant")
	var m: Dictionary = BalanceProfiles.cfg(30, "verdant", "modest")
	assert_eq(str(m["weapon"]), str(GearDrops.expected_loadout(20)["weapon"]))
	assert_lte((m["skills"] as Array).size(), (t["skills"] as Array).size())
	assert_eq((m["skills"] as Array).size(), mini(XpCurve.skill_points_at(30) / 2, (t["skills"] as Array).size()))

func test_skill_build_spends_the_level_points_in_prerequisite_order() -> void:
	for mt: String in ["light", "dark", "verdant", "rift"]:
		var build: Array[String] = BalanceProfiles.skill_build(mt, XpCurve.skill_points_at(30))
		assert_gt(build.size(), 0, mt)
		assert_lte(build.size(), XpCurve.skill_points_at(30), mt)
		assert_eq(BalanceProfiles.skill_build(mt, 3).size(), 3, "spends exactly the points it has")
		for i: int in build.size():
			var sk: SkillData = SkillRegistry.get_skill(build[i])
			for pre: String in sk.prerequisites:
				assert_true(build.slice(0, i).has(pre), "%s before its prerequisite %s" % [sk.id, pre])
	assert_eq(BalanceProfiles.skill_build("light", 0).size(), 0, "no points below level 10")

func test_deck_respects_technique_slots() -> void:
	var c: Dictionary = BalanceProfiles.cfg(40, "rift")
	var techs: int = 0
	for id: String in (c["deck"] as Array):
		if TechniqueDefs.is_technique(id):
			techs += 1
	var base: int = 0
	for id: String in BattleSetup.school_matched_deck("rift", c["learned"] as Array):
		if TechniqueDefs.is_technique(id):
			base += 1
	assert_lte(techs, maxi(base, UnlockLadder.technique_slots(c["learned"] as Array)), "skill cards fill free slots only")

func test_profile_builds_a_fight_with_gear_stats() -> void:
	var c: Dictionary = BalanceProfiles.cfg(30, "light")
	c.merge({"seed": 4, "enemy_type": "rift_echo", "enemy_level": 30}, true)
	var me: PlayerState = (BattleSetup.build(c)["state"] as GameState).players[0]
	assert_gt(me.gear_stat("stamina") + me.gear_stat("armor"), 0.0, "on-curve gear applied")
