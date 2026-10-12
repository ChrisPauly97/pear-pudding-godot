## GID-187 / TID-786: real-time party sides, enemy targeting, co-op boss scaling and the coop section's check
## (its fights run in tests/balance_coverage.gd).
extends "res://tests/framework/test_case.gd"

const RealtimeCombat = preload("res://game_logic/battle/RealtimeCombat.gd")
const GameState = preload("res://game_logic/battle/GameState.gd")
const PlayerState = preload("res://game_logic/battle/PlayerState.gd")
const CombatTuning = preload("res://game_logic/battle/CombatTuning.gd")
const CoopBattleScaling = preload("res://game_logic/battle/CoopBattleScaling.gd")
const BattleSetup = preload("res://game_logic/battle/BattleSetup.gd")
const BalanceFight = preload("res://game_logic/battle/BalanceFight.gd")
const BalanceCoop = preload("res://game_logic/battle/BalanceCoop.gd")
const BalanceProfiles = preload("res://game_logic/battle/BalanceProfiles.gd")

func test_add_ally_joins_the_party() -> void:
	var gs := GameState.new()
	var rt := RealtimeCombat.new(gs, [20, 20])
	var side: int = rt.add_ally(PlayerState.new(2, false), 20)
	assert_eq(side, 2)
	assert_true(rt.is_party(side))
	assert_eq(rt.enemy_sides(), [RealtimeCombat.ENEMY] as Array[int], "an ally is not an enemy")
	assert_true(gs.team_battle)
	assert_eq(gs.player_teams, [0, 1, 0] as Array[int])
	assert_gt(gs.players[side].hero.max_health, 30, "its HP grows with its level like yours")

func test_solo_targeting_never_rolls() -> void:
	var rt := RealtimeCombat.new(GameState.new(), [5, 5])
	rt.rng.seed = 7
	var before: int = rt.rng.state
	assert_eq(rt.enemy_target(), RealtimeCombat.PLAYER)
	assert_eq(rt.rng.state, before, "solo fights replay exactly")

func test_party_targeting_spreads_over_living_heroes() -> void:
	var gs := GameState.new()
	var rt := RealtimeCombat.new(gs, [10, 10])
	var ally: int = rt.add_ally(PlayerState.new(2, false), 10)
	rt.rng.seed = 3
	var seen: Dictionary = {}
	for i: int in 40:
		seen[rt.enemy_target()] = true
	assert_true(seen.has(RealtimeCombat.PLAYER) and seen.has(ally))
	gs.players[RealtimeCombat.PLAYER].hero.health = 0
	assert_eq(rt.enemy_target(), ally, "only the living")

func test_party_loses_only_when_all_fall() -> void:
	var gs := GameState.new()
	var rt := RealtimeCombat.new(gs, [10, 10])
	rt.add_ally(PlayerState.new(2, false), 10)
	gs.players[RealtimeCombat.PLAYER].hero.health = 0
	assert_false(gs.is_game_over(), "the ally fights on")
	gs.players[RealtimeCombat.ENEMY].hero.health = 0
	assert_eq(gs.winner(), 0, "the party's team wins")

func test_realtime_scaling() -> void:
	var t := CombatTuning.new()
	assert_almost_eq(CoopBattleScaling.realtime_hp_mult(1, t), 1.0, 0.0001, "solo")
	assert_almost_eq(CoopBattleScaling.realtime_damage_mult(1, t), 1.0, 0.0001, "solo")
	assert_almost_eq(CoopBattleScaling.realtime_haste_mult(1, t), 1.0, 0.0001, "solo")
	assert_almost_eq(CoopBattleScaling.realtime_hp_mult(3, t), 1.0 + 2.0 * t.get_f("coop_boss_hp"), 0.0001)
	var solo: Dictionary = BattleSetup.build({"seed": 2, "player_level": 30, "enemy_type": "barrow_king",
		"enemy_level": 30, "is_boss": true})
	var duo: Dictionary = BattleSetup.build({"seed": 2, "player_level": 30, "enemy_type": "barrow_king",
		"enemy_level": 30, "is_boss": true, "party": [{}]})
	var hp1: int = (solo["state"] as GameState).players[1].hero.max_health
	var hp2: int = (duo["state"] as GameState).players[1].hero.max_health
	assert_almost_eq(float(hp2) / float(hp1), CoopBattleScaling.realtime_hp_mult(2, t), 0.01)
	assert_almost_eq((duo["rt"] as RealtimeCombat).enemy_dmg_mult, CoopBattleScaling.realtime_damage_mult(2, t),
		0.0001)

func test_party_fight_is_deterministic() -> void:
	var c: Dictionary = BalanceCoop.party_cfg(BalanceCoop.CELLS[3], 2, 0)
	var a: Dictionary = BalanceFight.run(c)
	var b: Dictionary = BalanceFight.run(BalanceCoop.party_cfg(BalanceCoop.CELLS[3], 2, 0))
	assert_eq(str(a["result"]), str(b["result"]))
	assert_almost_eq(float(a["seconds"]), float(b["seconds"]), 0.0001)

func test_check_gates_per_party_size() -> void:
	var m: Dictionary = {
		"a@1/n1": {"n": 1, "win_rate": 0.6}, "a@1/n2": {"n": 2, "win_rate": 0.7},
		"a@1/n4": {"n": 4, "win_rate": 0.5},
	}
	assert_true(BalanceCoop.check(m).is_empty())
	(m["a@1/n4"] as Dictionary)["win_rate"] = 1.0
	assert_eq(BalanceCoop.check(m).size(), 1, "a carry fails")
