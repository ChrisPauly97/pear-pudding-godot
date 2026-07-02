## Unit tests for AuctionSync (GID-102 / TID-378) — the pure wire encode/decode
## helpers for the async card auction house. Mirrors test_trade_sync-style pure
## input/output coverage: round trips, defaults, garbage tolerance.
extends "res://tests/framework/test_case.gd"

const AuctionSync = preload("res://game_logic/net/AuctionSync.gd")


# ---------------------------------------------------------------------------
# List intent
# ---------------------------------------------------------------------------

func test_list_intent_round_trip() -> void:
	var encoded: Dictionary = AuctionSync.encode_list_intent("ghost_a_0", 150)
	var decoded: Dictionary = AuctionSync.decode_list_intent(encoded)
	assert_eq(decoded["card_uid"], "ghost_a_0")
	assert_eq(decoded["buyout"], 150)


func test_decode_list_intent_defaults_on_garbage() -> void:
	var decoded: Dictionary = AuctionSync.decode_list_intent("not-a-dict")
	assert_eq(decoded["card_uid"], "")
	assert_eq(decoded["buyout"], 0)


func test_decode_list_intent_defaults_on_missing_keys() -> void:
	var decoded: Dictionary = AuctionSync.decode_list_intent({})
	assert_eq(decoded["card_uid"], "")
	assert_eq(decoded["buyout"], 0)


# ---------------------------------------------------------------------------
# Bid intent
# ---------------------------------------------------------------------------

func test_bid_intent_round_trip() -> void:
	var encoded: Dictionary = AuctionSync.encode_bid_intent("auc_1", 75)
	var decoded: Dictionary = AuctionSync.decode_bid_intent(encoded)
	assert_eq(decoded["auction_id"], "auc_1")
	assert_eq(decoded["amount"], 75)


func test_decode_bid_intent_defaults_on_garbage() -> void:
	var decoded: Dictionary = AuctionSync.decode_bid_intent(null)
	assert_eq(decoded["auction_id"], "")
	assert_eq(decoded["amount"], 0)


# ---------------------------------------------------------------------------
# Id intent (buyout / cancel)
# ---------------------------------------------------------------------------

func test_id_intent_round_trip() -> void:
	var encoded: Dictionary = AuctionSync.encode_id_intent("auc_7")
	var decoded: Dictionary = AuctionSync.decode_id_intent(encoded)
	assert_eq(decoded["auction_id"], "auc_7")


func test_decode_id_intent_defaults_on_garbage() -> void:
	var decoded: Dictionary = AuctionSync.decode_id_intent(42)
	assert_eq(decoded["auction_id"], "")


# ---------------------------------------------------------------------------
# Listing normalization
# ---------------------------------------------------------------------------

func test_normalize_listing_fills_full_shape() -> void:
	var listing: Dictionary = AuctionSync.normalize_listing({
		"id": "auc_1", "seller_token": "tokA", "buyout": 100,
	})
	assert_eq(listing["id"], "auc_1")
	assert_eq(listing["seller_token"], "tokA")
	assert_eq(listing["seller_name"], "Player")
	assert_true(listing["card_instance"] is Dictionary)
	assert_eq(listing["buyout"], 100)
	assert_eq(listing["bid"], 0)
	assert_eq(listing["bidder_token"], "")
	assert_eq(listing["expires_day"], 0)
	assert_eq(listing["status"], AuctionSync.STATUS_ACTIVE)


func test_normalize_listing_tolerates_garbage() -> void:
	var listing: Dictionary = AuctionSync.normalize_listing("not-a-dict")
	assert_eq(listing["id"], "")
	assert_true(listing["card_instance"].is_empty())
	assert_eq(listing["status"], AuctionSync.STATUS_ACTIVE)


func test_normalize_listing_garbage_card_instance_falls_back_to_empty() -> void:
	var listing: Dictionary = AuctionSync.normalize_listing({"card_instance": "nope"})
	assert_true((listing["card_instance"] as Dictionary).is_empty())


# ---------------------------------------------------------------------------
# Snapshot
# ---------------------------------------------------------------------------

func test_decode_snapshot_normalizes_every_entry() -> void:
	var snapshot: Array = [
		{"id": "auc_1", "seller_token": "tokA"},
		{"id": "auc_2", "seller_token": "tokB", "status": AuctionSync.STATUS_SOLD},
	]
	var decoded: Array = AuctionSync.decode_snapshot(snapshot)
	assert_eq(decoded.size(), 2)
	assert_eq(str((decoded[0] as Dictionary).get("id", "")), "auc_1")
	assert_eq(str((decoded[1] as Dictionary).get("status", "")), AuctionSync.STATUS_SOLD)


func test_decode_snapshot_skips_non_dict_entries_by_normalizing_them_empty() -> void:
	var decoded: Array = AuctionSync.decode_snapshot(["garbage", 5])
	assert_eq(decoded.size(), 2)
	for entry in decoded:
		assert_eq(str((entry as Dictionary).get("id", "x")), "")


func test_decode_snapshot_non_array_returns_empty() -> void:
	var decoded: Array = AuctionSync.decode_snapshot("not-an-array")
	assert_true(decoded.is_empty())
