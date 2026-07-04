## Unit tests for GID-098 / TID-356 co-op shared story flags.
##
## Tests the data model that underpins flag synchronisation:
##   - SessionState.story_flags persistence through to_dict/from_dict.
##   - Idempotency rule: receiving the same flag+value pair a second time is safe.
##   - Snapshot semantics: flags dict is preserved through serialisation.
extends "res://tests/framework/test_case.gd"

const SessionState = preload("res://game_logic/net/SessionState.gd")


# ---------------------------------------------------------------------------
# SessionState.story_flags — the shared source of truth the authority updates
# ---------------------------------------------------------------------------

func test_story_flags_default_empty() -> void:
	var s := SessionState.new()
	assert_true(s.story_flags.is_empty(), "story_flags should default to empty")


func test_story_flags_survive_round_trip() -> void:
	var s := SessionState.new()
	s.story_flags["chapter1_left_madrian"] = true
	s.story_flags["tutorial_done"] = true
	var restored := SessionState.new()
	restored.from_dict(s.to_dict())
	assert_true(bool(restored.story_flags.get("chapter1_left_madrian", false)),
		"chapter1_left_madrian must survive round-trip")
	assert_true(bool(restored.story_flags.get("tutorial_done", false)),
		"tutorial_done must survive round-trip")


func test_story_flags_false_value_survives_round_trip() -> void:
	var s := SessionState.new()
	s.story_flags["some_flag"] = false
	var restored := SessionState.new()
	restored.from_dict(s.to_dict())
	assert_false(bool(restored.story_flags.get("some_flag", true)),
		"false flag value must survive round-trip")


func test_story_flags_garbage_input_defaults_to_empty() -> void:
	# If the session data carries a non-dict story_flags, from_dict must not crash.
	var data: Dictionary = {"session_id": "x", "members": {}, "story_flags": 42}
	var s := SessionState.new()
	s.from_dict(data)
	assert_true(s.story_flags.is_empty(), "non-dict story_flags must fall back to empty")


# ---------------------------------------------------------------------------
# Idempotency rule — authority skips broadcast if flag is already at the same value
# ---------------------------------------------------------------------------

func test_idempotent_flag_set_same_value_is_noop() -> void:
	# Simulate: the authority receives a client submit for a flag already at value.
	# The authority should detect the value is unchanged and skip the broadcast.
	var flags: Dictionary = {"chapter1_left_madrian": true}
	var key: String = "chapter1_left_madrian"
	var value: bool = true
	var already_set: bool = (flags.get(key, false) == value)
	assert_true(already_set, "idempotency check must detect no-op update")


func test_idempotent_flag_set_different_value_is_not_noop() -> void:
	var flags: Dictionary = {"chapter1_left_madrian": false}
	var key: String = "chapter1_left_madrian"
	var value: bool = true
	var already_set: bool = (flags.get(key, false) == value)
	assert_false(already_set, "a value change must not be skipped")


func test_idempotent_flag_new_key_is_not_noop() -> void:
	var flags: Dictionary = {}
	var key: String = "new_flag"
	var value: bool = true
	var already_set: bool = (flags.get(key, false) == value)
	assert_false(already_set, "a new key must not be treated as a no-op")


# ---------------------------------------------------------------------------
# Snapshot serialisation — flags dict passed via recv_story_flags_snapshot RPC
# ---------------------------------------------------------------------------

func test_snapshot_preserves_multiple_flags() -> void:
	# Simulates encoding a snapshot dict and decoding it on the receiving peer.
	var flags: Dictionary = {
		"chapter1_left_madrian": true,
		"intro_scroll_read": true,
		"tavern_quest_started": false,
	}
	# Duplicate as the RPC code does.
	var wire: Dictionary = flags.duplicate()
	assert_eq(wire.size(), 3)
	assert_true(bool(wire.get("chapter1_left_madrian", false)))
	assert_false(bool(wire.get("tavern_quest_started", true)))


func test_snapshot_empty_dict_is_valid() -> void:
	var wire: Dictionary = {}.duplicate()
	assert_true(wire.is_empty(), "empty snapshot must not crash the receiver")


func test_snapshot_bool_coercion() -> void:
	# In a Dictionary from JSON/Godot serialisation, values may arrive as ints.
	# The receiver applies bool(flags[key]) — verify that works correctly.
	var flags: Dictionary = {"f": 1, "g": 0}
	assert_true(bool(flags["f"]), "int 1 must coerce to bool true")
	assert_false(bool(flags["g"]), "int 0 must coerce to bool false")
