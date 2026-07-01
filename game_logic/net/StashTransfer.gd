## Pure card/coin transfer helpers for the shared party stash (GID-102 / TID-376).
##
## Generalizes the dupe-proof re-key mechanic `WorldScene._transfer_card_in_session`
## already uses for peer-to-peer trading (GID-101 / TID-366) to a **member <-> stash**
## move: deposit re-keys a card instance's uid into a stash-namespaced uid; withdraw
## re-keys it into the withdrawing member's namespace. This keeps exactly one instance
## dict alive per card at all times — never duplicated, never lost.
##
## Pure, scene-free, RefCounted — no SessionStore/SessionState dependency, so it is
## fully unit-testable (mirrors `CardInstanceUtil` / `RatingMath`). Callers (WorldScene)
## pass in plain dicts (a member character record, the shared stash dict) and receive
## updated copies back to write onto the live `SessionState` + mark it dirty.
##
## This is also the plumbing TID-378 (auction house) is expected to reuse for
## member <-> listing moves — kept generic on purpose (no stash-specific naming baked
## into the low-level uid re-key logic beyond the "_stash_" / "_w_" suffixes).
##
## Callers: preload("res://game_logic/net/StashTransfer.gd").
extends RefCounted

const _CardRegistry = preload("res://autoloads/CardRegistry.gd")


## Move a card instance from a member's owned_cards (+ deck, if present) into the
## shared stash. Blocks unique cards (`is_unique` on the card's template), exactly
## like card trading. Returns:
##   {ok: bool, reason: String, stash: Dictionary, member: Dictionary}
## `stash`/`member` are updated copies to write back; on failure they are the
## unmodified inputs (duplicated) so callers can always safely overwrite with them.
static func deposit_card(stash: Dictionary, member_rec: Dictionary, card_uid: String) -> Dictionary:
	var stash_out: Dictionary = _normalized_stash(stash)
	var member_out: Dictionary = member_rec.duplicate(true)
	if card_uid == "":
		return {"ok": false, "reason": "no_uid", "stash": stash_out, "member": member_out}

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
		return {"ok": false, "reason": "not_found", "stash": stash_out, "member": member_out}

	var template_id: String = str(card_inst.get("template_id", ""))
	var tmpl: Dictionary = _CardRegistry.get_template(template_id)
	if bool(tmpl.get("is_unique", false)):
		return {"ok": false, "reason": "unique", "stash": stash_out, "member": member_out}

	owned.remove_at(found_idx)
	var deck: Array = member_out.get("player_deck", []) as Array
	deck.erase(card_uid)
	member_out["owned_cards"] = owned
	member_out["player_deck"] = deck

	var stash_cards: Array = stash_out.get("cards", []) as Array
	var new_uid: String = "%s_stash_%d" % [card_uid, stash_cards.size()]
	card_inst["uid"] = new_uid
	stash_cards.append(card_inst)
	stash_out["cards"] = stash_cards

	return {"ok": true, "reason": "", "stash": stash_out, "member": member_out}


## Move a card instance from the shared stash into a member's owned_cards. Re-keys the
## uid into the member's namespace so it can never collide with another member's
## instance salted the same way (mirrors the trading gift-uid convention). Returns the
## same {ok, reason, stash, member} shape as deposit_card.
static func withdraw_card(stash: Dictionary, member_rec: Dictionary, stash_uid: String, member_token: String) -> Dictionary:
	var stash_out: Dictionary = _normalized_stash(stash)
	var member_out: Dictionary = member_rec.duplicate(true)
	if stash_uid == "":
		return {"ok": false, "reason": "no_uid", "stash": stash_out, "member": member_out}

	var stash_cards: Array = stash_out.get("cards", []) as Array
	var card_inst: Dictionary = {}
	var found_idx: int = -1
	for i: int in range(stash_cards.size()):
		var c: Variant = stash_cards[i]
		if c is Dictionary and str((c as Dictionary).get("uid", "")) == stash_uid:
			found_idx = i
			card_inst = (c as Dictionary).duplicate(true)
			break
	if found_idx == -1:
		return {"ok": false, "reason": "not_found", "stash": stash_out, "member": member_out}

	stash_cards.remove_at(found_idx)
	stash_out["cards"] = stash_cards

	var new_uid: String = stash_uid + "_w_" + member_token.substr(0, 4)
	card_inst["uid"] = new_uid
	var owned: Array = member_out.get("owned_cards", []) as Array
	owned.append(card_inst)
	member_out["owned_cards"] = owned

	return {"ok": true, "reason": "", "stash": stash_out, "member": member_out}


## Move `amount` coins from a member's balance into the shared stash. No-op (ok=false)
## when amount <= 0 or the member can't afford it. Returns {ok, reason, stash, member}.
static func deposit_coins(stash: Dictionary, member_rec: Dictionary, amount: int) -> Dictionary:
	var stash_out: Dictionary = _normalized_stash(stash)
	var member_out: Dictionary = member_rec.duplicate(true)
	if amount <= 0:
		return {"ok": false, "reason": "invalid_amount", "stash": stash_out, "member": member_out}
	var member_coins: int = int(member_out.get("coins", 0))
	if member_coins < amount:
		return {"ok": false, "reason": "insufficient_funds", "stash": stash_out, "member": member_out}
	member_out["coins"] = member_coins - amount
	stash_out["coins"] = int(stash_out.get("coins", 0)) + amount
	return {"ok": true, "reason": "", "stash": stash_out, "member": member_out}


## Move `amount` coins from the shared stash into a member's balance. No-op (ok=false)
## when amount <= 0 or the stash doesn't have enough. Returns {ok, reason, stash, member}.
static func withdraw_coins(stash: Dictionary, member_rec: Dictionary, amount: int) -> Dictionary:
	var stash_out: Dictionary = _normalized_stash(stash)
	var member_out: Dictionary = member_rec.duplicate(true)
	if amount <= 0:
		return {"ok": false, "reason": "invalid_amount", "stash": stash_out, "member": member_out}
	var stash_coins: int = int(stash_out.get("coins", 0))
	if stash_coins < amount:
		return {"ok": false, "reason": "insufficient_funds", "stash": stash_out, "member": member_out}
	stash_out["coins"] = stash_coins - amount
	member_out["coins"] = int(member_out.get("coins", 0)) + amount
	return {"ok": true, "reason": "", "stash": stash_out, "member": member_out}


## Defensive copy + shape guarantee so callers never need to null/type-check the stash
## dict before passing it in (garbage/legacy dicts default to empty).
static func _normalized_stash(stash: Dictionary) -> Dictionary:
	var out: Dictionary = stash.duplicate(true)
	var cards: Variant = out.get("cards", [])
	out["cards"] = (cards as Array).duplicate(true) if cards is Array else []
	out["coins"] = int(out.get("coins", 0))
	return out
