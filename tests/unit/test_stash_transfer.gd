## Unit tests for StashTransfer (GID-102 / TID-376) — the pure member <-> stash
## card/coin move helpers used by the shared party stash feature. Mirrors
## test_session_state.gd / test_rating_math.gd in style: pure inputs/outputs,
## no scene or SessionStore dependency.
extends "res://tests/framework/test_case.gd"

const StashTransfer = preload("res://game_logic/net/StashTransfer.gd")

const _NORMAL_CARD_ID: String = "ghost"       # not is_unique
const _UNIQUE_CARD_ID: String = "sig_pack_leader"  # is_unique = true


func _empty_stash() -> Dictionary:
	return {"cards": [], "coins": 0}


func _member_with_card(uid: String, template_id: String, coins: int = 100) -> Dictionary:
	return {
		"token": "tokA",
		"owned_cards": [
			{"uid": uid, "template_id": template_id, "rarity": "common",
			 "attack": 1, "health": 1, "cost": 1, "kills": 0,
			 "battles_survived": 0, "custom_name": ""},
		],
		"player_deck": [uid],
		"coins": coins,
	}


# ---------------------------------------------------------------------------
# deposit_card
# ---------------------------------------------------------------------------

func test_deposit_card_moves_instance_into_stash() -> void:
	var member: Dictionary = _member_with_card("ghost_a_0", _NORMAL_CARD_ID)
	var result: Dictionary = StashTransfer.deposit_card(_empty_stash(), member, "ghost_a_0")
	assert_true(bool(result.get("ok", false)))
	var member_out: Dictionary = result["member"]
	assert_true((member_out["owned_cards"] as Array).is_empty(), "card removed from owned_cards")
	assert_false((member_out["player_deck"] as Array).has("ghost_a_0"), "uid removed from deck")
	var stash_out: Dictionary = result["stash"]
	var stash_cards: Array = stash_out["cards"]
	assert_eq(stash_cards.size(), 1)
	assert_eq(str((stash_cards[0] as Dictionary).get("template_id", "")), _NORMAL_CARD_ID)


func test_deposit_card_rekeys_uid_into_stash_namespace() -> void:
	var member: Dictionary = _member_with_card("ghost_a_0", _NORMAL_CARD_ID)
	var result: Dictionary = StashTransfer.deposit_card(_empty_stash(), member, "ghost_a_0")
	var stash_cards: Array = result["stash"]["cards"]
	var new_uid: String = str((stash_cards[0] as Dictionary).get("uid", ""))
	assert_ne(new_uid, "ghost_a_0", "uid must be re-keyed, never reused as-is")
	assert_true(new_uid.begins_with("ghost_a_0"), "new uid still traces back to the original")


func test_deposit_card_blocks_unique_cards() -> void:
	var member: Dictionary = _member_with_card("sig_a_0", _UNIQUE_CARD_ID)
	var result: Dictionary = StashTransfer.deposit_card(_empty_stash(), member, "sig_a_0")
	assert_false(bool(result.get("ok", false)))
	assert_eq(str(result.get("reason", "")), "unique")
	# Nothing changed: card stays with the member, stash stays empty.
	var member_out: Dictionary = result["member"]
	assert_eq((member_out["owned_cards"] as Array).size(), 1)
	assert_true((result["stash"]["cards"] as Array).is_empty())


func test_deposit_card_no_ops_on_missing_card() -> void:
	var member: Dictionary = _member_with_card("ghost_a_0", _NORMAL_CARD_ID)
	var result: Dictionary = StashTransfer.deposit_card(_empty_stash(), member, "does_not_exist")
	assert_false(bool(result.get("ok", false)))
	assert_eq(str(result.get("reason", "")), "not_found")
	assert_eq((result["member"]["owned_cards"] as Array).size(), 1, "owned_cards untouched")


func test_deposit_card_no_ops_on_blank_uid() -> void:
	var member: Dictionary = _member_with_card("ghost_a_0", _NORMAL_CARD_ID)
	var result: Dictionary = StashTransfer.deposit_card(_empty_stash(), member, "")
	assert_false(bool(result.get("ok", false)))
	assert_eq(str(result.get("reason", "")), "no_uid")


# ---------------------------------------------------------------------------
# withdraw_card
# ---------------------------------------------------------------------------

func test_withdraw_card_moves_instance_to_member() -> void:
	var stash: Dictionary = {
		"cards": [{"uid": "ghost_stash_0", "template_id": _NORMAL_CARD_ID, "rarity": "common"}],
		"coins": 0,
	}
	var member: Dictionary = {"token": "tokB", "owned_cards": [], "player_deck": [], "coins": 0}
	var result: Dictionary = StashTransfer.withdraw_card(stash, member, "ghost_stash_0", "tokB")
	assert_true(bool(result.get("ok", false)))
	assert_true((result["stash"]["cards"] as Array).is_empty(), "card removed from stash")
	var owned: Array = result["member"]["owned_cards"]
	assert_eq(owned.size(), 1)
	assert_eq(str((owned[0] as Dictionary).get("template_id", "")), _NORMAL_CARD_ID)


func test_withdraw_card_rekeys_uid_into_member_namespace() -> void:
	var stash: Dictionary = {
		"cards": [{"uid": "ghost_stash_0", "template_id": _NORMAL_CARD_ID}],
		"coins": 0,
	}
	var member: Dictionary = {"token": "tokBBBB", "owned_cards": [], "player_deck": [], "coins": 0}
	var result: Dictionary = StashTransfer.withdraw_card(stash, member, "ghost_stash_0", "tokBBBB")
	var owned: Array = result["member"]["owned_cards"]
	var new_uid: String = str((owned[0] as Dictionary).get("uid", ""))
	assert_ne(new_uid, "ghost_stash_0")
	assert_true(new_uid.begins_with("ghost_stash_0"))
	assert_true(new_uid.ends_with("_w_tokB"), "salted with the withdrawing member's token prefix")


func test_withdraw_card_no_ops_on_missing_stash_card() -> void:
	var member: Dictionary = {"token": "tokB", "owned_cards": [], "player_deck": [], "coins": 0}
	var result: Dictionary = StashTransfer.withdraw_card(_empty_stash(), member, "nope", "tokB")
	assert_false(bool(result.get("ok", false)))
	assert_eq(str(result.get("reason", "")), "not_found")


# ---------------------------------------------------------------------------
# Round trip: deposit then withdraw restores an equivalent card
# ---------------------------------------------------------------------------

func test_deposit_then_withdraw_round_trip_restores_card_to_owner() -> void:
	var member: Dictionary = _member_with_card("ghost_a_0", _NORMAL_CARD_ID)
	var dep: Dictionary = StashTransfer.deposit_card(_empty_stash(), member, "ghost_a_0")
	assert_true(bool(dep.get("ok", false)))
	var stashed_uid: String = str((dep["stash"]["cards"][0] as Dictionary).get("uid", ""))

	var wd: Dictionary = StashTransfer.withdraw_card(dep["stash"], dep["member"], stashed_uid, "tokA")
	assert_true(bool(wd.get("ok", false)))
	assert_true((wd["stash"]["cards"] as Array).is_empty())
	var owned: Array = wd["member"]["owned_cards"]
	assert_eq(owned.size(), 1)
	assert_eq(str((owned[0] as Dictionary).get("template_id", "")), _NORMAL_CARD_ID)


# ---------------------------------------------------------------------------
# Coins
# ---------------------------------------------------------------------------

func test_deposit_coins_moves_amount_to_stash() -> void:
	var member: Dictionary = {"coins": 100}
	var result: Dictionary = StashTransfer.deposit_coins(_empty_stash(), member, 40)
	assert_true(bool(result.get("ok", false)))
	assert_eq(int(result["member"]["coins"]), 60)
	assert_eq(int(result["stash"]["coins"]), 40)


func test_deposit_coins_blocks_insufficient_funds() -> void:
	var member: Dictionary = {"coins": 10}
	var result: Dictionary = StashTransfer.deposit_coins(_empty_stash(), member, 40)
	assert_false(bool(result.get("ok", false)))
	assert_eq(str(result.get("reason", "")), "insufficient_funds")
	assert_eq(int(result["member"]["coins"]), 10, "balance untouched on failure")


func test_deposit_coins_blocks_non_positive_amount() -> void:
	var member: Dictionary = {"coins": 100}
	var result: Dictionary = StashTransfer.deposit_coins(_empty_stash(), member, 0)
	assert_false(bool(result.get("ok", false)))
	assert_eq(str(result.get("reason", "")), "invalid_amount")
	var neg_result: Dictionary = StashTransfer.deposit_coins(_empty_stash(), member, -5)
	assert_false(bool(neg_result.get("ok", false)))


func test_withdraw_coins_moves_amount_to_member() -> void:
	var stash: Dictionary = {"cards": [], "coins": 100}
	var member: Dictionary = {"coins": 10}
	var result: Dictionary = StashTransfer.withdraw_coins(stash, member, 30)
	assert_true(bool(result.get("ok", false)))
	assert_eq(int(result["stash"]["coins"]), 70)
	assert_eq(int(result["member"]["coins"]), 40)


func test_withdraw_coins_blocks_insufficient_stash_funds() -> void:
	var stash: Dictionary = {"cards": [], "coins": 5}
	var member: Dictionary = {"coins": 10}
	var result: Dictionary = StashTransfer.withdraw_coins(stash, member, 30)
	assert_false(bool(result.get("ok", false)))
	assert_eq(str(result.get("reason", "")), "insufficient_funds")
	assert_eq(int(result["stash"]["coins"]), 5, "stash balance untouched on failure")


func test_coin_deposit_then_withdraw_round_trip_is_neutral() -> void:
	var member: Dictionary = {"coins": 100}
	var dep: Dictionary = StashTransfer.deposit_coins(_empty_stash(), member, 25)
	var wd: Dictionary = StashTransfer.withdraw_coins(dep["stash"], dep["member"], 25)
	assert_true(bool(wd.get("ok", false)))
	assert_eq(int(wd["member"]["coins"]), 100)
	assert_eq(int(wd["stash"]["coins"]), 0)


# ---------------------------------------------------------------------------
# Defensive normalization of a garbage/legacy stash dict
# ---------------------------------------------------------------------------

func test_deposit_card_tolerates_garbage_stash_shape() -> void:
	var member: Dictionary = _member_with_card("ghost_a_0", _NORMAL_CARD_ID)
	var garbage_stash: Dictionary = {"cards": "not-an-array"}  # missing coins too
	var result: Dictionary = StashTransfer.deposit_card(garbage_stash, member, "ghost_a_0")
	assert_true(bool(result.get("ok", false)))
	assert_eq((result["stash"]["cards"] as Array).size(), 1)
