## Unit tests for PlayerIdentity — encode/decode round-trip and robust defaults.
extends "res://tests/framework/test_case.gd"

const PlayerIdentity = preload("res://game_logic/net/PlayerIdentity.gd")


# ---------------------------------------------------------------------------
# encode / decode round-trip
# ---------------------------------------------------------------------------

func test_round_trip_preserves_token() -> void:
	var payload: Array = PlayerIdentity.encode("abc123def456", "Maiteln", Color.RED)
	var d: Dictionary = PlayerIdentity.decode(payload)
	assert_eq(str(d["token"]), "abc123def456")


func test_round_trip_preserves_name() -> void:
	var payload: Array = PlayerIdentity.encode("tok", "Saimtar", Color.RED)
	var d: Dictionary = PlayerIdentity.decode(payload)
	assert_eq(str(d["name"]), "Saimtar")


func test_round_trip_preserves_color() -> void:
	var c := Color(0.2, 0.6, 0.9)
	var payload: Array = PlayerIdentity.encode("tok", "name", c)
	var d: Dictionary = PlayerIdentity.decode(payload)
	var out: Color = d["color"]
	# Hex round-trip is 8-bit per channel, so allow a small epsilon.
	assert_almost_eq(out.r, c.r, 0.01)
	assert_almost_eq(out.g, c.g, 0.01)
	assert_almost_eq(out.b, c.b, 0.01)


func test_encode_returns_three_elements() -> void:
	var payload: Array = PlayerIdentity.encode("t", "n", Color.WHITE)
	assert_eq(payload.size(), 3)


func test_color_serialised_as_hex_string() -> void:
	var payload: Array = PlayerIdentity.encode("t", "n", Color.RED)
	assert_true(payload[2] is String, "color must serialise to a String")


# ---------------------------------------------------------------------------
# decode defaults / robustness
# ---------------------------------------------------------------------------

func test_decode_empty_payload_defaults() -> void:
	var d: Dictionary = PlayerIdentity.decode([])
	assert_eq(str(d["token"]), "")
	assert_eq(str(d["name"]), "Player")
	assert_true(d.has("color"), "color key must always be present")


func test_decode_short_payload_defaults_name_and_color() -> void:
	var d: Dictionary = PlayerIdentity.decode(["onlytoken"])
	assert_eq(str(d["token"]), "onlytoken")
	assert_eq(str(d["name"]), "Player")


func test_decode_blank_name_falls_back() -> void:
	var d: Dictionary = PlayerIdentity.decode(["tok", "   ", "ff0000"])
	assert_eq(str(d["name"]), "Player")


func test_decode_invalid_color_hex_falls_back_to_white() -> void:
	var d: Dictionary = PlayerIdentity.decode(["tok", "name", "not-a-color"])
	var out: Color = d["color"]
	assert_almost_eq(out.r, 1.0)
	assert_almost_eq(out.g, 1.0)
	assert_almost_eq(out.b, 1.0)


func test_decode_always_returns_all_keys() -> void:
	var d: Dictionary = PlayerIdentity.decode(["t", "n", "00ff00"])
	assert_true(d.has("token"), "missing token")
	assert_true(d.has("name"), "missing name")
	assert_true(d.has("color"), "missing color")
