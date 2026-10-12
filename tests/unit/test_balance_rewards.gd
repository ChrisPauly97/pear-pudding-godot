## GID-187 / TID-779: the rewards section's configs and checks (the fights run in tests/balance_coverage.gd).
extends "res://tests/framework/test_case.gd"

const BalanceRewards = preload("res://game_logic/battle/BalanceRewards.gd")
const BalanceProfiles = preload("res://game_logic/battle/BalanceProfiles.gd")
const BattleSetup = preload("res://game_logic/battle/BattleSetup.gd")
const GameState = preload("res://game_logic/battle/GameState.gd")
const PlayerState = preload("res://game_logic/battle/PlayerState.gd")
const CompanionRegistry = preload("res://autoloads/CompanionRegistry.gd")
const UnlockLadder = preload("res://game_logic/progression/UnlockLadder.gd")
const XpCurve = preload("res://game_logic/progression/XpCurve.gd")

func test_companion_matches_the_registry() -> void:
	var c: Resource = CompanionRegistry.get_companion("maiteln")
	assert_eq(str(c.get("passive_type")), str(BalanceRewards.COMPANION["passive_type"]))
	assert_eq(int(c.get("passive_value")), int(BalanceRewards.COMPANION["passive_value"]))

func test_axis_cfgs_differ_only_in_their_reward() -> void:
	var on: Dictionary = BalanceRewards.axis_cfg("skills", true, 26, "light")
	var off: Dictionary = BalanceRewards.axis_cfg("skills", false, 26, "light")
	assert_gt((on["skills"] as Array).size(), 0)
	assert_eq((off["skills"] as Array).size(), 0)
	assert_eq(on["gear"], off["gear"], "gear unchanged")
	assert_eq(int(BalanceRewards.axis_cfg("weapon_upgrade", true, 26, "light")["weapon_upgrade"]),
		BalanceRewards.WEAPON_UPGRADE)
	assert_false(BalanceRewards.axis_cfg("card_rank", false, 26, "light").has("card_rank"))
	assert_false((BalanceRewards.axis_cfg("tech_slot", false, 40, "light")["learned"] as Array).has(
		UnlockLadder.FEAT_TECH_SLOT))
	assert_false(BalanceRewards.applies("tech_slot", 14), "the fourth slot is not learned at 14")

func test_card_rank_and_companion_reach_the_fight() -> void:
	var base: Dictionary = {"seed": 4, "player_level": 10, "learned": BalanceProfiles.cfg(10, "light")["learned"]}
	var plain: PlayerState = (BattleSetup.build(base)["state"] as GameState).players[0]
	var ranked_cfg: Dictionary = base.duplicate()
	ranked_cfg["card_rank"] = 3
	ranked_cfg["companion"] = BalanceRewards.COMPANION
	var ranked: PlayerState = (BattleSetup.build(ranked_cfg)["state"] as GameState).players[0]
	assert_eq(ranked.hand.size(), plain.hand.size() + 1, "Maiteln draws one more card")
	var hp_plain: int = 0
	var hp_ranked: int = 0
	for c: Variant in plain.draw_deck + plain.hand:
		hp_plain += int((c as Object).get("max_health"))
	for c: Variant in ranked.draw_deck + ranked.hand:
		hp_ranked += int((c as Object).get("max_health"))
	assert_gt(hp_ranked, hp_plain, "veteran cards are tougher")

func test_alt_build_spends_the_same_points_differently() -> void:
	var pts: int = XpCurve.skill_points_at(26)
	var std: Array[String] = BalanceProfiles.skill_build("dark", pts)
	var alt: Array[String] = BalanceRewards.alt_build("dark", 26)
	assert_eq(alt.size(), std.size(), "the same points")
	assert_ne(alt[0], std[0], "second branch first")

func test_check_gates() -> void:
	var ok: Dictionary = {
		"skills/a@1": {"axis": "skills", "with": 0.7, "without": 0.5},
		"builds/a@1": {"axis": "builds", "with": 0.7, "without": 0.6},
	}
	assert_true(BalanceRewards.check(ok).is_empty())
	assert_eq(BalanceRewards.check({"skills/a@1": {"axis": "skills", "with": 0.5, "without": 0.5}}).size(), 1,
		"no gain fails")
	assert_eq(BalanceRewards.check({"skills/a@1": {"axis": "skills", "with": 1.0, "without": 0.2}}).size(), 1,
		"a must-have fails")
	assert_true(BalanceRewards.check({"gear_step/a@1": {"axis": "gear_step", "with": 1.0, "without": 0.0}}).is_empty(),
		"gear is uncapped")
	assert_eq(BalanceRewards.check({"builds/a@1": {"axis": "builds", "with": 1.0, "without": 0.5}}).size(), 2,
		"a cell over the bound, and the mean")
	assert_true(BalanceRewards.check({"tech_slot/a@1": {"axis": "tech_slot", "with": 0.5, "without": 0.5}}).is_empty(),
		"the fourth slot has no minimum")
