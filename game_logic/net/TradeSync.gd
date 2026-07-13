## Pure encode/decode helpers for co-op card trading (TID-366).
## Scene-free, unit-testable — mirrors AvatarSync.gd.
## All payloads are JSON-primitive Dictionaries for RPC safety.
extends RefCounted

const _CardRegistry = preload("res://autoloads/CardRegistry.gd")

## Trade status values sent in recv_trade_update payloads.
const STATUS_PROPOSED:  String = "proposed"
const STATUS_COMPLETED: String = "completed"
const STATUS_CANCELLED: String = "cancelled"


## True if a resolved card instance dict (from owned_cards, with a
## `template_id` field) is unique per its template — mirrors
## StashTransfer/AuctionTransfer's `is_unique` check exactly (TID-432).
## Unique cards are blocked from trading, same as crafting/selling/stashing.
static func is_card_instance_unique(card_inst: Dictionary) -> bool:
	var template_id: String = str(card_inst.get("template_id", ""))
	return bool(_CardRegistry.get_template(template_id).get("is_unique", false))


## Encode a trade offer. The authority echoes this back with STATUS_PROPOSED so
## both parties see the pending offer.
##   card_uid        — UID of the card instance being offered; "" for a pure coin gift.
##   offer_coins     — coins the initiator pays on top of (or instead of) a card.
##   request_coins   — coins the initiator requests in return (for trades, not gifts).
static func encode_offer(
	trade_id: String,
	initiator_peer: int,
	target_peer: int,
	card_uid: String,
	offer_coins: int,
	request_coins: int
) -> Dictionary:
	return {
		"trade_id":       trade_id,
		"initiator_peer": initiator_peer,
		"target_peer":    target_peer,
		"card_uid":       card_uid,
		"offer_coins":    offer_coins,
		"request_coins":  request_coins,
	}


## Encode an outcome update broadcast by the authority.
static func encode_update(trade_id: String, status: String, detail: Dictionary = {}) -> Dictionary:
	var d: Dictionary = {"trade_id": trade_id, "status": status}
	d.merge(detail)
	return d


## Decode a trade offer dict; returns safe defaults for any missing key.
static func decode_offer(data: Variant) -> Dictionary:
	var d: Dictionary = {}
	if data is Dictionary:
		d = data as Dictionary
	return {
		"trade_id":       str(d.get("trade_id", "")),
		"initiator_peer": int(d.get("initiator_peer", -1)),
		"target_peer":    int(d.get("target_peer", -1)),
		"card_uid":       str(d.get("card_uid", "")),
		"offer_coins":    int(d.get("offer_coins", 0)),
		"request_coins":  int(d.get("request_coins", 0)),
	}


## Decode a status update dict; returns safe defaults.
static func decode_update(data: Variant) -> Dictionary:
	var d: Dictionary = {}
	if data is Dictionary:
		d = data as Dictionary
	return {
		"trade_id": str(d.get("trade_id", "")),
		"status":   str(d.get("status", "")),
	}
