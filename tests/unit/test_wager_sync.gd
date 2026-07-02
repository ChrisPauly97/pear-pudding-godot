## Unit tests for WagerSync (GID-104 / TID-387) — spectator-wager pure logic:
## betting cutoff, bet-size caps, bet validation (including replace-bet headroom),
## payout/settlement math (win/loss/draw/abandoned), and encode/decode round-trips
## with garbage tolerance. Mirrors test_loot_roll.gd / test_rating_math.gd (pure,
## scene-free).
extends "res://tests/framework/test_case.gd"

const WagerSync = preload("res://game_logic/net/WagerSync.gd")


# ---------------------------------------------------------------------------
# Cutoff — is_betting_open
# ---------------------------------------------------------------------------

func test_betting_open_on_turn_one() -> void:
	assert_true(WagerSync.is_betting_open(1))


func test_betting_open_at_cutoff_turn() -> void:
	assert_true(WagerSync.is_betting_open(WagerSync.CUTOFF_TURN))


func test_betting_closed_after_cutoff_turn() -> void:
	assert_false(WagerSync.is_betting_open(WagerSync.CUTOFF_TURN + 1))
	assert_false(WagerSync.is_betting_open(99))


# ---------------------------------------------------------------------------
# Bet cap — max_bet (flat cap vs 10% of balance, whichever is smaller)
# ---------------------------------------------------------------------------

func test_max_bet_zero_for_broke_or_negative_balance() -> void:
	assert_eq(WagerSync.max_bet(0), 0)
	assert_eq(WagerSync.max_bet(-50), 0)


func test_max_bet_flat_cap_for_rich_balance() -> void:
	# 10% of 10000 is 1000, but the flat cap wins.
	assert_eq(WagerSync.max_bet(10000), WagerSync.MAX_BET_FLAT)


func test_max_bet_percent_cap_for_small_balance() -> void:
	# 10% of 100 = 10, below the flat cap.
	assert_eq(WagerSync.max_bet(100), 10)
	assert_eq(WagerSync.max_bet(40), 4)


func test_max_bet_zero_when_ten_percent_floors_to_zero() -> void:
	# 10% of 9 floors to 0 — a spectator with fewer than 10 coins cannot bet.
	assert_eq(WagerSync.max_bet(9), 0)


func test_max_bet_exact_flat_cap_boundary() -> void:
	# 500 coins → 10% = 50 = flat cap.
	assert_eq(WagerSync.max_bet(500), WagerSync.MAX_BET_FLAT)


# ---------------------------------------------------------------------------
# normalize_side
# ---------------------------------------------------------------------------

func test_normalize_side_accepts_a_and_b() -> void:
	assert_eq(WagerSync.normalize_side("a"), WagerSync.SIDE_A)
	assert_eq(WagerSync.normalize_side("b"), WagerSync.SIDE_B)


func test_normalize_side_rejects_garbage() -> void:
	assert_eq(WagerSync.normalize_side("c"), "")
	assert_eq(WagerSync.normalize_side(""), "")
	assert_eq(WagerSync.normalize_side("A"), "")


# ---------------------------------------------------------------------------
# is_valid_bet
# ---------------------------------------------------------------------------

func test_valid_bet_within_cap_accepted() -> void:
	assert_true(WagerSync.is_valid_bet("a", 10, 500))
	assert_true(WagerSync.is_valid_bet("b", WagerSync.MAX_BET_FLAT, 10000))


func test_bet_with_invalid_side_rejected() -> void:
	assert_false(WagerSync.is_valid_bet("", 10, 500))
	assert_false(WagerSync.is_valid_bet("x", 10, 500))


func test_zero_or_negative_bet_rejected() -> void:
	assert_false(WagerSync.is_valid_bet("a", 0, 500))
	assert_false(WagerSync.is_valid_bet("a", -5, 500))


func test_bet_above_balance_rejected() -> void:
	assert_false(WagerSync.is_valid_bet("a", 60, 50))


func test_bet_above_cap_rejected_even_with_balance() -> void:
	# Balance 10000 gives headroom, but the flat cap is MAX_BET_FLAT.
	assert_false(WagerSync.is_valid_bet("a", WagerSync.MAX_BET_FLAT + 1, 10000))


func test_replace_bet_headroom_includes_prior_stake() -> void:
	# Bettor started with 300, placed a max bet of 30 (10% cap), leaving 270 free.
	# Replacing that bet is validated against the full headroom (270 + 30 = 300):
	# re-placing 30 or lowering to 20 is fine; 31 exceeds the cap (see next test).
	assert_true(WagerSync.is_valid_bet("a", 30, 270, 30))
	assert_true(WagerSync.is_valid_bet("a", 20, 270, 30))
	assert_false(WagerSync.is_valid_bet("a", 301, 270, 30))


func test_replace_bet_cap_applies_to_headroom() -> void:
	# Headroom 300 → cap 30. A raise to 31 must be rejected.
	assert_false(WagerSync.is_valid_bet("a", 31, 270, 30))
	assert_true(WagerSync.is_valid_bet("a", 30, 270, 30))


# ---------------------------------------------------------------------------
# encode_bet / decode_bet round-trip
# ---------------------------------------------------------------------------

func test_bet_round_trip_preserves_side_and_amount() -> void:
	var payload: Dictionary = WagerSync.encode_bet("b", 25)
	var d: Dictionary = WagerSync.decode_bet(payload)
	assert_eq(str(d.get("side", "")), WagerSync.SIDE_B)
	assert_eq(int(d.get("amount", 0)), 25)


func test_bet_encode_normalizes_bogus_side_to_empty() -> void:
	var payload: Dictionary = WagerSync.encode_bet("zzz", 25)
	assert_eq(str(payload.get("side", "x")), "")


func test_bet_encode_clamps_negative_amount() -> void:
	var payload: Dictionary = WagerSync.encode_bet("a", -10)
	assert_eq(int(payload.get("amount", -1)), 0)


func test_bet_decode_garbage_returns_defaults() -> void:
	var d: Dictionary = WagerSync.decode_bet({})
	assert_eq(str(d.get("side", "x")), "")
	assert_eq(int(d.get("amount", -1)), 0)


func test_bet_decode_non_dictionary_does_not_throw() -> void:
	var d: Dictionary = WagerSync.decode_bet("not a dict")
	assert_eq(str(d.get("side", "x")), "")


func test_bet_decode_null_does_not_throw() -> void:
	var d: Dictionary = WagerSync.decode_bet(null)
	assert_eq(str(d.get("side", "x")), "")


func test_bet_decode_forged_side_rejected() -> void:
	var d: Dictionary = WagerSync.decode_bet({"side": "hero", "amount": 10})
	assert_eq(str(d.get("side", "x")), "")


# ---------------------------------------------------------------------------
# settle — payout math
# ---------------------------------------------------------------------------

func test_settle_winner_credited_double_stake() -> void:
	var bets: Dictionary = {"tok_a": {"side": "a", "amount": 10}}
	var payouts: Dictionary = WagerSync.settle(bets, WagerSync.SIDE_A)
	assert_eq(int(payouts.get("tok_a", -1)), 20)


func test_settle_loser_credited_zero() -> void:
	var bets: Dictionary = {"tok_a": {"side": "a", "amount": 10}}
	var payouts: Dictionary = WagerSync.settle(bets, WagerSync.SIDE_B)
	assert_eq(int(payouts.get("tok_a", -1)), 0)


func test_settle_mixed_sides() -> void:
	var bets: Dictionary = {
		"tok_a": {"side": "a", "amount": 10},
		"tok_b": {"side": "b", "amount": 30},
	}
	var payouts: Dictionary = WagerSync.settle(bets, WagerSync.SIDE_B)
	assert_eq(int(payouts.get("tok_a", -1)), 0)
	assert_eq(int(payouts.get("tok_b", -1)), 60)


func test_settle_draw_refunds_exact_stake() -> void:
	var bets: Dictionary = {
		"tok_a": {"side": "a", "amount": 10},
		"tok_b": {"side": "b", "amount": 30},
	}
	var payouts: Dictionary = WagerSync.settle(bets, WagerSync.OUTCOME_DRAW)
	assert_eq(int(payouts.get("tok_a", -1)), 10)
	assert_eq(int(payouts.get("tok_b", -1)), 30)


func test_settle_abandoned_refunds_exact_stake() -> void:
	var bets: Dictionary = {"tok_a": {"side": "b", "amount": 15}}
	var payouts: Dictionary = WagerSync.settle(bets, WagerSync.OUTCOME_ABANDONED)
	assert_eq(int(payouts.get("tok_a", -1)), 15)


func test_settle_skips_garbage_bet_entries() -> void:
	var bets: Dictionary = {
		"tok_bad_type": "not a dict",
		"tok_bad_side": {"side": "z", "amount": 10},
		"tok_zero": {"side": "a", "amount": 0},
		"tok_ok": {"side": "a", "amount": 5},
	}
	var payouts: Dictionary = WagerSync.settle(bets, WagerSync.SIDE_A)
	assert_false(payouts.has("tok_bad_type"))
	assert_false(payouts.has("tok_bad_side"))
	assert_false(payouts.has("tok_zero"))
	assert_eq(int(payouts.get("tok_ok", -1)), 10)


func test_settle_empty_bets_yields_empty_payouts() -> void:
	var payouts: Dictionary = WagerSync.settle({}, WagerSync.SIDE_A)
	assert_eq(payouts.size(), 0)


func test_settle_total_credit_conservation_on_clean_win() -> void:
	# Escrow held = 10 + 30 = 40. Credits paid = winner's 20. The house (session)
	# absorbs the loser's 30 - the winner's 10 profit... i.e. total credited (20)
	# never exceeds total escrowed (40) for a 1:1 payout, regardless of sides.
	var bets: Dictionary = {
		"tok_a": {"side": "a", "amount": 10},
		"tok_b": {"side": "b", "amount": 30},
	}
	var payouts: Dictionary = WagerSync.settle(bets, WagerSync.SIDE_A)
	var total_credited: int = 0
	for k in payouts.keys():
		total_credited += int(payouts[k])
	assert_lte(total_credited, 40)


# ---------------------------------------------------------------------------
# encode_settlement / decode_settlement round-trip
# ---------------------------------------------------------------------------

func test_settlement_round_trip_preserves_outcome_and_payouts() -> void:
	var payload: Dictionary = WagerSync.encode_settlement(WagerSync.SIDE_A, {"tok_a": 20, "tok_b": 0})
	var d: Dictionary = WagerSync.decode_settlement(payload)
	assert_eq(str(d.get("outcome", "")), WagerSync.SIDE_A)
	var payouts: Dictionary = d.get("payouts", {})
	assert_eq(int(payouts.get("tok_a", -1)), 20)
	assert_eq(int(payouts.get("tok_b", -1)), 0)


func test_settlement_round_trip_refund_outcome() -> void:
	var payload: Dictionary = WagerSync.encode_settlement(WagerSync.OUTCOME_ABANDONED, {"tok_a": 15})
	var d: Dictionary = WagerSync.decode_settlement(payload)
	assert_eq(str(d.get("outcome", "")), WagerSync.OUTCOME_ABANDONED)
	assert_eq(int((d.get("payouts", {}) as Dictionary).get("tok_a", -1)), 15)


func test_settlement_decode_garbage_returns_defaults() -> void:
	var d: Dictionary = WagerSync.decode_settlement({})
	assert_eq(str(d.get("outcome", "x")), "")
	assert_eq((d.get("payouts", {}) as Dictionary).size(), 0)


func test_settlement_decode_non_dictionary_does_not_throw() -> void:
	var d: Dictionary = WagerSync.decode_settlement("not a dict")
	assert_eq(str(d.get("outcome", "x")), "")


func test_settlement_decode_null_does_not_throw() -> void:
	var d: Dictionary = WagerSync.decode_settlement(null)
	assert_eq(str(d.get("outcome", "x")), "")


func test_settlement_decode_non_dict_payouts_tolerated() -> void:
	var d: Dictionary = WagerSync.decode_settlement({"outcome": "a", "payouts": "junk"})
	assert_eq(str(d.get("outcome", "")), "a")
	assert_eq((d.get("payouts", {}) as Dictionary).size(), 0)


# ---------------------------------------------------------------------------
# End-to-end pure flow: place → settle → refund equivalence
# ---------------------------------------------------------------------------

func test_full_flow_win_and_loss_net_effect() -> void:
	# Spectator with 300 coins bets 30 on side a (stake debited → 270 held locally).
	var coins: int = 300
	var stake: int = 30
	assert_true(WagerSync.is_valid_bet("a", stake, coins))
	coins -= stake  # escrow debit
	# Side a wins: credit = 2x stake → net +30 vs the original balance.
	var payouts_win: Dictionary = WagerSync.settle({"tok": {"side": "a", "amount": stake}}, WagerSync.SIDE_A)
	assert_eq(coins + int(payouts_win.get("tok", 0)), 330)
	# Side b wins instead: credit 0 → net -30.
	var payouts_loss: Dictionary = WagerSync.settle({"tok": {"side": "a", "amount": stake}}, WagerSync.SIDE_B)
	assert_eq(coins + int(payouts_loss.get("tok", 0)), 270)
	# Abandoned: refund → back to exactly 300.
	var payouts_ref: Dictionary = WagerSync.settle({"tok": {"side": "a", "amount": stake}}, WagerSync.OUTCOME_ABANDONED)
	assert_eq(coins + int(payouts_ref.get("tok", 0)), 300)
