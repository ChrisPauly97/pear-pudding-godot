## Unit tests for GID-069 TID-253: DeckAutoFill heuristic.
extends "res://tests/framework/test_case.gd"

const DeckAutoFill = preload("res://game_logic/DeckAutoFill.gd")
const IsoConst = preload("res://autoloads/IsoConst.gd")

func _make_inst(uid: String, tid: String, rarity: String, cost: int) -> Dictionary:
	return {"uid": uid, "template_id": tid, "rarity": rarity, "cost": cost}

# ---------------------------------------------------------------------------

func test_fill_empty_deck_to_min() -> void:
	var available: Array[Dictionary] = []
	for i in range(IsoConst.DECK_MIN + 2):
		available.append(_make_inst("u%d" % i, "ghost", "common", 1))
	var result: Array[String] = DeckAutoFill.fill([], available, IsoConst.DECK_MIN)
	assert_eq(result.size(), IsoConst.DECK_MIN, "should fill to DECK_MIN")

func test_fill_does_not_exceed_target() -> void:
	var available: Array[Dictionary] = []
	for i in range(20):
		available.append(_make_inst("u%d" % i, "ghost", "common", 1))
	var result: Array[String] = DeckAutoFill.fill([], available, 5)
	assert_eq(result.size(), 5, "should not exceed target size")

func test_fill_no_duplicates() -> void:
	var available: Array[Dictionary] = []
	for i in range(15):
		available.append(_make_inst("u%d" % i, "ghost", "common", 1))
	var result: Array[String] = DeckAutoFill.fill([], available, 10)
	var seen: Dictionary = {}
	for uid: String in result:
		assert_false(seen.has(uid), "no duplicate UIDs in filled deck")
		seen[uid] = true

func test_fill_skips_already_in_deck() -> void:
	var working: Array[String] = ["u0", "u1"]
	var available: Array[Dictionary] = []
	for i in range(5):
		available.append(_make_inst("u%d" % i, "ghost", "common", 1))
	var result: Array[String] = DeckAutoFill.fill(working, available, 5)
	assert_false(result.count("u0") > 1, "u0 should not be added twice")
	assert_false(result.count("u1") > 1, "u1 should not be added twice")

func test_fill_prefers_higher_rarity() -> void:
	var available: Array[Dictionary] = [
		_make_inst("leg", "ghost", "legendary", 3),
		_make_inst("com1", "ghost", "common", 3),
		_make_inst("com2", "ghost", "common", 3),
	]
	var result: Array[String] = DeckAutoFill.fill([], available, 1)
	assert_eq(result[0], "leg", "legendary should be preferred over common")

func test_fill_returns_copy_of_input_when_already_at_target() -> void:
	var working: Array[String] = ["u0", "u1", "u2"]
	var available: Array[Dictionary] = [_make_inst("u3", "ghost", "common", 1)]
	var result: Array[String] = DeckAutoFill.fill(working, available, 3)
	assert_eq(result.size(), 3, "should not exceed target when already at it")

func test_fill_empty_available_returns_working_deck() -> void:
	var working: Array[String] = ["u0", "u1"]
	var result: Array[String] = DeckAutoFill.fill(working, [], 10)
	assert_eq(result.size(), 2, "cannot exceed what is available")
