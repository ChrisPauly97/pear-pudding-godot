## Unit tests for SocialSync (GID-101 / TID-365) — emote and ping encode/decode
## round-trips, map-filter field, robust defaults on garbage/short payloads.
extends "res://tests/framework/test_case.gd"

const SocialSync = preload("res://game_logic/net/SocialSync.gd")


# ---------------------------------------------------------------------------
# Emote encode / decode
# ---------------------------------------------------------------------------

func test_encode_emote_returns_two_elements() -> void:
	var p: Array = SocialSync.encode_emote("greet", "madrian")
	assert_eq(p.size(), 2)


func test_emote_round_trip_preserves_id_and_map() -> void:
	var p: Array = SocialSync.encode_emote("thanks", "maykalene")
	var d: Dictionary = SocialSync.decode_emote(p)
	assert_eq(str(d.get("emote_id", "")), "thanks")
	assert_eq(str(d.get("map", "")), "maykalene")


func test_emote_round_trip_all_preset_ids() -> void:
	for eid: String in SocialSync.EMOTE_IDS:
		var p: Array = SocialSync.encode_emote(eid, "madrian")
		var d: Dictionary = SocialSync.decode_emote(p)
		assert_eq(str(d.get("emote_id", "")), eid,
			"round-trip failed for emote_id '%s'" % eid)


func test_emote_default_map_is_empty_string() -> void:
	var p: Array = SocialSync.encode_emote("laugh")
	var d: Dictionary = SocialSync.decode_emote(p)
	assert_eq(str(d.get("map", "x")), "")


func test_decode_emote_garbage_returns_defaults() -> void:
	var d: Dictionary = SocialSync.decode_emote("not-an-array")
	assert_eq(str(d.get("emote_id", "x")), "")
	assert_eq(str(d.get("map", "x")), "")


func test_decode_emote_empty_array_returns_defaults() -> void:
	var d: Dictionary = SocialSync.decode_emote([])
	assert_eq(str(d.get("emote_id", "x")), "")
	assert_eq(str(d.get("map", "x")), "")


func test_decode_emote_single_element_array_defaults_map() -> void:
	var d: Dictionary = SocialSync.decode_emote(["help"])
	assert_eq(str(d.get("emote_id", "")), "help")
	assert_eq(str(d.get("map", "x")), "")


func test_emote_labels_cover_all_preset_ids() -> void:
	for eid: String in SocialSync.EMOTE_IDS:
		assert_true(SocialSync.EMOTE_LABELS.has(eid),
			"EMOTE_LABELS missing key '%s'" % eid)


# ---------------------------------------------------------------------------
# Ping encode / decode
# ---------------------------------------------------------------------------

func test_encode_ping_returns_five_elements() -> void:
	var p: Array = SocialSync.encode_ping(12.5, -3.0, SocialSync.PING_PLACE, "ff0000", "madrian")
	assert_eq(p.size(), 5)


func test_ping_round_trip_preserves_coords_kind_color_map() -> void:
	var p: Array = SocialSync.encode_ping(7.25, -9.5, SocialSync.PING_ENEMY, "00ff00", "dungeon_a")
	var d: Dictionary = SocialSync.decode_ping(p)
	assert_almost_eq(float(d.get("x", 0.0)), 7.25)
	assert_almost_eq(float(d.get("z", 0.0)), -9.5)
	assert_eq(str(d.get("kind", "")), SocialSync.PING_ENEMY)
	assert_eq(str(d.get("color_hex", "")), "00ff00")
	assert_eq(str(d.get("map", "")), "dungeon_a")


func test_ping_default_map_is_empty_string() -> void:
	var p: Array = SocialSync.encode_ping(0.0, 0.0, SocialSync.PING_PLACE, "ffffff")
	var d: Dictionary = SocialSync.decode_ping(p)
	assert_eq(str(d.get("map", "x")), "")


func test_decode_ping_garbage_returns_defaults() -> void:
	var d: Dictionary = SocialSync.decode_ping(null)
	assert_almost_eq(float(d.get("x", 99.0)), 0.0)
	assert_almost_eq(float(d.get("z", 99.0)), 0.0)
	assert_eq(str(d.get("kind", "")), SocialSync.PING_PLACE)
	assert_eq(str(d.get("color_hex", "")), "ffffff")
	assert_eq(str(d.get("map", "x")), "")


func test_decode_ping_empty_array_returns_defaults() -> void:
	var d: Dictionary = SocialSync.decode_ping([])
	assert_almost_eq(float(d.get("x", 99.0)), 0.0)
	assert_almost_eq(float(d.get("z", 99.0)), 0.0)


func test_decode_ping_partial_array_fills_missing_fields() -> void:
	# Only x and z provided; kind/color/map fall back to defaults.
	var d: Dictionary = SocialSync.decode_ping([5.0, 3.0])
	assert_almost_eq(float(d.get("x", 0.0)), 5.0)
	assert_almost_eq(float(d.get("z", 0.0)), 3.0)
	assert_eq(str(d.get("kind", "")), SocialSync.PING_PLACE)
	assert_eq(str(d.get("color_hex", "")), "ffffff")


func test_ping_negative_coords_survive_round_trip() -> void:
	var p: Array = SocialSync.encode_ping(-100.0, -200.0, SocialSync.PING_PLACE, "aabbcc", "madrian")
	var d: Dictionary = SocialSync.decode_ping(p)
	assert_almost_eq(float(d.get("x", 0.0)), -100.0)
	assert_almost_eq(float(d.get("z", 0.0)), -200.0)


# ---------------------------------------------------------------------------
# Constants sanity
# ---------------------------------------------------------------------------

func test_emote_ids_not_empty() -> void:
	assert_gt(SocialSync.EMOTE_IDS.size(), 0)


func test_emote_duration_positive() -> void:
	assert_gt(SocialSync.EMOTE_DURATION, 0.0)


func test_ping_duration_positive() -> void:
	assert_gt(SocialSync.PING_DURATION, 0.0)
