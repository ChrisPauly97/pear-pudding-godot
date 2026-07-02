## Pure business logic for the async card auction house (GID-102 / TID-378).
##
## Generalizes the dupe-proof re-key mechanic `StashTransfer.gd` uses for the
## member <-> stash move to a **member <-> listing <-> member** move: listing
## escrows a card instance into the listing dict (removed from the seller's
## owned_cards, like a stash deposit); buyout/settlement re-keys it into the
## winner's namespace and moves coins seller <-> buyer.
##
## Pure, scene-free, RefCounted — no SessionStore/SessionState dependency, so it
## is fully unit-testable (mirrors StashTransfer/TradeSync). Callers (WorldScene)
## pass in plain dicts/arrays (member character records, the session's `auctions`
## array) and receive updated copies back to write onto the live SessionState +
## mark it dirty.
##
## Callers: preload("res://game_logic/net/AuctionTransfer.gd").
extends RefCounted

const _CardRegistry = preload("res://autoloads/CardRegistry.gd")
const _AuctionSync = preload("res://game_logic/net/AuctionSync.gd")

## Highest-bidder settlement (buyout or expiry) never fails on a coin edge case
## silently — the bid is only ever "record-only" (never escrowed from the
## bidder up front), so settlement re-validates the bidder can still afford it.


## List a card for sale. Escrows the card instance out of the seller's
## owned_cards (+ deck, if present) into a new listing dict, blocking unique
## cards exactly like trade/stash. Returns:
##   {ok: bool, reason: String, auctions: Array, member: Dictionary}
## `auctions`/`member` are updated copies to write back; on failure they are the
## unmodified inputs (duplicated) so callers can always safely overwrite with them.
static func list_card(
	auctions: Array, seller_rec: Dictionary, seller_token: String,
	card_uid: String, buyout: int, expires_day: int
) -> Dictionary:
	var auctions_out: Array = auctions.duplicate(true)
	var member_out: Dictionary = seller_rec.duplicate(true)
	if card_uid == "":
		return {"ok": false, "reason": "no_uid", "auctions": auctions_out, "member": member_out}
	if buyout <= 0:
		return {"ok": false, "reason": "invalid_price", "auctions": auctions_out, "member": member_out}

	var owned: Array = member_out.get("owned_cards", []) as Array
	var card_inst: Dictionary = {}
	var found_idx: int = -1
	for i: int in range(owned.size()):
		var c: Variant = owned[i]
		if c is Dictionary and str((c as Dictionary).get("uid", "")) == card_uid:
			found_idx = i
			card_inst = (c as Dictionary).duplicate(true)
			break
	if found_idx == -1:
		return {"ok": false, "reason": "not_found", "auctions": auctions_out, "member": member_out}

	var template_id: String = str(card_inst.get("template_id", ""))
	var tmpl: Dictionary = _CardRegistry.get_template(template_id)
	if bool(tmpl.get("is_unique", false)):
		return {"ok": false, "reason": "unique", "auctions": auctions_out, "member": member_out}

	owned.remove_at(found_idx)
	var deck: Array = member_out.get("player_deck", []) as Array
	deck.erase(card_uid)
	member_out["owned_cards"] = owned
	member_out["player_deck"] = deck

	var listing_id: String = _next_id(auctions_out)
	card_inst["uid"] = "%s_auc_%s" % [card_uid, listing_id]
	auctions_out.append({
		"id": listing_id,
		"seller_token": seller_token,
		"seller_name": str(seller_rec.get("display_name", "Player")),
		"card_instance": card_inst,
		"buyout": buyout,
		"bid": 0,
		"bidder_token": "",
		"expires_day": expires_day,
		"status": _AuctionSync.STATUS_ACTIVE,
	})

	return {"ok": true, "reason": "", "auctions": auctions_out, "member": member_out}


## Place a bid on an active listing. Record-only — no coins move (and no
## card moves) until buyout/settlement, so only the auctions array changes.
## Returns {ok: bool, reason: String, auctions: Array}.
static func place_bid(
	auctions: Array, bidder_rec: Dictionary, bidder_token: String,
	auction_id: String, amount: int
) -> Dictionary:
	var auctions_out: Array = auctions.duplicate(true)
	if amount <= 0:
		return {"ok": false, "reason": "invalid_amount", "auctions": auctions_out}
	var idx: int = _find_index(auctions_out, auction_id)
	if idx == -1:
		return {"ok": false, "reason": "not_found", "auctions": auctions_out}
	var listing: Dictionary = auctions_out[idx]
	if str(listing.get("status", "")) != _AuctionSync.STATUS_ACTIVE:
		return {"ok": false, "reason": "not_active", "auctions": auctions_out}
	if str(listing.get("seller_token", "")) == bidder_token:
		return {"ok": false, "reason": "own_listing", "auctions": auctions_out}
	if amount <= int(listing.get("bid", 0)):
		return {"ok": false, "reason": "bid_too_low", "auctions": auctions_out}
	if int(bidder_rec.get("coins", 0)) < amount:
		return {"ok": false, "reason": "insufficient_funds", "auctions": auctions_out}

	listing["bid"] = amount
	listing["bidder_token"] = bidder_token
	auctions_out[idx] = listing
	return {"ok": true, "reason": "", "auctions": auctions_out}


## Buy a listing outright at its buyout price. Moves the escrowed card to the
## buyer (re-keyed into their namespace) and the buyout price from buyer to
## seller. Returns {ok, reason, auctions, buyer, seller} — `buyer`/`seller` are
## updated copies to write back (unmodified duplicates on failure).
static func buyout(
	auctions: Array, buyer_rec: Dictionary, buyer_token: String,
	seller_rec: Dictionary, auction_id: String
) -> Dictionary:
	var auctions_out: Array = auctions.duplicate(true)
	var buyer_out: Dictionary = buyer_rec.duplicate(true)
	var seller_out: Dictionary = seller_rec.duplicate(true)
	var idx: int = _find_index(auctions_out, auction_id)
	if idx == -1:
		return {"ok": false, "reason": "not_found", "auctions": auctions_out, "buyer": buyer_out, "seller": seller_out}
	var listing: Dictionary = auctions_out[idx]
	if str(listing.get("status", "")) != _AuctionSync.STATUS_ACTIVE:
		return {"ok": false, "reason": "not_active", "auctions": auctions_out, "buyer": buyer_out, "seller": seller_out}
	if str(listing.get("seller_token", "")) == buyer_token:
		return {"ok": false, "reason": "own_listing", "auctions": auctions_out, "buyer": buyer_out, "seller": seller_out}
	var price: int = int(listing.get("buyout", 0))
	if int(buyer_out.get("coins", 0)) < price:
		return {"ok": false, "reason": "insufficient_funds", "auctions": auctions_out, "buyer": buyer_out, "seller": seller_out}

	buyer_out["coins"] = int(buyer_out.get("coins", 0)) - price
	seller_out["coins"] = int(seller_out.get("coins", 0)) + price

	var card_inst: Dictionary = (listing.get("card_instance", {}) as Dictionary).duplicate(true)
	card_inst["uid"] = str(card_inst.get("uid", auction_id)) + "_w_" + buyer_token.substr(0, 4)
	var owned: Array = buyer_out.get("owned_cards", []) as Array
	owned.append(card_inst)
	buyer_out["owned_cards"] = owned

	listing["status"] = _AuctionSync.STATUS_SOLD
	listing["bidder_token"] = buyer_token
	listing["card_instance"] = {}
	auctions_out[idx] = listing

	return {"ok": true, "reason": "", "auctions": _prune_completed(auctions_out), "buyer": buyer_out, "seller": seller_out}


## Cancel your own active listing, returning the escrowed card to you. A no-op
## (ok=false) for anyone but the seller, or for a non-active listing (an
## existing bid does not block cancellation — the bid was never escrowed).
## Returns {ok, reason, auctions, member}.
static func cancel(
	auctions: Array, seller_rec: Dictionary, seller_token: String, auction_id: String
) -> Dictionary:
	var auctions_out: Array = auctions.duplicate(true)
	var member_out: Dictionary = seller_rec.duplicate(true)
	var idx: int = _find_index(auctions_out, auction_id)
	if idx == -1:
		return {"ok": false, "reason": "not_found", "auctions": auctions_out, "member": member_out}
	var listing: Dictionary = auctions_out[idx]
	if str(listing.get("status", "")) != _AuctionSync.STATUS_ACTIVE:
		return {"ok": false, "reason": "not_active", "auctions": auctions_out, "member": member_out}
	if str(listing.get("seller_token", "")) != seller_token:
		return {"ok": false, "reason": "not_owner", "auctions": auctions_out, "member": member_out}

	var card_inst: Dictionary = (listing.get("card_instance", {}) as Dictionary).duplicate(true)
	card_inst["uid"] = str(card_inst.get("uid", auction_id)) + "_ret"
	var owned: Array = member_out.get("owned_cards", []) as Array
	owned.append(card_inst)
	member_out["owned_cards"] = owned

	listing["status"] = _AuctionSync.STATUS_CANCELLED
	listing["card_instance"] = {}
	auctions_out[idx] = listing

	return {"ok": true, "reason": "", "auctions": _prune_completed(auctions_out), "member": member_out}


## Host-tick sweep: settle every active listing whose `expires_day` has passed.
## A listing with a standing bid whose bidder can still afford it sells to them
## (same coin/card move as buyout); otherwise the card returns to the seller and
## the listing is marked "expired". `members` is the full token -> record roster;
## only entries actually touched are modified. Returns {auctions, members} —
## always full (possibly unmodified) copies, safe to write straight back.
static func settle_expired(auctions: Array, members: Dictionary, current_day: int) -> Dictionary:
	var auctions_out: Array = auctions.duplicate(true)
	var members_out: Dictionary = members.duplicate(true)
	for i: int in range(auctions_out.size()):
		var listing: Dictionary = auctions_out[i]
		if str(listing.get("status", "")) != _AuctionSync.STATUS_ACTIVE:
			continue
		if int(listing.get("expires_day", 0)) > current_day:
			continue

		var seller_token: String = str(listing.get("seller_token", ""))
		var bidder_token: String = str(listing.get("bidder_token", ""))
		var bid_amount: int = int(listing.get("bid", 0))
		var seller_rec: Variant = members_out.get(seller_token, null)
		var bidder_rec: Variant = members_out.get(bidder_token, null) if bidder_token != "" else null

		if bid_amount > 0 and bidder_rec is Dictionary \
				and int((bidder_rec as Dictionary).get("coins", 0)) >= bid_amount:
			var bidder_out: Dictionary = (bidder_rec as Dictionary).duplicate(true)
			bidder_out["coins"] = int(bidder_out.get("coins", 0)) - bid_amount
			var card_inst: Dictionary = (listing.get("card_instance", {}) as Dictionary).duplicate(true)
			card_inst["uid"] = str(card_inst.get("uid", listing.get("id", ""))) + "_w_" + bidder_token.substr(0, 4)
			var owned: Array = bidder_out.get("owned_cards", []) as Array
			owned.append(card_inst)
			bidder_out["owned_cards"] = owned
			members_out[bidder_token] = bidder_out

			if seller_rec is Dictionary:
				var seller_out: Dictionary = (seller_rec as Dictionary).duplicate(true)
				seller_out["coins"] = int(seller_out.get("coins", 0)) + bid_amount
				members_out[seller_token] = seller_out

			listing["status"] = _AuctionSync.STATUS_SOLD
			listing["card_instance"] = {}
		else:
			# No standing bid (or the bidder can no longer afford it): return
			# the card to the seller, if they still exist in the roster.
			if seller_rec is Dictionary:
				var seller_out2: Dictionary = (seller_rec as Dictionary).duplicate(true)
				var card_inst2: Dictionary = (listing.get("card_instance", {}) as Dictionary).duplicate(true)
				card_inst2["uid"] = str(card_inst2.get("uid", listing.get("id", ""))) + "_ret"
				var owned2: Array = seller_out2.get("owned_cards", []) as Array
				owned2.append(card_inst2)
				seller_out2["owned_cards"] = owned2
				members_out[seller_token] = seller_out2
			listing["status"] = _AuctionSync.STATUS_EXPIRED
			listing["card_instance"] = {}
		auctions_out[i] = listing

	return {"auctions": _prune_completed(auctions_out), "members": members_out}


# ---------------------------------------------------------------------------
# Internals
# ---------------------------------------------------------------------------

static func _find_index(auctions: Array, auction_id: String) -> int:
	if auction_id == "":
		return -1
	for i: int in range(auctions.size()):
		var a: Variant = auctions[i]
		if a is Dictionary and str((a as Dictionary).get("id", "")) == auction_id:
			return i
	return -1


## Deterministic, collision-free listing id — no wall-clock/random dependency,
## so listing creation stays fully unit-testable. Derives the next id from the
## highest existing numeric suffix rather than `auctions.size()`, so ids stay
## unique even after completed listings are pruned.
static func _next_id(auctions: Array) -> String:
	var max_n: int = 0
	for a: Variant in auctions:
		if a is Dictionary:
			var id_str: String = str((a as Dictionary).get("id", ""))
			if id_str.begins_with("auc_"):
				var n: int = int(id_str.substr(4))
				if n > max_n:
					max_n = n
	return "auc_%d" % (max_n + 1)


## Cap of completed (sold/cancelled/expired) listings kept around for the "My
## Listings" history view, oldest-first trimmed — bounds the persisted session
## file's growth over a long-running party, mirrors PVE_LEADERBOARD_CAP.
const _COMPLETED_CAP: int = 30

static func _prune_completed(auctions: Array) -> Array:
	var active: Array = []
	var completed: Array = []
	for a: Variant in auctions:
		if a is Dictionary and str((a as Dictionary).get("status", "")) == _AuctionSync.STATUS_ACTIVE:
			active.append(a)
		else:
			completed.append(a)
	if completed.size() > _COMPLETED_CAP:
		completed = completed.slice(completed.size() - _COMPLETED_CAP, completed.size())
	var out: Array = []
	out.append_array(active)
	out.append_array(completed)
	return out
