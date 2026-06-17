## Unit tests for puzzle mode in GameState.
## Verifies that load_puzzle() correctly builds board state from PuzzleData.
extends "res://tests/framework/test_case.gd"

const GameState = preload("res://game_logic/battle/GameState.gd")
const PuzzleData = preload("res://game_logic/battle/PuzzleData.gd")
const CardInstance = preload("res://game_logic/battle/CardInstance.gd")

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

func _minimal_puzzle(player_hand: Array[String], enemy_hp: int, mana: int) -> PuzzleData:
	var pd := PuzzleData.new()
	pd.puzzle_id = "test_puzzle"
	pd.title = "Test"
	pd.hint_text = "Test hint"
	pd.player_hand = player_hand
	pd.player_hero_hp = 30
	pd.player_mana = mana
	pd.enemy_hero_hp = enemy_hp
	pd.enemy_board = []
	pd.enemy_board_buffs = []
	pd.reward_card_id = "ghost"
	return pd


# ---------------------------------------------------------------------------
# load_puzzle basics
# ---------------------------------------------------------------------------

func test_load_puzzle_sets_puzzle_mode_true() -> void:
	var pd := _minimal_puzzle([], 5, 2)
	var gs := GameState.new()
	gs.load_puzzle(pd)
	assert_true(gs.puzzle_mode)


func test_load_puzzle_sets_puzzle_data_id() -> void:
	var pd := _minimal_puzzle([], 5, 2)
	var gs := GameState.new()
	gs.load_puzzle(pd)
	assert_eq(gs.puzzle_data_id, "test_puzzle")


func test_load_puzzle_sets_current_player_to_zero() -> void:
	var pd := _minimal_puzzle([], 5, 2)
	var gs := GameState.new()
	gs.load_puzzle(pd)
	assert_eq(gs.current_player_idx, 0)


func test_load_puzzle_sets_enemy_hero_hp() -> void:
	var pd := _minimal_puzzle([], 7, 2)
	var gs := GameState.new()
	gs.load_puzzle(pd)
	assert_eq(gs.opponent().hero.health, 7)


func test_load_puzzle_sets_player_mana() -> void:
	var pd := _minimal_puzzle([], 5, 3)
	var gs := GameState.new()
	gs.load_puzzle(pd)
	assert_eq(gs.current_player().hero.mana, 3)


func test_load_puzzle_clears_player_deck() -> void:
	var hand: Array[String] = ["ghost"]
	var pd := _minimal_puzzle(hand, 5, 2)
	var gs := GameState.new()
	gs.load_puzzle(pd)
	assert_eq(gs.current_player().draw_deck.size(), 0)


func test_load_puzzle_populates_player_hand() -> void:
	var hand: Array[String] = ["ghost", "skeleton"]
	var pd := _minimal_puzzle(hand, 5, 2)
	var gs := GameState.new()
	gs.load_puzzle(pd)
	assert_eq(gs.current_player().hand.size(), 2)


func test_load_puzzle_hand_cards_have_no_summoning_sickness() -> void:
	var hand: Array[String] = ["ghost"]
	var pd := _minimal_puzzle(hand, 5, 2)
	var gs := GameState.new()
	gs.load_puzzle(pd)
	if gs.current_player().hand.size() > 0:
		var ci: CardInstance = gs.current_player().hand[0]
		assert_false(ci.summoning_sick)


# ---------------------------------------------------------------------------
# Board setup
# ---------------------------------------------------------------------------

func test_load_puzzle_populates_player_board() -> void:
	var pd := PuzzleData.new()
	pd.puzzle_id = "board_test"
	pd.title = "Board Test"
	pd.player_board = ["ghost"]
	pd.player_mana = 0
	pd.player_hero_hp = 30
	pd.enemy_hero_hp = 5
	pd.enemy_board = []
	pd.enemy_board_buffs = []
	pd.reward_card_id = ""
	var gs := GameState.new()
	gs.load_puzzle(pd)
	assert_ne(gs.current_player().board.slots[0], null)


func test_load_puzzle_board_minions_have_no_summoning_sickness() -> void:
	var pd := PuzzleData.new()
	pd.puzzle_id = "board_test2"
	pd.title = "Board Test"
	pd.player_board = ["ghost"]
	pd.player_mana = 0
	pd.player_hero_hp = 30
	pd.enemy_hero_hp = 5
	pd.enemy_board = []
	pd.enemy_board_buffs = []
	pd.reward_card_id = ""
	var gs := GameState.new()
	gs.load_puzzle(pd)
	var ci: CardInstance = gs.current_player().board.slots[0]
	if ci != null:
		assert_false(ci.summoning_sick)


func test_load_puzzle_enemy_board_buffs_applied() -> void:
	var pd := PuzzleData.new()
	pd.puzzle_id = "buff_test"
	pd.title = "Buff Test"
	pd.player_board = []
	pd.player_mana = 0
	pd.player_hero_hp = 30
	pd.enemy_hero_hp = 5
	pd.enemy_board = ["ghost"]
	pd.enemy_board_buffs = ["0:ward"]
	pd.reward_card_id = ""
	var gs := GameState.new()
	gs.load_puzzle(pd)
	var ci: CardInstance = gs.opponent().board.slots[0]
	if ci != null:
		assert_true(ci.keywords.has("ward"))


# ---------------------------------------------------------------------------
# to_dict / from_dict round-trip
# ---------------------------------------------------------------------------

func test_puzzle_mode_survives_serialization() -> void:
	var pd := _minimal_puzzle([], 5, 2)
	var gs := GameState.new()
	gs.load_puzzle(pd)
	var d := gs.to_dict()
	var gs2 := GameState.new()
	gs2.from_dict(d)
	assert_true(gs2.puzzle_mode)


func test_puzzle_data_id_survives_serialization() -> void:
	var pd := _minimal_puzzle([], 5, 2)
	var gs := GameState.new()
	gs.load_puzzle(pd)
	var d := gs.to_dict()
	var gs2 := GameState.new()
	gs2.from_dict(d)
	assert_eq(gs2.puzzle_data_id, "test_puzzle")
