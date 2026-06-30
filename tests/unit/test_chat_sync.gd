## Unit tests for ChatSync (GID-102 / TID-374) — quick-chat and free-text encode/decode
## round-trips, length cap, control-character stripping, map-filter field, robust
## defaults on garbage/short payloads. Mirrors test_social_sync.gd.
extends "res://tests/framework/test_case.gd"

const ChatSync = preload("res://game_logic/net/ChatSync.gd")


# ---------------------------------------------------------------------------
# Quick-chat encode / decode
# ---------------------------------------------------------------------------

func test_encode_quick_returns_three_elements() -> void:
	var p: Array = ChatSync.encode_quick("Nice!", "madrian")
	assert_eq(p.size(), 3)


func test_quick_round_trip_preserves_text_kind_and_map() -> void:
	var p: Array = ChatSync.encode_quick("Need help", "maykalene")
	var d: Dictionary = ChatSync.decode(p)
	assert_eq(str(d.get("text", "")), "Need help")
	assert_eq(str(d.get("kind", "")), ChatSync.KIND_QUICK)
	assert_eq(str(d.get("map", "")), "maykalene")


func test_quick_round_trip_all_preset_ids() -> void:
	for preset: String in ChatSync.QUICK_PRESETS:
		var p: Array = ChatSync.encode_quick(preset, "madrian")
		var d: Dictionary = ChatSync.decode(p)
		assert_eq(str(d.get("text", "")), preset,
			"round-trip failed for preset '%s'" % preset)


func test_quick_unknown_preset_falls_back_to_first() -> void:
	var p: Array = ChatSync.encode_quick("not a real preset", "madrian")
	var d: Dictionary = ChatSync.decode(p)
	assert_eq(str(d.get("text", "")), ChatSync.QUICK_PRESETS[0])


func test_quick_default_map_is_empty_string() -> void:
	var p: Array = ChatSync.encode_quick("Wait")
	var d: Dictionary = ChatSync.decode(p)
	assert_eq(str(d.get("map", "x")), "")


# ---------------------------------------------------------------------------
# Free-text encode / decode
# ---------------------------------------------------------------------------

func test_encode_text_returns_three_elements() -> void:
	var p: Array = ChatSync.encode_text("hello there", "madrian")
	assert_eq(p.size(), 3)


func test_text_round_trip_preserves_text_kind_and_map() -> void:
	var p: Array = ChatSync.encode_text("hello party", "dungeon_a")
	var d: Dictionary = ChatSync.decode(p)
	assert_eq(str(d.get("text", "")), "hello party")
	assert_eq(str(d.get("kind", "")), ChatSync.KIND_TEXT)
	assert_eq(str(d.get("map", "")), "dungeon_a")


func test_text_default_map_is_empty_string() -> void:
	var p: Array = ChatSync.encode_text("hi")
	var d: Dictionary = ChatSync.decode(p)
	assert_eq(str(d.get("map", "x")), "")


func test_text_empty_string_round_trips_to_empty() -> void:
	var p: Array = ChatSync.encode_text("", "madrian")
	var d: Dictionary = ChatSync.decode(p)
	assert_eq(str(d.get("text", "x")), "")


# ---------------------------------------------------------------------------
# Length cap
# ---------------------------------------------------------------------------

func test_text_over_cap_is_truncated_to_max_len() -> void:
	var long_text: String = "a".repeat(200)
	var p: Array = ChatSync.encode_text(long_text, "madrian")
	var d: Dictionary = ChatSync.decode(p)
	assert_eq(str(d.get("text", "")).length(), ChatSync.MAX_TEXT_LEN)


func test_text_exactly_at_cap_is_unchanged() -> void:
	var exact_text: String = "b".repeat(ChatSync.MAX_TEXT_LEN)
	var p: Array = ChatSync.encode_text(exact_text, "madrian")
	var d: Dictionary = ChatSync.decode(p)
	assert_eq(str(d.get("text", "")).length(), ChatSync.MAX_TEXT_LEN)
	assert_eq(str(d.get("text", "")), exact_text)


func test_text_under_cap_is_unchanged() -> void:
	var short_text: String = "short message"
	var p: Array = ChatSync.encode_text(short_text, "madrian")
	var d: Dictionary = ChatSync.decode(p)
	assert_eq(str(d.get("text", "")), short_text)


func test_decode_also_enforces_cap_on_oversized_payload_text() -> void:
	# Simulate a forged/garbled payload whose text field bypasses encode_text().
	var forged: Array = ["c".repeat(500), ChatSync.KIND_TEXT, "madrian"]
	var d: Dictionary = ChatSync.decode(forged)
	assert_eq(str(d.get("text", "")).length(), ChatSync.MAX_TEXT_LEN)


# ---------------------------------------------------------------------------
# Control character stripping
# ---------------------------------------------------------------------------

func test_text_strips_control_characters() -> void:
	var dirty: String = "helloworld"
	var p: Array = ChatSync.encode_text(dirty, "madrian")
	var d: Dictionary = ChatSync.decode(p)
	assert_eq(str(d.get("text", "")), "helloworld")


func test_text_strips_newlines_and_tabs() -> void:
	var dirty: String = "line1\nline2\ttabbed"
	var p: Array = ChatSync.encode_text(dirty, "madrian")
	var d: Dictionary = ChatSync.decode(p)
	assert_eq(str(d.get("text", "")), "line1line2tabbed")


func test_text_strips_del_character() -> void:
	var dirty: String = "abcdef"
	var p: Array = ChatSync.encode_text(dirty, "madrian")
	var d: Dictionary = ChatSync.decode(p)
	assert_eq(str(d.get("text", "")), "abcdef")


func test_text_preserves_normal_punctuation_and_spaces() -> void:
	var clean: String = "Hello, party! Let's go - 100%?"
	var p: Array = ChatSync.encode_text(clean, "madrian")
	var d: Dictionary = ChatSync.decode(p)
	assert_eq(str(d.get("text", "")), clean)


# ---------------------------------------------------------------------------
# Garbage / empty payload tolerance
# ---------------------------------------------------------------------------

func test_decode_garbage_string_returns_defaults() -> void:
	var d: Dictionary = ChatSync.decode("not-an-array")
	assert_eq(str(d.get("text", "x")), "")
	assert_eq(str(d.get("kind", "")), ChatSync.KIND_TEXT)
	assert_eq(str(d.get("map", "x")), "")


func test_decode_null_returns_defaults() -> void:
	var d: Dictionary = ChatSync.decode(null)
	assert_eq(str(d.get("text", "x")), "")
	assert_eq(str(d.get("kind", "")), ChatSync.KIND_TEXT)
	assert_eq(str(d.get("map", "x")), "")


func test_decode_empty_array_returns_defaults() -> void:
	var d: Dictionary = ChatSync.decode([])
	assert_eq(str(d.get("text", "x")), "")
	assert_eq(str(d.get("kind", "")), ChatSync.KIND_TEXT)
	assert_eq(str(d.get("map", "x")), "")


func test_decode_single_element_array_defaults_kind_and_map() -> void:
	var d: Dictionary = ChatSync.decode(["hi"])
	assert_eq(str(d.get("text", "")), "hi")
	assert_eq(str(d.get("kind", "")), ChatSync.KIND_TEXT)
	assert_eq(str(d.get("map", "x")), "")


func test_decode_invalid_kind_falls_back_to_text() -> void:
	var d: Dictionary = ChatSync.decode(["hi", "bogus_kind", "madrian"])
	assert_eq(str(d.get("kind", "")), ChatSync.KIND_TEXT)


func test_decode_does_not_throw_on_dictionary_payload() -> void:
	var d: Dictionary = ChatSync.decode({"not": "an array"})
	assert_eq(str(d.get("text", "x")), "")


# ---------------------------------------------------------------------------
# Constants sanity
# ---------------------------------------------------------------------------

func test_quick_presets_not_empty() -> void:
	assert_gt(ChatSync.QUICK_PRESETS.size(), 0)


func test_max_text_len_positive() -> void:
	assert_gt(ChatSync.MAX_TEXT_LEN, 0)


func test_log_max_lines_positive() -> void:
	assert_gt(ChatSync.LOG_MAX_LINES, 0)
