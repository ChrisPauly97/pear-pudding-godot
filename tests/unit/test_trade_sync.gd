## Unit tests for TradeSync (TID-366 / TID-432) — pure encode/decode helpers and
## the unique-card trade block. Mirrors test_stash_transfer.gd / test_auction_sync.gd
## in style: pure inputs/outputs, no scene or SessionStore dependency.
extends "res://tests/framework/test_case.gd"

const TradeSync = preload("res://game_logic/net/TradeSync.gd")

const _NORMAL_CARD_ID: String = "ghost"            # not is_unique
const _UNIQUE_CARD_ID: String = "sig_pack_leader"   # is_unique = true


# ---------------------------------------------------------------------------
# is_card_instance_unique
# ---------------------------------------------------------------------------

func test_is_card_instance_unique_false_for_normal_card() -> void:
	var card: Dictionary = {"uid": "ghost_a_0", "template_id": _NORMAL_CARD_ID}
	assert_false(TradeSync.is_card_instance_unique(card))


func test_is_card_instance_unique_true_for_unique_card() -> void:
	var card: Dictionary = {"uid": "sig_a_0", "template_id": _UNIQUE_CARD_ID}
	assert_true(TradeSync.is_card_instance_unique(card))


func test_is_card_instance_unique_false_for_missing_template_id() -> void:
	assert_false(TradeSync.is_card_instance_unique({"uid": "x"}))


# ---------------------------------------------------------------------------
# encode/decode offer + update (roundtrip)
# ---------------------------------------------------------------------------

func test_encode_decode_offer_roundtrip() -> void:
	var payload: Dictionary = TradeSync.encode_offer("t1", 1, 2, "ghost_a_0", 10, 5)
	var decoded: Dictionary = TradeSync.decode_offer(payload)
	assert_eq(str(decoded["trade_id"]), "t1")
	assert_eq(int(decoded["initiator_peer"]), 1)
	assert_eq(int(decoded["target_peer"]), 2)
	assert_eq(str(decoded["card_uid"]), "ghost_a_0")
	assert_eq(int(decoded["offer_coins"]), 10)
	assert_eq(int(decoded["request_coins"]), 5)


func test_decode_offer_tolerates_garbage_input() -> void:
	var decoded: Dictionary = TradeSync.decode_offer("not-a-dict")
	assert_eq(str(decoded["trade_id"]), "")
	assert_eq(int(decoded["initiator_peer"]), -1)


func test_encode_decode_update_roundtrip() -> void:
	var payload: Dictionary = TradeSync.encode_update("t1", TradeSync.STATUS_COMPLETED, {"card_uid": "ghost_a_0"})
	var decoded: Dictionary = TradeSync.decode_update(payload)
	assert_eq(str(decoded["trade_id"]), "t1")
	assert_eq(str(decoded["status"]), TradeSync.STATUS_COMPLETED)
