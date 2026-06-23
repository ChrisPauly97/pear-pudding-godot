## Unit tests for BattleNetProtocol — intent + state-mirror encode/decode (GID-091).
extends "res://tests/framework/test_case.gd"

const Proto = preload("res://game_logic/net/BattleNetProtocol.gd")


# ---------------------------------------------------------------------------
# Intent round-trips
# ---------------------------------------------------------------------------

func test_play_card_at_slot_round_trip() -> void:
	var p: Dictionary = Proto.encode_play_card_at_slot(2, 4)
	var d: Dictionary = Proto.decode_intent(p)
	assert_eq(d["type"], Proto.INTENT_PLAY_CARD_AT_SLOT)
	assert_eq(int(d["hand_index"]), 2)
	assert_eq(int(d["slot_idx"]), 4)


func test_play_spell_untargeted_round_trip() -> void:
	var p: Dictionary = Proto.encode_play_spell(1)
	var d: Dictionary = Proto.decode_intent(p)
	assert_eq(d["type"], Proto.INTENT_PLAY_SPELL)
	assert_eq(int(d["hand_index"]), 1)
	var tgt: Dictionary = d["target"]
	assert_true(tgt.is_empty(), "untargeted spell should have empty target")


func test_play_spell_targeted_round_trip() -> void:
	var p: Dictionary = Proto.encode_play_spell(0, {"side": 0, "slot": 3})
	var d: Dictionary = Proto.decode_intent(p)
	var tgt: Dictionary = d["target"]
	assert_eq(int(tgt["side"]), 0)
	assert_eq(int(tgt["slot"]), 3)


func test_attack_minion_round_trip() -> void:
	var p: Dictionary = Proto.encode_attack(1, 2)
	var d: Dictionary = Proto.decode_intent(p)
	assert_eq(d["type"], Proto.INTENT_ATTACK)
	assert_eq(int(d["attacker_slot"]), 1)
	assert_eq(int(d["target_slot"]), 2)


func test_attack_hero_round_trip() -> void:
	var p: Dictionary = Proto.encode_attack(3, Proto.TARGET_HERO)
	var d: Dictionary = Proto.decode_intent(p)
	assert_eq(int(d["attacker_slot"]), 3)
	assert_eq(int(d["target_slot"]), Proto.TARGET_HERO)


func test_end_turn_round_trip() -> void:
	var d: Dictionary = Proto.decode_intent(Proto.encode_end_turn())
	assert_eq(d["type"], Proto.INTENT_END_TURN)


func test_hero_power_round_trip() -> void:
	var d: Dictionary = Proto.decode_intent(Proto.encode_hero_power({"side": 1, "slot": 0}))
	assert_eq(d["type"], Proto.INTENT_HERO_POWER)
	var tgt: Dictionary = d["target"]
	assert_eq(int(tgt["slot"]), 0)


func test_potion_round_trip() -> void:
	var d: Dictionary = Proto.decode_intent(Proto.encode_potion("heal_minor"))
	assert_eq(d["type"], Proto.INTENT_POTION)
	assert_eq(str(d["potion_id"]), "heal_minor")


func test_surrender_round_trip() -> void:
	var d: Dictionary = Proto.decode_intent(Proto.encode_surrender())
	assert_eq(d["type"], Proto.INTENT_SURRENDER)


# ---------------------------------------------------------------------------
# Robust decode of garbage / unknown
# ---------------------------------------------------------------------------

func test_decode_unknown_type_is_empty() -> void:
	var d: Dictionary = Proto.decode_intent({"type": "explode_everything"})
	assert_eq(d["type"], "", "unknown intent type should decode to empty")


func test_decode_non_dictionary_is_empty() -> void:
	var d: Dictionary = Proto.decode_intent("not a dict")
	assert_eq(d["type"], "")


func test_decode_empty_dict_is_empty() -> void:
	var d: Dictionary = Proto.decode_intent({})
	assert_eq(d["type"], "")


func test_decode_always_has_all_keys() -> void:
	var d: Dictionary = Proto.decode_intent({})
	for k in ["type", "hand_index", "slot_idx", "attacker_slot", "target_slot", "target", "potion_id"]:
		assert_true(d.has(k), "decoded intent missing key %s" % k)


# ---------------------------------------------------------------------------
# State mirror round-trip
# ---------------------------------------------------------------------------

func test_state_round_trip_preserves_seq() -> void:
	var state := {"current_player_idx": 1, "turn_number": 5}
	var payload: Dictionary = Proto.encode_state(state, 42)
	var decoded: Dictionary = Proto.decode_state(payload)
	assert_true(decoded["valid"])
	assert_eq(int(decoded["seq"]), 42)


func test_state_round_trip_preserves_state() -> void:
	var state := {"current_player_idx": 1, "turn_number": 5, "players": [{"player_id": 0}]}
	var payload: Dictionary = Proto.encode_state(state, 1)
	var decoded: Dictionary = Proto.decode_state(payload)
	var s: Dictionary = decoded["state"]
	assert_eq(int(s["current_player_idx"]), 1)
	assert_eq(int(s["turn_number"]), 5)


func test_decode_state_garbage_is_invalid() -> void:
	var decoded: Dictionary = Proto.decode_state("nope")
	assert_false(decoded["valid"])


func test_decode_state_missing_state_is_invalid() -> void:
	var decoded: Dictionary = Proto.decode_state({"seq": 3})
	assert_false(decoded["valid"])
