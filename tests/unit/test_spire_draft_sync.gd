## Unit tests for SpireDraftSync (GID-106 / TID-390) — encode/decode round-trips
## and garbage tolerance for the co-op Endless Spire alternating draft wire format.
## Mirrors test_loot_roll.gd structurally.
extends "res://tests/framework/test_case.gd"

const SpireDraftSync = preload("res://game_logic/net/SpireDraftSync.gd")


# ---------------------------------------------------------------------------
# encode_draft_start / decode_draft_start round-trip
# ---------------------------------------------------------------------------

func test_start_round_trip_preserves_all_fields() -> void:
	var payload: Dictionary = SpireDraftSync.encode_draft_start(
		3, ["ghost", "skeleton", "zombie"], "tok_a", "Alice")
	var d: Dictionary = SpireDraftSync.decode_draft_start(payload)
	assert_eq(int(d.get("floor", 0)), 3)
	assert_eq(d.get("options", []), ["ghost", "skeleton", "zombie"])
	assert_eq(str(d.get("active_picker_token", "")), "tok_a")
	assert_eq(str(d.get("active_picker_name", "")), "Alice")


func test_start_encode_stringifies_option_ids() -> void:
	var payload: Dictionary = SpireDraftSync.encode_draft_start(1, ["ghost", 42], "t", "n")
	var opts: Array = payload.get("options", [])
	assert_eq(opts, ["ghost", "42"])


func test_start_decode_garbage_returns_defaults() -> void:
	var d: Dictionary = SpireDraftSync.decode_draft_start({})
	assert_eq(int(d.get("floor", -1)), 0)
	assert_eq((d.get("options", []) as Array).size(), 0)
	assert_eq(str(d.get("active_picker_token", "x")), "")
	assert_eq(str(d.get("active_picker_name", "")), "Player")


func test_start_decode_non_dictionary_payload_does_not_throw() -> void:
	var d: Dictionary = SpireDraftSync.decode_draft_start("not a dict")
	assert_eq(int(d.get("floor", -1)), 0)
	assert_eq((d.get("options", []) as Array).size(), 0)


func test_start_decode_null_does_not_throw() -> void:
	var d: Dictionary = SpireDraftSync.decode_draft_start(null)
	assert_eq(int(d.get("floor", -1)), 0)


func test_start_decode_non_array_options_falls_back_to_empty() -> void:
	var d: Dictionary = SpireDraftSync.decode_draft_start({"floor": 2, "options": "not an array"})
	assert_eq(int(d.get("floor", 0)), 2)
	assert_eq((d.get("options", []) as Array).size(), 0)


# ---------------------------------------------------------------------------
# encode_draft_choice / decode_draft_choice round-trip
# ---------------------------------------------------------------------------

func test_choice_round_trip_preserves_all_fields() -> void:
	var payload: Array = SpireDraftSync.encode_draft_choice("ghost", "tok_b", "Bob")
	var d: Dictionary = SpireDraftSync.decode_draft_choice(payload)
	assert_eq(str(d.get("card_id", "")), "ghost")
	assert_eq(str(d.get("next_active_picker_token", "")), "tok_b")
	assert_eq(str(d.get("next_active_picker_name", "")), "Bob")


func test_choice_decode_garbage_returns_defaults() -> void:
	var d: Dictionary = SpireDraftSync.decode_draft_choice({})
	assert_eq(str(d.get("card_id", "x")), "")
	assert_eq(str(d.get("next_active_picker_token", "x")), "")
	assert_eq(str(d.get("next_active_picker_name", "")), "Player")


func test_choice_decode_empty_array_does_not_throw() -> void:
	var d: Dictionary = SpireDraftSync.decode_draft_choice([])
	assert_eq(str(d.get("card_id", "x")), "")


func test_choice_decode_non_array_payload_does_not_throw() -> void:
	var d: Dictionary = SpireDraftSync.decode_draft_choice("not an array")
	assert_eq(str(d.get("card_id", "x")), "")


func test_choice_decode_null_does_not_throw() -> void:
	var d: Dictionary = SpireDraftSync.decode_draft_choice(null)
	assert_eq(str(d.get("card_id", "x")), "")


func test_choice_decode_short_array_defaults_missing_fields() -> void:
	var d: Dictionary = SpireDraftSync.decode_draft_choice(["ghost"])
	assert_eq(str(d.get("card_id", "")), "ghost")
	assert_eq(str(d.get("next_active_picker_token", "x")), "")
	assert_eq(str(d.get("next_active_picker_name", "")), "Player")


func get_suite_name() -> String:
	return "SpireDraftSync"
