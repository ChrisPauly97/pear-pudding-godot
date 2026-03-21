## Unit tests for ZoneState.
##
## Covers board slot management (add, remove, full/empty detection, first-empty
## indexing), the get_cards filtered view, snapshot/restore semantics, and the
## start_turn delegation to resident cards.
extends "res://tests/framework/test_case.gd"

const CardInstance = preload("res://game_logic/battle/CardInstance.gd")
const ZoneState = preload("res://game_logic/battle/ZoneState.gd")

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

func _card(id: String = "ghost") -> CardInstance:
	return CardInstance.from_template({
		"id": id,
		"name": id.capitalize(),
		"cost": 1,
		"attack": 1,
		"health": 2,
		"card_class": "minion",
		"description": "",
	})


func _zone() -> ZoneState:
	return ZoneState.new()


func _fill_zone(zone: ZoneState) -> Array:
	var cards := []
	for i in range(ZoneState.SLOT_COUNT):
		var c = _card("card_%d" % i)
		zone.add_card(c)
		cards.append(c)
	return cards


# ---------------------------------------------------------------------------
# Initial state
# ---------------------------------------------------------------------------

func test_new_zone_has_five_slots() -> void:
	assert_eq(_zone().slots.size(), ZoneState.SLOT_COUNT)


func test_new_zone_all_slots_empty() -> void:
	var zone = _zone()
	for s in zone.slots:
		assert_null(s)


func test_new_zone_is_not_full() -> void:
	assert_false(_zone().is_full())


func test_new_zone_first_empty_slot_is_zero() -> void:
	assert_eq(_zone().first_empty_slot(), 0)


# ---------------------------------------------------------------------------
# add_card
# ---------------------------------------------------------------------------

func test_add_card_returns_true_when_slot_available() -> void:
	assert_true(_zone().add_card(_card()))


func test_add_card_places_in_first_slot() -> void:
	var zone = _zone()
	var c = _card()
	zone.add_card(c)
	assert_eq(zone.slots[0], c)


func test_add_card_advances_first_empty_slot() -> void:
	var zone = _zone()
	zone.add_card(_card())
	assert_eq(zone.first_empty_slot(), 1)


func test_add_card_returns_false_when_zone_full() -> void:
	var zone = _zone()
	_fill_zone(zone)
	assert_false(zone.add_card(_card("overflow")))


func test_add_card_does_not_change_state_when_full() -> void:
	var zone = _zone()
	_fill_zone(zone)
	zone.add_card(_card("overflow"))
	assert_eq(zone.get_cards().size(), ZoneState.SLOT_COUNT)


# ---------------------------------------------------------------------------
# is_full / first_empty_slot
# ---------------------------------------------------------------------------

func test_is_full_after_filling_all_slots() -> void:
	var zone = _zone()
	_fill_zone(zone)
	assert_true(zone.is_full())


func test_first_empty_slot_returns_minus_one_when_full() -> void:
	var zone = _zone()
	_fill_zone(zone)
	assert_eq(zone.first_empty_slot(), -1)


func test_first_empty_slot_after_partial_fill() -> void:
	var zone = _zone()
	zone.add_card(_card())
	zone.add_card(_card())
	assert_eq(zone.first_empty_slot(), 2)


# ---------------------------------------------------------------------------
# remove_card
# ---------------------------------------------------------------------------

func test_remove_card_returns_true_when_present() -> void:
	var zone = _zone()
	var c = _card()
	zone.add_card(c)
	assert_true(zone.remove_card(c))


func test_remove_card_nullifies_slot() -> void:
	var zone = _zone()
	var c = _card()
	zone.add_card(c)
	zone.remove_card(c)
	assert_null(zone.slots[0])


func test_remove_card_returns_false_when_absent() -> void:
	var zone = _zone()
	assert_false(zone.remove_card(_card()))


func test_remove_card_makes_zone_not_full() -> void:
	var zone = _zone()
	var cards = _fill_zone(zone)
	zone.remove_card(cards[0])
	assert_false(zone.is_full())


func test_removing_middle_card_leaves_correct_gaps() -> void:
	var zone = _zone()
	var cards = []
	for i in range(3):
		var c = _card("c%d" % i)
		zone.add_card(c)
		cards.append(c)
	zone.remove_card(cards[1])  # remove middle
	assert_not_null(zone.slots[0])
	assert_null(zone.slots[1])
	assert_not_null(zone.slots[2])


# ---------------------------------------------------------------------------
# get_cards
# ---------------------------------------------------------------------------

func test_get_cards_empty_zone_returns_empty_array() -> void:
	assert_eq(_zone().get_cards().size(), 0)


func test_get_cards_returns_all_added_cards() -> void:
	var zone = _zone()
	_fill_zone(zone)
	assert_eq(zone.get_cards().size(), ZoneState.SLOT_COUNT)


func test_get_cards_excludes_null_slots() -> void:
	var zone = _zone()
	var cards = _fill_zone(zone)
	zone.remove_card(cards[2])
	assert_eq(zone.get_cards().size(), ZoneState.SLOT_COUNT - 1)


func test_get_cards_contains_the_correct_card() -> void:
	var zone = _zone()
	var c = _card("target")
	zone.add_card(c)
	assert_has(zone.get_cards(), c)


# ---------------------------------------------------------------------------
# snapshot / restore_snapshot
# ---------------------------------------------------------------------------

func test_restore_snapshot_reverts_added_card() -> void:
	var zone = _zone()
	zone.snapshot()
	zone.add_card(_card())
	zone.restore_snapshot()
	assert_eq(zone.get_cards().size(), 0)


func test_restore_snapshot_reverts_removed_card() -> void:
	var zone = _zone()
	var c = _card()
	zone.add_card(c)
	zone.snapshot()
	zone.remove_card(c)
	zone.restore_snapshot()
	assert_eq(zone.get_cards().size(), 1)


func test_snapshot_is_independent_of_further_changes() -> void:
	var zone = _zone()
	zone.add_card(_card("a"))
	zone.snapshot()
	zone.add_card(_card("b"))
	zone.add_card(_card("c"))
	zone.restore_snapshot()
	assert_eq(zone.get_cards().size(), 1)


# ---------------------------------------------------------------------------
# start_turn
# ---------------------------------------------------------------------------

func test_start_turn_clears_summoning_sickness_on_all_cards() -> void:
	var zone = _zone()
	for _i in range(3):
		zone.add_card(_card())
	zone.start_turn()
	for c in zone.get_cards():
		assert_false(c.summoning_sick)


func test_start_turn_restores_attack_count() -> void:
	var zone = _zone()
	var c = _card()
	c.summoning_sick = false
	c.attack_count = 0
	zone.add_card(c)
	zone.start_turn()
	assert_eq(c.attack_count, 1)
