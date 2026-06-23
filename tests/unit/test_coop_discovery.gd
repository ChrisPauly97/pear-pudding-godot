## Unit tests for NetworkManager LAN-discovery wire format (GID-090 / TID-327).
## Pure static helpers — no sockets, no autoload state.
extends "res://tests/framework/test_case.gd"

const NM = preload("res://autoloads/NetworkManager.gd")


func test_query_round_trip() -> void:
	var q: PackedByteArray = NM.build_discovery_query()
	assert_true(NM.is_discovery_query(q), "query should be recognised")


func test_is_query_rejects_other_text() -> void:
	assert_false(NM.is_discovery_query("not a query".to_utf8_buffer()))


func test_reply_round_trip_preserves_fields() -> void:
	var pkt: PackedByteArray = NM.build_discovery_reply("My Host", 24565, "madrian", 2)
	var d: Dictionary = NM.parse_discovery_reply(pkt, "192.168.1.5")
	assert_eq(str(d["name"]), "My Host")
	assert_eq(int(d["game_port"]), 24565)
	assert_eq(str(d["map"]), "madrian")
	assert_eq(int(d["players"]), 2)


func test_parse_uses_socket_ip_not_payload() -> void:
	# The IP must come from the observed socket address, never the payload.
	var pkt: PackedByteArray = NM.build_discovery_reply("H", 1, "m", 1)
	var d: Dictionary = NM.parse_discovery_reply(pkt, "10.0.0.9")
	assert_eq(str(d["ip"]), "10.0.0.9")


func test_parse_rejects_non_json() -> void:
	var d: Dictionary = NM.parse_discovery_reply("garbage".to_utf8_buffer(), "1.2.3.4")
	assert_true(d.is_empty(), "non-JSON should yield empty dict")


func test_parse_rejects_wrong_tag() -> void:
	var pkt: PackedByteArray = JSON.stringify({"tag": "SOMETHING_ELSE"}).to_utf8_buffer()
	var d: Dictionary = NM.parse_discovery_reply(pkt, "1.2.3.4")
	assert_true(d.is_empty(), "wrong tag should yield empty dict")


func test_parse_defaults_missing_fields() -> void:
	var pkt: PackedByteArray = JSON.stringify({"tag": "PPTCG_HOST"}).to_utf8_buffer()
	var d: Dictionary = NM.parse_discovery_reply(pkt, "1.2.3.4")
	assert_false(d.is_empty(), "valid tag should parse even with missing fields")
	assert_eq(int(d["players"]), 1)
	assert_eq(str(d["name"]), "Host")
