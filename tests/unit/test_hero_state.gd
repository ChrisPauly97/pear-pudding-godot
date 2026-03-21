## Unit tests for HeroState.
##
## Covers initial values, damage model (clamp at zero), liveness, mana scaling
## across turns (capped at 10), mana spending (success / insufficient guard),
## and refill semantics.
extends "res://tests/framework/test_case.gd"

const HeroState = preload("res://game_logic/battle/HeroState.gd")

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

func _hero(pid: int = 0) -> HeroState:
	return HeroState.new(pid)


# ---------------------------------------------------------------------------
# Initial state
# ---------------------------------------------------------------------------

func test_initial_health_is_30() -> void:
	assert_eq(_hero().health, 30)


func test_initial_max_health_is_30() -> void:
	assert_eq(_hero().max_health, 30)


func test_initial_mana_is_1() -> void:
	assert_eq(_hero().mana, 1)


func test_initial_max_mana_is_1() -> void:
	assert_eq(_hero().max_mana, 1)


func test_initial_attack_is_2() -> void:
	assert_eq(_hero().attack, 2)


func test_player_id_set_correctly() -> void:
	assert_eq(_hero(1).player_id, 1)


# ---------------------------------------------------------------------------
# is_alive
# ---------------------------------------------------------------------------

func test_is_alive_with_positive_health() -> void:
	assert_true(_hero().is_alive())


func test_is_alive_at_one_health() -> void:
	var h = _hero()
	h.health = 1
	assert_true(h.is_alive())


func test_is_not_alive_at_zero_health() -> void:
	var h = _hero()
	h.health = 0
	assert_false(h.is_alive())


# ---------------------------------------------------------------------------
# take_damage
# ---------------------------------------------------------------------------

func test_take_damage_reduces_health() -> void:
	var h = _hero()
	h.take_damage(5)
	assert_eq(h.health, 25)


func test_take_damage_does_not_go_below_zero() -> void:
	var h = _hero()
	h.take_damage(999)
	assert_eq(h.health, 0)


func test_take_damage_zero_is_noop() -> void:
	var h = _hero()
	h.take_damage(0)
	assert_eq(h.health, 30)


func test_take_damage_kills_hero_at_exact_health() -> void:
	var h = _hero()
	h.take_damage(30)
	assert_false(h.is_alive())


func test_multiple_damage_instances_accumulate() -> void:
	var h = _hero()
	h.take_damage(10)
	h.take_damage(10)
	assert_eq(h.health, 10)


# ---------------------------------------------------------------------------
# gain_mana_for_turn
# ---------------------------------------------------------------------------

func test_gain_mana_for_turn_1_sets_max_mana_to_1() -> void:
	var h = _hero()
	h.gain_mana_for_turn(1)
	assert_eq(h.max_mana, 1)


func test_gain_mana_for_turn_5_sets_max_mana_to_5() -> void:
	var h = _hero()
	h.gain_mana_for_turn(5)
	assert_eq(h.max_mana, 5)


func test_gain_mana_for_turn_refills_current_mana() -> void:
	var h = _hero()
	h.mana = 0
	h.gain_mana_for_turn(3)
	assert_eq(h.mana, 3)


func test_gain_mana_caps_max_mana_at_10() -> void:
	var h = _hero()
	h.gain_mana_for_turn(15)
	assert_eq(h.max_mana, 10)


func test_gain_mana_caps_current_mana_at_10() -> void:
	var h = _hero()
	h.gain_mana_for_turn(15)
	assert_eq(h.mana, 10)


func test_mana_progression_follows_turn_number() -> void:
	var h = _hero()
	for turn in range(1, 11):
		h.gain_mana_for_turn(turn)
		assert_eq(h.max_mana, turn, "turn %d should give %d max mana" % [turn, turn])


# ---------------------------------------------------------------------------
# spend_mana
# ---------------------------------------------------------------------------

func test_spend_mana_deducts_amount_and_returns_true() -> void:
	var h = _hero()
	h.gain_mana_for_turn(5)
	var ok := h.spend_mana(3)
	assert_true(ok)
	assert_eq(h.mana, 2)


func test_spend_mana_returns_false_when_insufficient() -> void:
	var h = _hero()
	h.gain_mana_for_turn(1)
	var ok := h.spend_mana(5)
	assert_false(ok)


func test_spend_mana_does_not_deduct_on_failure() -> void:
	var h = _hero()
	h.gain_mana_for_turn(2)
	h.spend_mana(5)
	assert_eq(h.mana, 2)


func test_spend_all_mana_leaves_zero() -> void:
	var h = _hero()
	h.gain_mana_for_turn(4)
	h.spend_mana(4)
	assert_eq(h.mana, 0)


func test_spend_zero_mana_succeeds_without_change() -> void:
	var h = _hero()
	h.gain_mana_for_turn(3)
	var ok := h.spend_mana(0)
	assert_true(ok)
	assert_eq(h.mana, 3)
