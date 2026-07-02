## Pure encode/decode helpers for the async card auction house (GID-102 / TID-378).
## Scene-free, unit-testable — mirrors TradeSync.gd / StashTransfer.gd.
## All payloads are JSON-primitive Dictionaries/Arrays for RPC safety.
extends RefCounted

## Listing status values carried in each listing dict and in recv_auction_update.
const STATUS_ACTIVE:    String = "active"
const STATUS_SOLD:      String = "sold"
const STATUS_CANCELLED: String = "cancelled"
const STATUS_EXPIRED:   String = "expired"

## Days a fresh listing stays active before the host-tick expiry sweep settles it
## (to the highest bidder, or back to the seller if there is no bid).
const LISTING_DURATION_DAYS: int = 3


## Encode a "list a card" intent (client -> authority).
static func encode_list_intent(card_uid: String, buyout: int) -> Dictionary:
	return {"card_uid": card_uid, "buyout": buyout}


## Decode a "list a card" intent; returns safe defaults for any missing key.
static func decode_list_intent(data: Variant) -> Dictionary:
	var d: Dictionary = data as Dictionary if data is Dictionary else {}
	return {
		"card_uid": str(d.get("card_uid", "")),
		"buyout":   int(d.get("buyout", 0)),
	}


## Encode a "place a bid" intent (client -> authority).
static func encode_bid_intent(auction_id: String, amount: int) -> Dictionary:
	return {"auction_id": auction_id, "amount": amount}


## Decode a "place a bid" intent; returns safe defaults for any missing key.
static func decode_bid_intent(data: Variant) -> Dictionary:
	var d: Dictionary = data as Dictionary if data is Dictionary else {}
	return {
		"auction_id": str(d.get("auction_id", "")),
		"amount":     int(d.get("amount", 0)),
	}


## Encode a "buyout" or "cancel" intent (client -> authority) — both need only the id.
static func encode_id_intent(auction_id: String) -> Dictionary:
	return {"auction_id": auction_id}


## Decode a "buyout" or "cancel" intent; returns safe defaults for any missing key.
static func decode_id_intent(data: Variant) -> Dictionary:
	var d: Dictionary = data as Dictionary if data is Dictionary else {}
	return {"auction_id": str(d.get("auction_id", ""))}


## Normalize one listing dict to its full, defaulted wire shape. Used both when
## building a fresh listing and when decoding a received snapshot entry, so a
## garbage/legacy entry can never crash a caller that assumes the shape.
static func normalize_listing(data: Variant) -> Dictionary:
	var d: Dictionary = data as Dictionary if data is Dictionary else {}
	var card: Variant = d.get("card_instance", {})
	return {
		"id":            str(d.get("id", "")),
		"seller_token":  str(d.get("seller_token", "")),
		"seller_name":   str(d.get("seller_name", "Player")),
		"card_instance": (card as Dictionary).duplicate(true) if card is Dictionary else {},
		"buyout":        int(d.get("buyout", 0)),
		"bid":           int(d.get("bid", 0)),
		"bidder_token":  str(d.get("bidder_token", "")),
		"expires_day":   int(d.get("expires_day", 0)),
		"status":        str(d.get("status", STATUS_ACTIVE)),
	}


## Decode a full listings snapshot (recv_auction_update payload) into normalized
## listing dicts. Any non-Array input decodes to an empty snapshot.
static func decode_snapshot(data: Variant) -> Array:
	var out: Array = []
	if data is Array:
		for entry: Variant in (data as Array):
			out.append(normalize_listing(entry))
	return out
