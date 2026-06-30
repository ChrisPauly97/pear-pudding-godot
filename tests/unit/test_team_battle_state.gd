## Unit tests for 2v2 team battle state model (GID-102 / TID-371).
##
## Tests: setup interleaving + team assignment, turn rotation alternates teams across
## all 4 slots and wraps, opponent() picks the lowest-HP alive enemy-team member,
## is_game_over()/winner() team-aware, to_dict/from_dict round-trip.
extends "res://tests/framework/test_case.gd"

const GameState = preload("res://game_logic/battle/GameState.gd")
const PlayerState = preload("res://game_logic/battle/PlayerState.gd")

var _default_deck: Array[String] = ["ghost", "skeleton", "zombie", "ghoul",
	"ghost", "skeleton", "zombie", "ghoul", "ghost", "skeleton", "zombie", "ghoul"]


func _team_battle() -> GameState:
	var gs := GameState.new()
	gs.setup_team_battle(
		func(_local_idx: int, ps: PlayerState) -> void:
			ps.build_deck(_default_deck)
			ps.draw_opening_hand(4),
		func(_local_idx: int, ps: PlayerState) -> void:
			ps.build_deck(_default_deck)
			ps.draw_opening_hand(4))
	return gs


# ---------------------------------------------------------------------------
# Setup: interleaving + team assignment
# ---------------------------------------------------------------------------

func test_setup_produces_four_players() -> void:
	assert_eq(_team_battle().players.size(), 4)


func test_team_battle_flag_is_set() -> void:
	assert_true(_team_battle().team_battle)


func test_players_interleaved_by_team() -> void:
	var gs := _team_battle()
	assert_eq(gs.player_teams, [0, 1, 0, 1])


func test_current_player_starts_at_zero() -> void:
	assert_eq(_team_battle().current_player_idx, 0)


func test_player_zero_starts_with_extra_mana_turn() -> void:
	var gs := _team_battle()
	assert_eq(gs.player_turn_numbers[0], 1)
	assert_eq(gs.player_turn_numbers[1], 0)
	assert_eq(gs.player_turn_numbers[2], 0)
	assert_eq(gs.player_turn_numbers[3], 0)


# ---------------------------------------------------------------------------
# Turn rotation alternates teams
# ---------------------------------------------------------------------------

func test_turn_rotation_alternates_teams_and_wraps() -> void:
	var gs := _team_battle()
	var seen_idxs: Array[int] = [gs.current_player_idx]
	for _i in range(8):
		gs.end_turn()
		seen_idxs.append(gs.current_player_idx)
	# 0,1,2,3,0,1,2,3,0 — strict round robin across all 4 slots.
	assert_eq(seen_idxs, [0, 1, 2, 3, 0, 1, 2, 3, 0])
	# Verify it strictly alternates team 0 / team 1 every single turn.
	for i in seen_idxs:
		var expected_team: int = i % 2
		assert_eq(gs.player_teams[i], expected_team)


# ---------------------------------------------------------------------------
# opponent() — lowest-HP alive enemy-team member
# ---------------------------------------------------------------------------

func test_opponent_for_team0_member_is_lowest_hp_team1_member() -> void:
	var gs := _team_battle()
	gs.players[1].hero.health = 5
	gs.players[3].hero.health = 20
	# current_player_idx == 0 (team 0); enemy team is players[1] and players[3].
	assert_eq(gs.opponent(), gs.players[1])


func test_opponent_for_team1_member_is_lowest_hp_team0_member() -> void:
	var gs := _team_battle()
	gs.current_player_idx = 1  # team 1's turn
	gs.players[0].hero.health = 30
	gs.players[2].hero.health = 4
	assert_eq(gs.opponent(), gs.players[2])


func test_opponent_prefers_alive_over_dead_even_if_higher_hp() -> void:
	var gs := _team_battle()
	gs.players[1].hero.health = 0  # dead
	gs.players[3].hero.health = 15  # alive
	assert_eq(gs.opponent(), gs.players[3], "must prefer the alive enemy over a dead one")


func test_opponent_idx_matches_opponent() -> void:
	var gs := _team_battle()
	gs.players[1].hero.health = 1
	assert_eq(gs.opponent_idx(), gs.players.find(gs.opponent()))


# ---------------------------------------------------------------------------
# is_game_over() / winner() — team-aware
# ---------------------------------------------------------------------------

func test_not_game_over_when_one_member_down_but_teammate_alive() -> void:
	var gs := _team_battle()
	gs.players[1].hero.health = 0  # one team-1 member dead
	assert_false(gs.is_game_over())
	assert_eq(gs.winner(), -1)


func test_game_over_and_team0_wins_when_team1_fully_dead() -> void:
	var gs := _team_battle()
	gs.players[1].hero.health = 0
	gs.players[3].hero.health = 0
	assert_true(gs.is_game_over())
	assert_eq(gs.winner(), 0)


func test_game_over_and_team1_wins_when_team0_fully_dead() -> void:
	var gs := _team_battle()
	gs.players[0].hero.health = 0
	gs.players[2].hero.health = 0
	assert_true(gs.is_game_over())
	assert_eq(gs.winner(), 1)


func test_not_game_over_at_battle_start() -> void:
	assert_false(_team_battle().is_game_over())


# ---------------------------------------------------------------------------
# to_dict / from_dict round-trip
# ---------------------------------------------------------------------------

func test_round_trip_preserves_team_battle_flag_and_teams() -> void:
	var gs := _team_battle()
	var restored := GameState.new()
	restored.from_dict(gs.to_dict())
	assert_true(restored.team_battle)
	assert_eq(restored.player_teams, [0, 1, 0, 1])
	assert_eq(restored.players.size(), 4)


func test_round_trip_preserves_mid_battle_state() -> void:
	var gs := _team_battle()
	gs.end_turn()
	gs.end_turn()
	gs.players[1].hero.health = 7
	var restored := GameState.new()
	restored.from_dict(gs.to_dict())
	assert_eq(restored.current_player_idx, gs.current_player_idx)
	assert_eq(restored.players[1].hero.health, 7)
	assert_true(restored.team_battle)


func test_from_dict_defaults_team_battle_false_for_legacy_dict() -> void:
	# A 2-player dict with no team_battle/player_teams keys must not crash and
	# must default to non-team-battle.
	var gs := GameState.new()
	var legacy: Dictionary = gs.to_dict()
	legacy.erase("team_battle")
	legacy.erase("player_teams")
	var restored := GameState.new()
	restored.from_dict(legacy)
	assert_false(restored.team_battle)
	assert_true(restored.player_teams.is_empty())
