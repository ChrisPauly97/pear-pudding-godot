## Unit tests for the status effects data model (TID-060).
## Covers apply/has/get/clear helpers on CardInstance and HeroState,
## armor absorption in take_damage, freeze check in can_attack,
## and stun bridging via out_of_play.
extends "res://tests/framework/test_case.gd"

const CardInstance = preload("res://game_logic/battle/CardInstance.gd")
const HeroState = preload("res://game_logic/battle/HeroState.gd")

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

func _card() -> CardInstance:
	return CardInstance.from_template({
		"id": "test", "name": "Test", "cost": 1,
		"attack": 2, "health": 5, "card_class": "minion", "description": "",
	})

func _hero() -> HeroState:
	return HeroState.new(0)

# ---------------------------------------------------------------------------
# CardInstance status helpers
# ---------------------------------------------------------------------------

func test_card_has_no_statuses_by_default() -> void:
	assert_false(_card().has_status("poison"))

func test_card_apply_status_stores_value() -> void:
	var c := _card()
	c.apply_status("poison", 3)
	assert_true(c.has_status("poison"))
	assert_eq(c.get_status_value("poison"), 3)

func test_card_clear_status_removes_it() -> void:
	var c := _card()
	c.apply_status("armor", 5)
	c.clear_status("armor")
	assert_false(c.has_status("armor"))

func test_card_get_status_value_returns_zero_when_absent() -> void:
	assert_eq(_card().get_status_value("freeze"), 0)

func test_card_multiple_statuses_coexist() -> void:
	var c := _card()
	c.apply_status("poison", 2)
	c.apply_status("armor", 4)
	assert_true(c.has_status("poison"))
	assert_true(c.has_status("armor"))

# ---------------------------------------------------------------------------
# CardInstance armor absorption in take_damage
# ---------------------------------------------------------------------------

func test_card_armor_absorbs_damage() -> void:
	var c := _card()
	c.apply_status("armor", 3)
	c.take_damage(2)
	assert_eq(c.health, 5)  # all absorbed by armor
	assert_eq(c.get_status_value("armor"), 1)

func test_card_armor_consumed_fully_when_damage_exceeds() -> void:
	var c := _card()
	c.apply_status("armor", 2)
	c.take_damage(5)
	assert_false(c.has_status("armor"))
	assert_eq(c.health, 2)  # 5 - 2 armor = 3 damage, health 5-3=2

func test_card_take_damage_zero_is_noop() -> void:
	var c := _card()
	c.take_damage(0)
	assert_eq(c.health, 5)

# ---------------------------------------------------------------------------
# CardInstance freeze blocks can_attack
# ---------------------------------------------------------------------------

func test_card_freeze_blocks_attack() -> void:
	var c := _card()
	c.summoning_sick = false
	c.attack_count = 1
	c.apply_status("freeze", 2)
	assert_false(c.can_attack())

func test_card_can_attack_after_freeze_cleared() -> void:
	var c := _card()
	c.summoning_sick = false
	c.attack_count = 1
	c.apply_status("freeze", 1)
	c.clear_status("freeze")
	assert_true(c.can_attack())

# ---------------------------------------------------------------------------
# CardInstance stun bridges to out_of_play
# ---------------------------------------------------------------------------

func test_card_stun_sets_out_of_play() -> void:
	var c := _card()
	c.summoning_sick = false
	c.apply_status("stun", 2)
	assert_eq(c.out_of_play, 2)
	assert_false(c.can_attack())

func test_card_clear_stun_clears_out_of_play() -> void:
	var c := _card()
	c.summoning_sick = false
	c.attack_count = 1
	c.apply_status("stun", 2)
	c.clear_status("stun")
	assert_eq(c.out_of_play, 0)
	assert_true(c.can_attack())

func test_card_start_turn_decrements_stun_and_syncs_dict() -> void:
	var c := _card()
	c.apply_status("stun", 2)
	c.start_turn()
	assert_eq(c.out_of_play, 1)
	assert_eq(c.get_status_value("stun"), 1)

func test_card_start_turn_clears_stun_at_zero() -> void:
	var c := _card()
	c.apply_status("stun", 1)
	c.start_turn()
	assert_eq(c.out_of_play, 0)
	assert_false(c.has_status("stun"))

# ---------------------------------------------------------------------------
# HeroState status helpers
# ---------------------------------------------------------------------------

func test_hero_has_no_statuses_by_default() -> void:
	assert_false(_hero().has_status("poison"))

func test_hero_apply_and_get_status() -> void:
	var h := _hero()
	h.apply_status("freeze", 2)
	assert_true(h.has_status("freeze"))
	assert_eq(h.get_status_value("freeze"), 2)

func test_hero_clear_status() -> void:
	var h := _hero()
	h.apply_status("stun", 1)
	h.clear_status("stun")
	assert_false(h.has_status("stun"))

# ---------------------------------------------------------------------------
# HeroState armor absorption in take_damage
# ---------------------------------------------------------------------------

func test_hero_armor_absorbs_fully() -> void:
	var h := _hero()
	h.apply_status("armor", 10)
	h.take_damage(5)
	assert_eq(h.health, 30)
	assert_eq(h.get_status_value("armor"), 5)

func test_hero_armor_partial_and_damage_spills() -> void:
	var h := _hero()
	h.apply_status("armor", 3)
	h.take_damage(8)
	assert_false(h.has_status("armor"))
	assert_eq(h.health, 25)  # 8 - 3 = 5 damage, 30 - 5 = 25

func test_hero_take_damage_no_armor() -> void:
	var h := _hero()
	h.take_damage(10)
	assert_eq(h.health, 20)
