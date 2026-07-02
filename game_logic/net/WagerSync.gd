## Pure spectator-wager helpers for live PvP duels (GID-104 / TID-387).
##
## Spectators of a duel (see TID-367, docs/agent/multiplayer-coop.md "Spectating a
## duel") can bet coins on peer_a ("a") or peer_b ("b") before a cutoff turn. The
## host/authority holds every bet in escrow (BattleScene volatile state — not
## persisted mid-duel) and, on settlement, writes coins directly into the bettor's
## `SessionState` member record (mirrors `WorldScene._grant_chest_loot_to_token` /
## the party-bounty reward pattern). Only coins are ever at risk — cards are never
## touched by this file or its callers.
##
## Callers: preload("res://game_logic/net/WagerSync.gd"). No scene dependencies —
## fully unit-testable, mirrors AvatarSync / BattleNetProtocol / RatingMath / LootRoll.
extends RefCounted

## The two sides a spectator can back — peer_a (host/challenger) or peer_b (opponent).
const SIDE_A: String = "a"
const SIDE_B: String = "b"

## Settlement outcomes that are not a clean side win: every bettor gets their
## original stake back (no side "wins" the pot).
const OUTCOME_DRAW: String = "draw"
const OUTCOME_ABANDONED: String = "abandoned"

## Betting closes once the mirrored GameState.turn_number exceeds this (end of turn 3).
## Every peer already has turn_number locally via the existing state mirror, so the
## cutoff needs no extra wire traffic — each spectator evaluates it the same way.
const CUTOFF_TURN: int = 3

## Absolute bet ceiling, regardless of the bettor's coin balance.
const MAX_BET_FLAT: int = 50

## Bet ceiling as a fraction of the bettor's available coins (the more restrictive
## of the two caps always applies — see max_bet()).
const MAX_BET_PCT: float = 0.10


# ---------------------------------------------------------------------------
# Cutoff + cap logic (pure, no networking)
# ---------------------------------------------------------------------------

## True while spectators may still place or change a bet.
static func is_betting_open(turn_number: int) -> bool:
	return turn_number <= CUTOFF_TURN


## The largest single bet a spectator with `available_coins` may hold at once: the
## smaller of the flat cap and 10% of their balance (floored). Never negative.
static func max_bet(available_coins: int) -> int:
	if available_coins <= 0:
		return 0
	var pct_cap: int = int(float(available_coins) * MAX_BET_PCT)
	return mini(MAX_BET_FLAT, pct_cap)


## Normalize a raw side string; anything other than "a"/"b" is invalid ("").
static func normalize_side(side: String) -> String:
	if side == SIDE_A or side == SIDE_B:
		return side
	return ""


## Full authority-side validation for placing/replacing one bet. `existing_amount`
## is any prior bet from the same spectator being replaced (0 if none) — a spectator
## raising or lowering their own bet is validated against their *total* headroom
## (their current balance plus whatever is already held in escrow from their prior
## bet), not double-penalized for coins already committed.
static func is_valid_bet(side: String, amount: int, available_coins: int, existing_amount: int = 0) -> bool:
	if normalize_side(side) == "":
		return false
	if amount <= 0:
		return false
	var headroom: int = available_coins + maxi(0, existing_amount)
	if amount > headroom:
		return false
	return amount <= max_bet(headroom)


# ---------------------------------------------------------------------------
# Wire format — spectator -> host: place/replace a bet.
# ---------------------------------------------------------------------------

## Pack one bet placement. Amount is clamped non-negative; an invalid side
## normalizes to "" so a garbage caller can never smuggle a bogus side across
## the wire (the host rejects an empty side on decode).
static func encode_bet(side: String, amount: int) -> Dictionary:
	return {"side": normalize_side(side), "amount": maxi(0, int(amount))}


## Unpack a bet payload into {side, amount}. Fully defaulted and garbage-tolerant —
## never throws. side == "" means invalid/unrecognized (caller must reject).
static func decode_bet(payload: Variant) -> Dictionary:
	if not (payload is Dictionary):
		return {"side": "", "amount": 0}
	var d: Dictionary = payload
	return {
		"side": normalize_side(str(d.get("side", ""))),
		"amount": maxi(0, int(d.get("amount", 0))),
	}


# ---------------------------------------------------------------------------
# Settlement — authority only (owns the outcome + the SessionState writes).
# ---------------------------------------------------------------------------

## Resolve every bettor's payout. `bets` = {key: {"side": "a"|"b", "amount": int}}
## (key is caller-defined — the authority uses session tokens). `outcome` is SIDE_A/
## SIDE_B (that side won) or OUTCOME_DRAW/OUTCOME_ABANDONED (refund everyone their
## stake). Returns {key: payout_coins} — the amount to CREDIT back to the bettor's
## record (their stake was already deducted from it at bet-placement time). A winner
## is credited double their stake (stake back + an equal 1:1 win); a loser is
## credited 0 (their stake is gone); a refund credits exactly their stake.
static func settle(bets: Dictionary, outcome: String) -> Dictionary:
	var payouts: Dictionary = {}
	for key in bets.keys():
		var bet: Variant = bets[key]
		if not (bet is Dictionary):
			continue
		var side: String = normalize_side(str((bet as Dictionary).get("side", "")))
		var amount: int = maxi(0, int((bet as Dictionary).get("amount", 0)))
		if side == "" or amount <= 0:
			continue
		var payout: int = 0
		if outcome == OUTCOME_DRAW or outcome == OUTCOME_ABANDONED:
			payout = amount
		elif side == outcome:
			payout = amount * 2
		payouts[key] = payout
	return payouts


# ---------------------------------------------------------------------------
# Wire format — host -> spectators: the settlement result.
# ---------------------------------------------------------------------------

## Pack the settlement broadcast. `payouts` maps a bettor key (session token) to
## the coins credited back to them (0 for a clean loss).
static func encode_settlement(outcome: String, payouts: Dictionary) -> Dictionary:
	var p: Dictionary = {}
	for k in payouts.keys():
		p[str(k)] = int(payouts[k])
	return {"outcome": str(outcome), "payouts": p}


## Unpack a settlement payload into {outcome, payouts}. Garbage-tolerant — never throws.
static func decode_settlement(payload: Variant) -> Dictionary:
	if not (payload is Dictionary):
		return {"outcome": "", "payouts": {}}
	var d: Dictionary = payload
	var raw: Variant = d.get("payouts", {})
	var out: Dictionary = {}
	if raw is Dictionary:
		for k in (raw as Dictionary).keys():
			out[str(k)] = int((raw as Dictionary)[k])
	return {"outcome": str(d.get("outcome", "")), "payouts": out}
