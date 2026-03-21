## Unit tests for GameState.
##
## GameState._init() calls CardRegistry.get_template() via PlayerState.build_deck(),
## so these tests require the runner to be executed with `--path .` so that the
## CardRegistry autoload is initialised.  All other logic is pure GDScript and
## needs no special setup.
extends "res://tests/framework/test_case.gd"

const GameState = preload("res://game_logic/battle/GameState.gd")
const PlayerState = preload("res://game_logic/battle/PlayerState.gd")
const CardInstance = preload("res://game_logic/battle/CardInstance.gd")

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

## Build a fresh GameState.  Requires CardRegistry autoload.
func _state() -> GameState:
	return GameState.new()


func _tmpl(id: String = "ghost", cost: int = 1, attack: int = 1, health: int = 2) -> Dictionary:
	return {
		"id": id, "name": id.capitalize(), "cost": cost,
		"attack": attack, "health": health,
		"card_class": "minion", "description": "",
	}


func _card(cost: int = 1, attack: int = 1, health: int = 2) -> CardInstance:
	return CardInstance.from_template(_tmpl("ghost", cost, attack, health))


# ---------------------------------------------------------------------------
# Construction
# ---------------------------------------------------------------------------

func test_initial_state_has_two_players() -> void:
	assert_eq(_state().players.size(), 2)


func test_player_zero_goes_first() -> void:
	assert_eq(_state().current_player_idx, 0)


func test_turn_number_starts_at_one() -> void:
	assert_eq(_state().turn_number, 1)


func test_player_zero_is_human() -> void:
	assert_false(_state().players[0].is_ai)


func test_player_one_is_ai() -> void:
	assert_true(_state().players[1].is_ai)


func test_both_players_have_opening_hands() -> void:
	var gs = _state()
	assert_gt(gs.players[0].hand.size(), 0)
	assert_gt(gs.players[1].hand.size(), 0)


func test_opening_hand_size_is_four() -> void:
	var gs = _state()
	assert_eq(gs.players[0].hand.size(), 4)
	assert_eq(gs.players[1].hand.size(), 4)


# ---------------------------------------------------------------------------
# current_player / opponent
# ---------------------------------------------------------------------------

func test_current_player_returns_player_zero_initially() -> void:
	var gs = _state()
	assert_eq(gs.current_player().player_id, 0)


func test_opponent_returns_player_one_initially() -> void:
	var gs = _state()
	assert_eq(gs.opponent().player_id, 1)


func test_current_player_and_opponent_are_different() -> void:
	var gs = _state()
	assert_ne(gs.current_player().player_id, gs.opponent().player_id)


# ---------------------------------------------------------------------------
# end_turn
# ---------------------------------------------------------------------------

func test_end_turn_switches_active_player() -> void:
	var gs = _state()
	gs.end_turn()
	assert_eq(gs.current_player_idx, 1)


func test_end_turn_increments_turn_number() -> void:
	var gs = _state()
	gs.end_turn()
	assert_eq(gs.turn_number, 2)


func test_end_turn_twice_returns_to_player_zero() -> void:
	var gs = _state()
	gs.end_turn()
	gs.end_turn()
	assert_eq(gs.current_player_idx, 0)


func test_end_turn_four_times_increments_turn_to_five() -> void:
	var gs = _state()
	for _i in range(4):
		gs.end_turn()
	assert_eq(gs.turn_number, 5)


func test_end_turn_draws_card_for_new_current_player() -> void:
	var gs = _state()
	var hand_before: int = gs.opponent().hand.size()
	gs.end_turn()
	# After end_turn, the new current player (was opponent) starts their turn and draws
	assert_gte(gs.current_player().hand.size(), hand_before)


# ---------------------------------------------------------------------------
# is_game_over / winner
# ---------------------------------------------------------------------------

func test_game_not_over_initially() -> void:
	assert_false(_state().is_game_over())


func test_winner_is_minus_one_when_not_over() -> void:
	assert_eq(_state().winner(), -1)


func test_game_over_when_player_zero_hero_dies() -> void:
	var gs = _state()
	gs.players[0].hero.health = 0
	assert_true(gs.is_game_over())


func test_game_over_when_player_one_hero_dies() -> void:
	var gs = _state()
	gs.players[1].hero.health = 0
	assert_true(gs.is_game_over())


func test_winner_is_player_one_when_player_zero_dies() -> void:
	var gs = _state()
	gs.players[0].hero.health = 0
	assert_eq(gs.winner(), 1)


func test_winner_is_player_zero_when_player_one_dies() -> void:
	var gs = _state()
	gs.players[1].hero.health = 0
	assert_eq(gs.winner(), 0)


func test_game_continues_while_both_heroes_alive() -> void:
	var gs = _state()
	gs.players[0].hero.take_damage(15)
	gs.players[1].hero.take_damage(10)
	assert_false(gs.is_game_over())
