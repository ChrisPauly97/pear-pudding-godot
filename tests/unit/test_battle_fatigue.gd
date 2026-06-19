## Unit tests for the deck fatigue system (GID-077).
##
## Verifies escalating damage on empty-draw, counter persistence via
## to_dict/from_dict, and that discard is no longer reshuffled.
extends "res://tests/framework/test_case.gd"

const CardInstance = preload("res://game_logic/battle/CardInstance.gd")
const PlayerState = preload("res://game_logic/battle/PlayerState.gd")

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

func _tmpl(id: String = "ghost") -> Dictionary:
	return {
		"id": id, "name": id.capitalize(), "cost": 1,
		"attack": 1, "health": 2,
		"card_class": "minion", "description": "",
	}


func _card() -> CardInstance:
	return CardInstance.new(_tmpl())


func _player_with_deck(size: int) -> PlayerState:
	var p := PlayerState.new(0)
	for _i in range(size):
		p.draw_deck.append(_card())
	return p


# ---------------------------------------------------------------------------
# Fatigue — escalating damage
# ---------------------------------------------------------------------------

func test_fatigue_counter_starts_at_zero() -> void:
	var p := PlayerState.new(0)
	assert_eq(p.fatigue_counter, 0)


func test_first_empty_draw_deals_one_damage() -> void:
	var p := PlayerState.new(0)
	p.draw_card()
	assert_eq(p.hero.health, 29)


func test_first_empty_draw_increments_counter_to_one() -> void:
	var p := PlayerState.new(0)
	p.draw_card()
	assert_eq(p.fatigue_counter, 1)


func test_second_empty_draw_deals_two_more_damage() -> void:
	var p := PlayerState.new(0)
	p.draw_card()  # -1 HP
	p.draw_card()  # -2 HP
	assert_eq(p.hero.health, 27)


func test_second_empty_draw_increments_counter_to_two() -> void:
	var p := PlayerState.new(0)
	p.draw_card()
	p.draw_card()
	assert_eq(p.fatigue_counter, 2)


func test_fatigue_fires_after_deck_empties() -> void:
	var p := _player_with_deck(1)
	p.draw_card()  # draws the one card — no fatigue
	assert_eq(p.hero.health, 30, "draw from non-empty deck should not deal fatigue")
	p.draw_card()  # deck now empty — fatigue = 1
	assert_eq(p.hero.health, 29)


func test_discard_is_not_reshuffled_into_deck() -> void:
	var p := PlayerState.new(0)
	p.discard.append(_card())
	p.draw_card()  # deck empty, discard has a card — should NOT reshuffle
	assert_eq(p.discard.size(), 1, "discard should remain intact; no reshuffle")
	assert_eq(p.hand.size(), 0, "no card should be drawn when deck is empty")


func test_draw_from_non_empty_deck_does_not_increment_fatigue() -> void:
	var p := _player_with_deck(3)
	p.draw_card()
	p.draw_card()
	assert_eq(p.fatigue_counter, 0)


# ---------------------------------------------------------------------------
# Serialization — fatigue_counter persists through to_dict/from_dict
# ---------------------------------------------------------------------------

func test_fatigue_counter_serialized_in_to_dict() -> void:
	var p := PlayerState.new(0)
	p.draw_card()  # fatigue_counter = 1
	var d: Dictionary = p.to_dict()
	assert_has(d.keys(), "fatigue_counter")
	assert_eq(int(d["fatigue_counter"]), 1)


func test_fatigue_counter_restored_from_dict() -> void:
	var p := PlayerState.new(0)
	p.draw_card()
	p.draw_card()  # fatigue_counter = 2
	var d: Dictionary = p.to_dict()
	var p2 := PlayerState.new(0)
	p2.from_dict(d)
	assert_eq(p2.fatigue_counter, 2)


func test_fatigue_counter_defaults_to_zero_if_missing_from_dict() -> void:
	var p := PlayerState.new(0)
	p.from_dict({"player_id": 0})
	assert_eq(p.fatigue_counter, 0)
