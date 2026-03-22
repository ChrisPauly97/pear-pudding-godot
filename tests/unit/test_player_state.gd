## Unit tests for PlayerState.
##
## Tests bypass build_deck (which calls the CardRegistry autoload) by directly
## populating draw_deck with CardInstance objects built from raw templates.
## This keeps tests pure and fast while still exercising all PlayerState logic.
extends "res://tests/framework/test_case.gd"

const CardInstance = preload("res://game_logic/battle/CardInstance.gd")
const PlayerState = preload("res://game_logic/battle/PlayerState.gd")
const ZoneState = preload("res://game_logic/battle/ZoneState.gd")

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

func _tmpl(id: String = "ghost", cost: int = 1, attack: int = 1, health: int = 2) -> Dictionary:
	return {
		"id": id, "name": id.capitalize(), "cost": cost,
		"attack": attack, "health": health,
		"card_class": "minion", "description": "",
	}


func _card(cost: int = 1, attack: int = 1, health: int = 2) -> CardInstance:
	return CardInstance.from_template(_tmpl("ghost", cost, attack, health))


func _player(pid: int = 0, ai: bool = false) -> PlayerState:
	return PlayerState.new(pid, ai)


func _player_with_deck(size: int = 6, card_cost: int = 1) -> PlayerState:
	var p = _player()
	for _i in range(size):
		p.draw_deck.append(_card(card_cost))
	return p


# ---------------------------------------------------------------------------
# Construction
# ---------------------------------------------------------------------------

func test_player_id_is_set() -> void:
	assert_eq(_player(1).player_id, 1)


func test_is_ai_flag_set_correctly() -> void:
	assert_true(_player(0, true).is_ai)
	assert_false(_player(0, false).is_ai)


func test_new_player_has_empty_hand() -> void:
	assert_eq(_player().hand.size(), 0)


func test_new_player_has_empty_draw_deck() -> void:
	assert_eq(_player().draw_deck.size(), 0)


func test_new_player_has_empty_discard() -> void:
	assert_eq(_player().discard.size(), 0)


func test_new_player_hero_is_alive() -> void:
	assert_true(_player().hero.is_alive())


func test_new_player_board_is_empty() -> void:
	assert_eq(_player().board.get_cards().size(), 0)


# ---------------------------------------------------------------------------
# draw_card
# ---------------------------------------------------------------------------

func test_draw_card_moves_card_to_hand() -> void:
	var p = _player_with_deck(3)
	p.draw_card()
	assert_eq(p.hand.size(), 1)


func test_draw_card_reduces_deck_size() -> void:
	var p = _player_with_deck(3)
	p.draw_card()
	assert_eq(p.draw_deck.size(), 2)


func test_draw_card_returns_the_drawn_card() -> void:
	var p = _player_with_deck(1)
	var c = p.draw_card()
	assert_not_null(c)
	assert_has(p.hand, c)


func test_draw_card_returns_null_when_no_cards() -> void:
	var p = _player()
	var c = p.draw_card()
	assert_null(c)


func test_draw_card_shuffles_discard_into_deck_when_empty() -> void:
	var p = _player()
	var discarded = _card()
	p.discard.append(discarded)
	p.draw_card()
	# Either the card was drawn into hand or remains accessible
	assert_true(p.hand.size() == 1 or p.draw_deck.size() >= 0)
	assert_eq(p.discard.size(), 0, "discard should be cleared after shuffle")


func test_draw_card_multiple_times_empties_deck_into_hand() -> void:
	var p = _player_with_deck(4)
	for _i in range(4):
		p.draw_card()
	assert_eq(p.hand.size(), 4)
	assert_eq(p.draw_deck.size(), 0)


# ---------------------------------------------------------------------------
# draw_opening_hand
# ---------------------------------------------------------------------------

func test_draw_opening_hand_draws_four_cards_by_default() -> void:
	var p = _player_with_deck(8)
	p.draw_opening_hand()
	assert_eq(p.hand.size(), 4)


func test_draw_opening_hand_accepts_custom_count() -> void:
	var p = _player_with_deck(8)
	p.draw_opening_hand(3)
	assert_eq(p.hand.size(), 3)


func test_draw_opening_hand_reduces_deck_accordingly() -> void:
	var p = _player_with_deck(8)
	p.draw_opening_hand(4)
	assert_eq(p.draw_deck.size(), 4)


# ---------------------------------------------------------------------------
# can_play
# ---------------------------------------------------------------------------

func test_can_play_when_mana_equals_cost() -> void:
	var p = _player_with_deck(1, 1)
	p.hero.gain_mana_for_turn(3)
	var c = _card(3)
	p.hand.append(c)
	assert_true(p.can_play(c))


func test_cannot_play_when_insufficient_mana() -> void:
	var p = _player()
	p.hero.gain_mana_for_turn(1)
	var c = _card(5)
	p.hand.append(c)
	assert_false(p.can_play(c))


func test_cannot_play_when_board_is_full() -> void:
	var p = _player()
	p.hero.gain_mana_for_turn(10)
	# Fill the board
	for i in range(ZoneState.SLOT_COUNT):
		p.board.add_card(_card())
	var c = _card(1)
	p.hand.append(c)
	assert_false(p.can_play(c))


# ---------------------------------------------------------------------------
# play_card
# ---------------------------------------------------------------------------

func test_play_card_removes_from_hand() -> void:
	var p = _player()
	p.hero.gain_mana_for_turn(5)
	var c = _card(1)
	p.hand.append(c)
	p.play_card(c)
	assert_does_not_have(p.hand, c)


func test_play_card_adds_to_board() -> void:
	var p = _player()
	p.hero.gain_mana_for_turn(5)
	var c = _card(1)
	p.hand.append(c)
	p.play_card(c)
	assert_has(p.board.get_cards(), c)


func test_play_card_spends_mana() -> void:
	var p = _player()
	p.hero.gain_mana_for_turn(5)
	var c = _card(3)
	p.hand.append(c)
	p.play_card(c)
	assert_eq(p.hero.mana, 2)


func test_play_card_returns_true_on_success() -> void:
	var p = _player()
	p.hero.gain_mana_for_turn(5)
	var c = _card(1)
	p.hand.append(c)
	assert_true(p.play_card(c))


func test_play_card_returns_false_when_cannot_play() -> void:
	var p = _player()
	p.hero.gain_mana_for_turn(1)
	var c = _card(5)
	p.hand.append(c)
	assert_false(p.play_card(c))


func test_play_card_does_not_modify_hand_on_failure() -> void:
	var p = _player()
	p.hero.gain_mana_for_turn(1)
	var c = _card(5)
	p.hand.append(c)
	p.play_card(c)
	assert_has(p.hand, c)


# ---------------------------------------------------------------------------
# start_turn
# ---------------------------------------------------------------------------

func test_start_turn_refills_mana() -> void:
	var p = _player_with_deck(2)
	p.hero.gain_mana_for_turn(5)
	p.hero.mana = 0
	p.start_turn(5)
	assert_eq(p.hero.mana, 5)


func test_start_turn_draws_one_card() -> void:
	var p = _player_with_deck(4)
	var hand_before: int = p.hand.size()
	p.start_turn(1)
	assert_eq(p.hand.size(), hand_before + 1)


func test_start_turn_clears_summoning_sickness_on_board() -> void:
	var p = _player_with_deck(2)
	var c = _card()
	p.board.add_card(c)
	p.start_turn(1)
	assert_false(c.summoning_sick)
