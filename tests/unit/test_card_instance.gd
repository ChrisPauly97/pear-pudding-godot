## Unit tests for CardInstance.
##
## Tests cover: factory construction, alive/dead state transitions, attack
## eligibility flags (summoning sickness, attack count, stun counter), turn
## cycle behaviour, and dict serialisation.
extends "res://tests/framework/test_case.gd"

const CardInstance = preload("res://game_logic/battle/CardInstance.gd")

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

func _tmpl(id: String = "ghost", cost: int = 1, attack: int = 1, health: int = 2) -> Dictionary:
	return {
		"id": id,
		"name": id.capitalize(),
		"cost": cost,
		"attack": attack,
		"health": health,
		"card_class": "minion",
		"description": "Test card.",
	}


func _card(id: String = "ghost", cost: int = 1, attack: int = 1, health: int = 2) -> CardInstance:
	return CardInstance.new(_tmpl(id, cost, attack, health))


# ---------------------------------------------------------------------------
# from_template — factory construction
# ---------------------------------------------------------------------------

func test_from_template_sets_template_id() -> void:
	var c = _card("skeleton")
	assert_eq(c.template_id, "skeleton")


func test_from_template_sets_name() -> void:
	var c = _card("ghost")
	assert_eq(c.name, "Ghost")


func test_from_template_sets_cost() -> void:
	var c = _card("ghost", 3)
	assert_eq(c.cost, 3)


func test_from_template_sets_attack() -> void:
	var c = _card("ghost", 1, 4)
	assert_eq(c.attack, 4)


func test_from_template_sets_health_and_max_health() -> void:
	var c = _card("ghost", 1, 1, 5)
	assert_eq(c.health, 5)
	assert_eq(c.max_health, 5)


func test_from_template_sets_card_class() -> void:
	var c = _card()
	assert_eq(c.card_class, "minion")


func test_from_template_generates_unique_instance_ids() -> void:
	var a = _card()
	var b = _card()
	assert_ne(a.instance_id, b.instance_id)


func test_from_template_instance_id_contains_template_id() -> void:
	var c = _card("zombie")
	assert_true(c.instance_id.begins_with("zombie_"), "instance_id should start with template id")


# ---------------------------------------------------------------------------
# is_alive
# ---------------------------------------------------------------------------

func test_is_alive_when_health_positive() -> void:
	var c = _card()
	assert_true(c.is_alive())


func test_is_alive_at_one_health() -> void:
	var c = _card()
	c.health = 1
	assert_true(c.is_alive())


func test_is_not_alive_at_zero_health() -> void:
	var c = _card()
	c.health = 0
	assert_false(c.is_alive())


func test_is_not_alive_when_health_negative() -> void:
	var c = _card()
	c.health = -1
	assert_false(c.is_alive())


# ---------------------------------------------------------------------------
# can_attack
# ---------------------------------------------------------------------------

func test_cannot_attack_on_the_turn_played_summoning_sick() -> void:
	var c = _card()
	# Freshly created cards start summoning_sick = true
	assert_false(c.can_attack(), "new card should not be able to attack (summoning sickness)")


func test_can_attack_after_start_turn_clears_sickness() -> void:
	var c = _card()
	c.start_turn()
	assert_true(c.can_attack())


func test_cannot_attack_when_attack_count_exhausted() -> void:
	var c = _card()
	c.summoning_sick = false
	c.attack_count = 0
	assert_false(c.can_attack())


func test_cannot_attack_when_stunned() -> void:
	var c = _card()
	c.summoning_sick = false
	c.out_of_play = 1
	assert_false(c.can_attack())


func test_can_attack_when_ready() -> void:
	var c = _card()
	c.summoning_sick = false
	c.attack_count = 1
	c.out_of_play = 0
	assert_true(c.can_attack())


# ---------------------------------------------------------------------------
# start_turn
# ---------------------------------------------------------------------------

func test_start_turn_clears_summoning_sickness() -> void:
	var c = _card()
	assert_true(c.summoning_sick)
	c.start_turn()
	assert_false(c.summoning_sick)


func test_start_turn_resets_attack_count_to_one() -> void:
	var c = _card()
	c.summoning_sick = false
	c.attack_count = 0
	c.start_turn()
	assert_eq(c.attack_count, 1)


func test_start_turn_decrements_stun_counter() -> void:
	var c = _card()
	c.out_of_play = 2
	c.start_turn()
	assert_eq(c.out_of_play, 1)


func test_start_turn_does_not_go_below_zero_stun() -> void:
	var c = _card()
	c.out_of_play = 0
	c.start_turn()
	assert_eq(c.out_of_play, 0)


func test_stun_expires_after_enough_start_turns() -> void:
	var c = _card()
	c.out_of_play = 2
	c.start_turn()
	assert_false(c.can_attack(), "still stunned after 1 turn")
	c.start_turn()
	assert_true(c.can_attack(), "stun should have expired")


# ---------------------------------------------------------------------------
# to_dict
# ---------------------------------------------------------------------------

func test_to_dict_contains_instance_id() -> void:
	var c = _card()
	assert_has(c.to_dict().keys(), "instance_id")


func test_to_dict_contains_correct_attack() -> void:
	var c = _card("ghost", 1, 3, 2)
	assert_eq(c.to_dict()["attack"], 3)


func test_to_dict_can_attack_reflects_state() -> void:
	var c = _card()
	c.summoning_sick = false
	assert_true(c.to_dict()["can_attack"])
	c.attack_count = 0
	assert_false(c.to_dict()["can_attack"])
