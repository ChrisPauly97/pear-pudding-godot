## Unit tests for AuctionTransfer (GID-102 / TID-378) — the pure listing/bid/
## buyout/cancel/expiry logic for the async card auction house. Mirrors
## test_stash_transfer.gd in style: pure inputs/outputs, no scene or
## SessionStore dependency.
extends "res://tests/framework/test_case.gd"

const AuctionTransfer = preload("res://game_logic/net/AuctionTransfer.gd")
const AuctionSync = preload("res://game_logic/net/AuctionSync.gd")

const _NORMAL_CARD_ID: String = "ghost"             # not is_unique
const _UNIQUE_CARD_ID: String = "sig_pack_leader"    # is_unique = true


func _member(token: String, uid: String, template_id: String, coins: int = 500, name: String = "Ada") -> Dictionary:
	return {
		"token": token,
		"display_name": name,
		"owned_cards": [
			{"uid": uid, "template_id": template_id, "rarity": "common",
			 "attack": 1, "health": 1, "cost": 1, "kills": 0,
			 "battles_survived": 0, "custom_name": ""},
		],
		"player_deck": [uid],
		"coins": coins,
	}


func _bare_member(token: String, coins: int = 500, name: String = "Bram") -> Dictionary:
	return {"token": token, "display_name": name, "owned_cards": [], "player_deck": [], "coins": coins}


# ---------------------------------------------------------------------------
# list_card
# ---------------------------------------------------------------------------

func test_list_card_escrows_instance_and_removes_from_owner() -> void:
	var seller: Dictionary = _member("tokA", "ghost_a_0", _NORMAL_CARD_ID)
	var result: Dictionary = AuctionTransfer.list_card([], seller, "tokA", "ghost_a_0", 100, 5)
	assert_true(bool(result.get("ok", false)))
	var member_out: Dictionary = result["member"]
	assert_true((member_out["owned_cards"] as Array).is_empty())
	assert_false((member_out["player_deck"] as Array).has("ghost_a_0"))
	var auctions: Array = result["auctions"]
	assert_eq(auctions.size(), 1)
	var listing: Dictionary = auctions[0]
	assert_eq(str(listing.get("seller_token", "")), "tokA")
	assert_eq(str(listing.get("seller_name", "")), "Ada")
	assert_eq(int(listing.get("buyout", 0)), 100)
	assert_eq(int(listing.get("bid", 0)), 0)
	assert_eq(int(listing.get("expires_day", 0)), 5)
	assert_eq(str(listing.get("status", "")), AuctionSync.STATUS_ACTIVE)


func test_list_card_rekeys_escrowed_uid() -> void:
	var seller: Dictionary = _member("tokA", "ghost_a_0", _NORMAL_CARD_ID)
	var result: Dictionary = AuctionTransfer.list_card([], seller, "tokA", "ghost_a_0", 100, 5)
	var card: Dictionary = (result["auctions"][0] as Dictionary)["card_instance"]
	var new_uid: String = str(card.get("uid", ""))
	assert_ne(new_uid, "ghost_a_0")
	assert_true(new_uid.begins_with("ghost_a_0"))


func test_list_card_blocks_unique_cards() -> void:
	var seller: Dictionary = _member("tokA", "sig_a_0", _UNIQUE_CARD_ID)
	var result: Dictionary = AuctionTransfer.list_card([], seller, "tokA", "sig_a_0", 100, 5)
	assert_false(bool(result.get("ok", false)))
	assert_eq(str(result.get("reason", "")), "unique")
	assert_eq((result["member"]["owned_cards"] as Array).size(), 1, "card stays with seller")


func test_list_card_no_ops_on_missing_card() -> void:
	var seller: Dictionary = _member("tokA", "ghost_a_0", _NORMAL_CARD_ID)
	var result: Dictionary = AuctionTransfer.list_card([], seller, "tokA", "nope", 100, 5)
	assert_false(bool(result.get("ok", false)))
	assert_eq(str(result.get("reason", "")), "not_found")


func test_list_card_blocks_non_positive_price() -> void:
	var seller: Dictionary = _member("tokA", "ghost_a_0", _NORMAL_CARD_ID)
	var result: Dictionary = AuctionTransfer.list_card([], seller, "tokA", "ghost_a_0", 0, 5)
	assert_false(bool(result.get("ok", false)))
	assert_eq(str(result.get("reason", "")), "invalid_price")


func test_list_card_ids_increment_and_never_collide() -> void:
	var seller: Dictionary = _member("tokA", "ghost_a_0", _NORMAL_CARD_ID)
	var r1: Dictionary = AuctionTransfer.list_card([], seller, "tokA", "ghost_a_0", 100, 5)
	var seller2: Dictionary = _member("tokA", "ghost_a_1", _NORMAL_CARD_ID)
	var r2: Dictionary = AuctionTransfer.list_card(r1["auctions"], seller2, "tokA", "ghost_a_1", 50, 5)
	var ids: Array = []
	for a in (r2["auctions"] as Array):
		ids.append(str((a as Dictionary).get("id", "")))
	assert_eq(ids.size(), 2)
	assert_ne(ids[0], ids[1])


# ---------------------------------------------------------------------------
# place_bid
# ---------------------------------------------------------------------------

func _listed_auctions(buyout: int = 100, expires_day: int = 5) -> Array:
	var seller: Dictionary = _member("tokSeller", "ghost_a_0", _NORMAL_CARD_ID)
	var result: Dictionary = AuctionTransfer.list_card([], seller, "tokSeller", "ghost_a_0", buyout, expires_day)
	return result["auctions"]


func test_place_bid_updates_listing() -> void:
	var auctions: Array = _listed_auctions()
	var id: String = str((auctions[0] as Dictionary).get("id", ""))
	var bidder: Dictionary = _bare_member("tokBidder", 200)
	var result: Dictionary = AuctionTransfer.place_bid(auctions, bidder, "tokBidder", id, 30)
	assert_true(bool(result.get("ok", false)))
	var listing: Dictionary = result["auctions"][0]
	assert_eq(int(listing.get("bid", 0)), 30)
	assert_eq(str(listing.get("bidder_token", "")), "tokBidder")


func test_place_bid_rejects_own_listing() -> void:
	var auctions: Array = _listed_auctions()
	var id: String = str((auctions[0] as Dictionary).get("id", ""))
	var seller_as_bidder: Dictionary = _bare_member("tokSeller", 200)
	var result: Dictionary = AuctionTransfer.place_bid(auctions, seller_as_bidder, "tokSeller", id, 30)
	assert_false(bool(result.get("ok", false)))
	assert_eq(str(result.get("reason", "")), "own_listing")


func test_place_bid_rejects_lower_than_current() -> void:
	var auctions: Array = _listed_auctions()
	var id: String = str((auctions[0] as Dictionary).get("id", ""))
	var bidder: Dictionary = _bare_member("tokBidder", 200)
	var r1: Dictionary = AuctionTransfer.place_bid(auctions, bidder, "tokBidder", id, 50)
	var r2: Dictionary = AuctionTransfer.place_bid(r1["auctions"], bidder, "tokBidder", id, 40)
	assert_false(bool(r2.get("ok", false)))
	assert_eq(str(r2.get("reason", "")), "bid_too_low")


func test_place_bid_rejects_insufficient_funds() -> void:
	var auctions: Array = _listed_auctions()
	var id: String = str((auctions[0] as Dictionary).get("id", ""))
	var poor_bidder: Dictionary = _bare_member("tokBidder", 10)
	var result: Dictionary = AuctionTransfer.place_bid(auctions, poor_bidder, "tokBidder", id, 30)
	assert_false(bool(result.get("ok", false)))
	assert_eq(str(result.get("reason", "")), "insufficient_funds")


func test_place_bid_not_found() -> void:
	var bidder: Dictionary = _bare_member("tokBidder", 200)
	var result: Dictionary = AuctionTransfer.place_bid([], bidder, "tokBidder", "nope", 30)
	assert_false(bool(result.get("ok", false)))
	assert_eq(str(result.get("reason", "")), "not_found")


# ---------------------------------------------------------------------------
# buyout
# ---------------------------------------------------------------------------

func test_buyout_moves_card_and_coins() -> void:
	var auctions: Array = _listed_auctions(120)
	var id: String = str((auctions[0] as Dictionary).get("id", ""))
	var seller: Dictionary = _member("tokSeller", "unused", _NORMAL_CARD_ID, 0)
	var buyer: Dictionary = _bare_member("tokBuyer", 200)
	var result: Dictionary = AuctionTransfer.buyout(auctions, buyer, "tokBuyer", seller, id)
	assert_true(bool(result.get("ok", false)))
	assert_eq(int(result["buyer"]["coins"]), 80)
	assert_eq(int(result["seller"]["coins"]), 120)
	var owned: Array = result["buyer"]["owned_cards"]
	assert_eq(owned.size(), 1)
	assert_eq(str((owned[0] as Dictionary).get("template_id", "")), _NORMAL_CARD_ID)
	var listing: Dictionary = result["auctions"][0]
	assert_eq(str(listing.get("status", "")), AuctionSync.STATUS_SOLD)
	assert_eq(str(listing.get("bidder_token", "")), "tokBuyer")


func test_buyout_rejects_own_listing() -> void:
	var auctions: Array = _listed_auctions(120)
	var id: String = str((auctions[0] as Dictionary).get("id", ""))
	var seller: Dictionary = _member("tokSeller", "unused", _NORMAL_CARD_ID, 0)
	var result: Dictionary = AuctionTransfer.buyout(auctions, seller, "tokSeller", seller, id)
	assert_false(bool(result.get("ok", false)))
	assert_eq(str(result.get("reason", "")), "own_listing")


func test_buyout_rejects_insufficient_funds() -> void:
	var auctions: Array = _listed_auctions(120)
	var id: String = str((auctions[0] as Dictionary).get("id", ""))
	var seller: Dictionary = _member("tokSeller", "unused", _NORMAL_CARD_ID, 0)
	var poor_buyer: Dictionary = _bare_member("tokBuyer", 10)
	var result: Dictionary = AuctionTransfer.buyout(auctions, poor_buyer, "tokBuyer", seller, id)
	assert_false(bool(result.get("ok", false)))
	assert_eq(str(result.get("reason", "")), "insufficient_funds")


func test_buyout_rejects_non_active_listing() -> void:
	var auctions: Array = _listed_auctions(120)
	var id: String = str((auctions[0] as Dictionary).get("id", ""))
	var seller: Dictionary = _member("tokSeller", "unused", _NORMAL_CARD_ID, 0)
	var buyer: Dictionary = _bare_member("tokBuyer", 200)
	var first: Dictionary = AuctionTransfer.buyout(auctions, buyer, "tokBuyer", seller, id)
	var second_buyer: Dictionary = _bare_member("tokBuyer2", 200)
	var second: Dictionary = AuctionTransfer.buyout(first["auctions"], second_buyer, "tokBuyer2", first["seller"], id)
	assert_false(bool(second.get("ok", false)))
	assert_eq(str(second.get("reason", "")), "not_active")


# ---------------------------------------------------------------------------
# cancel
# ---------------------------------------------------------------------------

func test_cancel_returns_card_to_seller() -> void:
	var auctions: Array = _listed_auctions(120)
	var id: String = str((auctions[0] as Dictionary).get("id", ""))
	var seller: Dictionary = _member("tokSeller", "unused", _NORMAL_CARD_ID, 0)
	seller["owned_cards"] = []  # already escrowed, mirror the post-list state
	var result: Dictionary = AuctionTransfer.cancel(auctions, seller, "tokSeller", id)
	assert_true(bool(result.get("ok", false)))
	var owned: Array = result["member"]["owned_cards"]
	assert_eq(owned.size(), 1)
	assert_eq(str((owned[0] as Dictionary).get("template_id", "")), _NORMAL_CARD_ID)
	var listing: Dictionary = result["auctions"][0]
	assert_eq(str(listing.get("status", "")), AuctionSync.STATUS_CANCELLED)


func test_cancel_rejects_non_owner() -> void:
	var auctions: Array = _listed_auctions(120)
	var id: String = str((auctions[0] as Dictionary).get("id", ""))
	var intruder: Dictionary = _bare_member("tokIntruder", 0)
	var result: Dictionary = AuctionTransfer.cancel(auctions, intruder, "tokIntruder", id)
	assert_false(bool(result.get("ok", false)))
	assert_eq(str(result.get("reason", "")), "not_owner")


func test_cancel_rejects_non_active_listing() -> void:
	var auctions: Array = _listed_auctions(120)
	var id: String = str((auctions[0] as Dictionary).get("id", ""))
	var seller: Dictionary = _member("tokSeller", "unused", _NORMAL_CARD_ID, 0)
	var first: Dictionary = AuctionTransfer.cancel(auctions, seller, "tokSeller", id)
	var second: Dictionary = AuctionTransfer.cancel(first["auctions"], first["member"], "tokSeller", id)
	assert_false(bool(second.get("ok", false)))
	assert_eq(str(second.get("reason", "")), "not_active")


# ---------------------------------------------------------------------------
# settle_expired
# ---------------------------------------------------------------------------

func test_settle_expired_ignores_listings_not_yet_due() -> void:
	var auctions: Array = _listed_auctions(120, 10)
	var members: Dictionary = {"tokSeller": _member("tokSeller", "unused", _NORMAL_CARD_ID, 0)}
	var result: Dictionary = AuctionTransfer.settle_expired(auctions, members, 3)
	var listing: Dictionary = result["auctions"][0]
	assert_eq(str(listing.get("status", "")), AuctionSync.STATUS_ACTIVE)


func test_settle_expired_with_bid_sells_to_highest_bidder() -> void:
	var auctions: Array = _listed_auctions(120, 3)
	var id: String = str((auctions[0] as Dictionary).get("id", ""))
	var bidder: Dictionary = _bare_member("tokBidder", 200)
	var bid_result: Dictionary = AuctionTransfer.place_bid(auctions, bidder, "tokBidder", id, 60)
	var members: Dictionary = {
		"tokSeller": _member("tokSeller", "unused", _NORMAL_CARD_ID, 0),
		"tokBidder": bidder,
	}
	var result: Dictionary = AuctionTransfer.settle_expired(bid_result["auctions"], members, 5)
	var listing: Dictionary = result["auctions"][0]
	assert_eq(str(listing.get("status", "")), AuctionSync.STATUS_SOLD)
	var new_members: Dictionary = result["members"]
	assert_eq(int((new_members["tokBidder"] as Dictionary).get("coins", -1)), 140, "bidder charged the bid amount")
	assert_eq(int((new_members["tokSeller"] as Dictionary).get("coins", -1)), 60, "seller credited the bid amount")
	var bidder_owned: Array = (new_members["tokBidder"] as Dictionary)["owned_cards"]
	assert_eq(bidder_owned.size(), 1)


func test_settle_expired_without_bid_returns_card_to_seller() -> void:
	var auctions: Array = _listed_auctions(120, 3)
	# Bare (card-less) seller record: _member() would seed an unrelated
	# pre-existing card, making the post-settle count 2 instead of the
	# returned card alone.
	var members: Dictionary = {"tokSeller": _bare_member("tokSeller", 0)}
	var result: Dictionary = AuctionTransfer.settle_expired(auctions, members, 5)
	var listing: Dictionary = result["auctions"][0]
	assert_eq(str(listing.get("status", "")), AuctionSync.STATUS_EXPIRED)
	var new_members: Dictionary = result["members"]
	var seller_owned: Array = (new_members["tokSeller"] as Dictionary)["owned_cards"]
	assert_eq(seller_owned.size(), 1, "card returned to the seller")


func test_settle_expired_bidder_who_can_no_longer_afford_it_falls_back_to_seller() -> void:
	var auctions: Array = _listed_auctions(120, 3)
	var id: String = str((auctions[0] as Dictionary).get("id", ""))
	var bidder: Dictionary = _bare_member("tokBidder", 200)
	var bid_result: Dictionary = AuctionTransfer.place_bid(auctions, bidder, "tokBidder", id, 60)
	# Bidder spent their coins elsewhere in the meantime (bid was record-only, not escrowed).
	var poorer_bidder: Dictionary = bidder.duplicate(true)
	poorer_bidder["coins"] = 10
	# Bare (card-less) seller record — see test_settle_expired_without_bid_returns_card_to_seller.
	var members: Dictionary = {
		"tokSeller": _bare_member("tokSeller", 0),
		"tokBidder": poorer_bidder,
	}
	var result: Dictionary = AuctionTransfer.settle_expired(bid_result["auctions"], members, 5)
	var listing: Dictionary = result["auctions"][0]
	assert_eq(str(listing.get("status", "")), AuctionSync.STATUS_EXPIRED, "falls back to expiry, not a sale")
	var new_members: Dictionary = result["members"]
	var seller_owned: Array = (new_members["tokSeller"] as Dictionary)["owned_cards"]
	assert_eq(seller_owned.size(), 1, "card returned to the seller")
	assert_eq(int((new_members["tokBidder"] as Dictionary).get("coins", -1)), 10, "bidder never charged")


func test_settle_expired_is_a_noop_when_nothing_is_due() -> void:
	var auctions: Array = _listed_auctions(120, 10)
	var members: Dictionary = {"tokSeller": _member("tokSeller", "unused", _NORMAL_CARD_ID, 0)}
	var result: Dictionary = AuctionTransfer.settle_expired(auctions, members, 0)
	assert_eq((result["auctions"] as Array).size(), 1)
	assert_eq(str((result["auctions"][0] as Dictionary).get("status", "")), AuctionSync.STATUS_ACTIVE)
