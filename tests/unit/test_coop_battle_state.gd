## Unit tests for co-op joint battle state model (GID-099).
##
## Tests: N-player setup, turn rotation including boss turn, win/loss conditions,
## to_dict/from_dict round-trip for N participants, and CoopBattleScaling.
extends "res://tests/framework/test_case.gd"

const GameState = preload("res://game_logic/battle/GameState.gd")
const PlayerState = preload("res://game_logic/battle/PlayerState.gd")
const CoopBattleScaling = preload("res://game_logic/battle/CoopBattleScaling.gd")

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

var _default_deck: Array[String] = ["ghost", "skeleton", "zombie", "ghoul",
	"ghost", "skeleton", "zombie", "ghoul", "ghost", "skeleton", "zombie", "ghoul"]


func _coop(n_allies: int) -> GameState:
	var gs := GameState.new()
	gs.setup_coop_battle(n_allies,
		func(_i: int, ally: PlayerState) -> void:
			ally.build_deck(_default_deck)
			ally.draw_opening_hand(4),
		func(boss: PlayerState) -> void:
			boss.build_deck(_default_deck)
			boss.draw_opening_hand(4))
	return gs


# ---------------------------------------------------------------------------
# Setup: player counts
# ---------------------------------------------------------------------------

func test_two_allies_gives_three_total_players() -> void:
	assert_eq(_coop(2).players.size(), 3)


func test_three_allies_gives_four_total_players() -> void:
	assert_eq(_coop(3).players.size(), 4)


func test_four_allies_gives_five_total_players() -> void:
	assert_eq(_coop(4).players.size(), 5)


func test_n_allies_clamped_to_two_minimum() -> void:
	# n_allies < 2 is clamped to 2
	assert_eq(_coop(1).players.size(), 3)


func test_n_allies_clamped_to_four_maximum() -> void:
	# n_allies > 4 is clamped to 4
	assert_eq(_coop(5).players.size(), 5)


func test_coop_battle_flag_is_set() -> void:
	assert_true(_coop(2).coop_battle)


func test_allies_returns_all_non_boss_players() -> void:
	var gs := _coop(3)
	assert_eq(gs.allies().size(), 3)


func test_boss_is_last_player() -> void:
	var gs := _coop(2)
	var boss_idx: int = gs.players.size() - 1
	assert_eq(gs.boss().player_id, gs.players[boss_idx].player_id)


func test_boss_is_ai() -> void:
	assert_true(_coop(2).boss().is_ai)


func test_allies_are_not_ai() -> void:
	var gs := _coop(2)
	for ally in gs.allies():
		assert_false(ally.is_ai)


func test_is_ally_returns_true_for_ally_indices() -> void:
	var gs := _coop(2)
	assert_true(gs.is_ally(0))
	assert_true(gs.is_ally(1))


func test_is_ally_returns_false_for_boss_index() -> void:
	var gs := _coop(2)
	assert_false(gs.is_ally(2))


# ---------------------------------------------------------------------------
# Turn rotation
# ---------------------------------------------------------------------------

func test_first_player_is_ally_zero() -> void:
	assert_eq(_coop(2).current_player_idx, 0)


func test_end_turn_advances_to_ally_one() -> void:
	var gs := _coop(2)
	gs.end_turn()
	assert_eq(gs.current_player_idx, 1)


func test_end_turn_after_last_ally_advances_to_boss() -> void:
	var gs := _coop(2)
	gs.end_turn()  # → ally 1
	gs.end_turn()  # → boss (idx 2)
	assert_eq(gs.current_player_idx, 2)


func test_end_turn_after_boss_wraps_to_ally_zero() -> void:
	var gs := _coop(2)
	gs.end_turn()
	gs.end_turn()
	gs.end_turn()  # → ally 0 again
	assert_eq(gs.current_player_idx, 0)


func test_three_ally_rotation_includes_boss_then_wraps() -> void:
	var gs := _coop(3)
	gs.end_turn()  # 0→1
	gs.end_turn()  # 1→2
	gs.end_turn()  # 2→3 (boss)
	assert_eq(gs.current_player_idx, 3)
	gs.end_turn()  # 3→0
	assert_eq(gs.current_player_idx, 0)


# ---------------------------------------------------------------------------
# opponent() during ally vs boss turns
# ---------------------------------------------------------------------------

func test_opponent_is_boss_during_ally_turn() -> void:
	var gs := _coop(2)
	assert_eq(gs.opponent().player_id, gs.boss().player_id)


func test_opponent_during_boss_turn_is_an_ally() -> void:
	var gs := _coop(2)
	gs.end_turn()
	gs.end_turn()  # boss turn
	var opp := gs.opponent()
	assert_true(gs.is_ally(opp.player_id))


func test_boss_targets_lowest_hp_ally() -> void:
	var gs := _coop(2)
	# Cripple ally 0 first so ally 1 has more HP.
	gs.players[0].hero.health = 5
	gs.players[1].hero.health = 20
	gs.end_turn()
	gs.end_turn()  # boss turn
	assert_eq(gs.opponent().player_id, gs.players[0].player_id)


# ---------------------------------------------------------------------------
# Win / loss conditions
# ---------------------------------------------------------------------------

func test_not_game_over_initially() -> void:
	assert_false(_coop(2).is_game_over())


func test_boss_dead_triggers_game_over() -> void:
	var gs := _coop(2)
	gs.boss().hero.health = 0
	assert_true(gs.is_game_over())


func test_boss_dead_winner_is_zero() -> void:
	var gs := _coop(2)
	gs.boss().hero.health = 0
	assert_eq(gs.winner(), 0)


func test_one_ally_alive_is_not_game_over() -> void:
	var gs := _coop(2)
	gs.players[0].hero.health = 0
	assert_false(gs.is_game_over())


func test_all_allies_dead_triggers_game_over() -> void:
	var gs := _coop(2)
	gs.players[0].hero.health = 0
	gs.players[1].hero.health = 0
	assert_true(gs.is_game_over())


func test_all_allies_dead_winner_is_boss_idx() -> void:
	var gs := _coop(2)
	gs.players[0].hero.health = 0
	gs.players[1].hero.health = 0
	assert_eq(gs.winner(), gs.boss().player_id)


func test_winner_minus_one_when_not_over() -> void:
	assert_eq(_coop(2).winner(), -1)


# ---------------------------------------------------------------------------
# to_dict / from_dict round-trip
# ---------------------------------------------------------------------------

func test_round_trip_preserves_coop_battle_flag() -> void:
	var gs := _coop(2)
	var gs2 := GameState.new()
	gs2.from_dict(gs.to_dict())
	assert_true(gs2.coop_battle)


func test_round_trip_preserves_player_count() -> void:
	var gs := _coop(3)
	var gs2 := GameState.new()
	gs2.from_dict(gs.to_dict())
	assert_eq(gs2.players.size(), 4)


func test_round_trip_preserves_current_player_idx() -> void:
	var gs := _coop(2)
	gs.end_turn()
	var gs2 := GameState.new()
	gs2.from_dict(gs.to_dict())
	assert_eq(gs2.current_player_idx, 1)


func test_round_trip_preserves_turn_number() -> void:
	var gs := _coop(2)
	gs.end_turn()
	gs.end_turn()
	var gs2 := GameState.new()
	gs2.from_dict(gs.to_dict())
	assert_eq(gs2.turn_number, gs.turn_number)


func test_round_trip_preserves_player_turn_numbers_size() -> void:
	var gs := _coop(3)
	var d: Dictionary = gs.to_dict()
	var ptn: Array = d["player_turn_numbers"]
	assert_eq(ptn.size(), 4)  # 3 allies + 1 boss


# ---------------------------------------------------------------------------
# CoopBattleScaling
# ---------------------------------------------------------------------------

func test_boss_hp_scales_with_party_size() -> void:
	var hp1: int = CoopBattleScaling.scale_boss_hp(30, 1)
	var hp2: int = CoopBattleScaling.scale_boss_hp(30, 2)
	var hp4: int = CoopBattleScaling.scale_boss_hp(30, 4)
	assert_lt(hp1, hp2)
	assert_lt(hp2, hp4)


func test_boss_hp_n1_matches_formula() -> void:
	# base_hp * (0.6 * 1 + 0.4) = base_hp * 1.0
	assert_eq(CoopBattleScaling.scale_boss_hp(30, 1), 30)


func test_boss_hp_n2_matches_formula() -> void:
	# 30 * (0.6 * 2 + 0.4) = 30 * 1.6 = 48
	assert_eq(CoopBattleScaling.scale_boss_hp(30, 2), 48)


func test_boss_hp_n4_matches_formula() -> void:
	# 30 * (0.6 * 4 + 0.4) = 30 * 2.8 = 84
	assert_eq(CoopBattleScaling.scale_boss_hp(30, 4), 84)


func test_boss_tier_n1_unchanged() -> void:
	assert_eq(CoopBattleScaling.scale_boss_tier(2, 1), 2)


func test_boss_tier_n3_increments_by_one() -> void:
	assert_eq(CoopBattleScaling.scale_boss_tier(2, 3), 3)


func test_boss_tier_capped_at_four() -> void:
	assert_eq(CoopBattleScaling.scale_boss_tier(4, 4), 4)


func test_boss_hp_clamped_below_min() -> void:
	var hp_min: int = CoopBattleScaling.scale_boss_hp(30, 1)
	var hp_too_low: int = CoopBattleScaling.scale_boss_hp(30, 0)
	assert_eq(hp_too_low, hp_min)


func test_boss_hp_clamped_above_max() -> void:
	var hp_max: int = CoopBattleScaling.scale_boss_hp(30, 4)
	var hp_too_high: int = CoopBattleScaling.scale_boss_hp(30, 99)
	assert_eq(hp_too_high, hp_max)
