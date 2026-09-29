## Unit tests for the consumable quick slots (GID-136 / TID-542).
extends "res://tests/framework/test_case.gd"

const _QuickSlots = preload("res://game_logic/battle/QuickSlots.gd")
const _CombatTuning = preload("res://game_logic/battle/CombatTuning.gd")
const SaveManagerScript = preload("res://autoloads/SaveManager.gd")


func test_turn_cooldown_spans_three_of_your_turns() -> void:
	var q := _QuickSlots.new()
	assert_true(q.is_ready(1, false))
	q.start(2, 0.0)
	assert_false(q.is_ready(2, false), "same turn")
	assert_false(q.is_ready(4, false))
	assert_eq(q.remaining(3, false), 2)
	assert_true(q.is_ready(5, false), "ready three turns later")


func test_realtime_cooldown_counts_seconds() -> void:
	var q := _QuickSlots.new()
	q.start(1, 20.0)
	assert_false(q.is_ready(99, true), "turn number is irrelevant in real time")
	q.tick(19.5)
	assert_eq(q.remaining(0, true), 1)
	q.tick(1.0)
	assert_true(q.is_ready(0, true))


func test_resolve_fills_empty_and_exhausted_slots() -> void:
	var potions: Dictionary = {"healing_draught": 2, "clarity_brew": 0, "ember_tonic": 1}
	var ids: Array[String] = _QuickSlots.resolve(["", ""], potions)
	assert_eq(ids, ["healing_draught", "ember_tonic"] as Array[String])
	ids = _QuickSlots.resolve(["ember_tonic", "clarity_brew"], potions)
	assert_eq(ids, ["ember_tonic", "healing_draught"] as Array[String], "exhausted clarity replaced")
	assert_eq(_QuickSlots.resolve(["bogus"], {}), ["", ""] as Array[String])


func test_assign_moves_a_potion_between_slots() -> void:
	var slots: Array[String] = _QuickSlots.assign(["healing_draught", ""], 1, "healing_draught")
	assert_eq(slots, ["", "healing_draught"] as Array[String])
	assert_eq(_QuickSlots.assign([], 0, "ember_tonic").size(), _QuickSlots.SLOTS)


func test_slots_are_persisted_and_tuned() -> void:
	assert_true(SaveManagerScript.PERSISTED_FIELDS.has("quick_slots"))
	assert_eq(_QuickSlots.KEYS.size(), _QuickSlots.SLOTS)
	assert_eq(_CombatTuning.new().get_f("potion_cooldown"), 20.0)
