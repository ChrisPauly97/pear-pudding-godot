## Unit tests for bounty board accept/claim logic in SaveManager (TID-189).
##
## Covers: accept flow, max-3 gate, claim flow, coin payout, already-claimed guard,
## progress-incomplete guard, repeated accept guard.
extends "res://tests/framework/test_case.gd"

const SaveManagerScript = preload("res://autoloads/SaveManager.gd")

var _sm: Node

func before_each() -> void:
	_sm = SaveManagerScript.new()
	_sm._loaded = true
	_sm.world_seed = 7
	_sm.days_elapsed = 0
	# Pre-populate offered bounties with known test data (bypass BountyGen)
	_sm.offered_bounties.assign([
		{"id": "b_deftype", "type": "defeat_enemy_type", "target": "undead_basic",
			"count": 2, "reward": 80, "offered_at_day": 0},
		{"id": "b_biome",   "type": "defeat_in_biome",   "target": "grasslands",
			"count": 3, "reward": 95, "offered_at_day": 0},
		{"id": "b_chests",  "type": "open_chests",        "target": "chest",
			"count": 2, "reward": 60, "offered_at_day": 0},
	])
	_sm.bounty_day = 0

func after_each() -> void:
	_sm.free()

# ---------------------------------------------------------------------------
# accept_bounty
# ---------------------------------------------------------------------------

func test_accept_moves_bounty_to_active() -> void:
	_sm.accept_bounty("b_deftype")
	assert_eq(_sm.active_bounties.size(), 1)

func test_accept_removes_from_offered() -> void:
	_sm.accept_bounty("b_deftype")
	assert_eq(_sm.offered_bounties.size(), 2)

func test_accept_sets_progress_zero() -> void:
	_sm.accept_bounty("b_deftype")
	assert_eq(int(_sm.active_bounties[0].get("progress", -1)), 0)

func test_accept_sets_claimed_false() -> void:
	_sm.accept_bounty("b_deftype")
	assert_false(bool(_sm.active_bounties[0].get("claimed", true)))

func test_accept_sets_accepted_at_day() -> void:
	_sm.days_elapsed = 5
	_sm.accept_bounty("b_deftype")
	assert_eq(int(_sm.active_bounties[0].get("accepted_at_day", -1)), 5)

func test_accept_returns_true_on_success() -> void:
	var ok: bool = _sm.accept_bounty("b_deftype")
	assert_true(ok)

func test_accept_returns_false_for_unknown_id() -> void:
	var ok: bool = _sm.accept_bounty("nonexistent")
	assert_false(ok)

func test_accept_same_bounty_twice_fails() -> void:
	_sm.accept_bounty("b_deftype")
	var ok: bool = _sm.accept_bounty("b_deftype")
	assert_false(ok, "second accept of same id must fail (no longer in offered)")
	assert_eq(_sm.active_bounties.size(), 1)

func test_accept_preserves_reward_and_count() -> void:
	_sm.accept_bounty("b_deftype")
	assert_eq(int(_sm.active_bounties[0].get("reward", 0)), 80)
	assert_eq(int(_sm.active_bounties[0].get("count", 0)), 2)

# ---------------------------------------------------------------------------
# max 3 active gate
# ---------------------------------------------------------------------------

func test_accept_three_bounties_succeeds() -> void:
	_sm.accept_bounty("b_deftype")
	_sm.accept_bounty("b_biome")
	var ok: bool = _sm.accept_bounty("b_chests")
	assert_true(ok, "third accept must succeed")
	assert_eq(_sm.active_bounties.size(), 3)

func test_accept_fourth_bounty_rejected() -> void:
	# Fill to 3 via direct mutation then try to accept
	_sm.active_bounties.assign([
		{"id": "x1", "progress": 0, "claimed": false, "count": 1, "reward": 10},
		{"id": "x2", "progress": 0, "claimed": false, "count": 1, "reward": 10},
		{"id": "x3", "progress": 0, "claimed": false, "count": 1, "reward": 10},
	])
	var ok: bool = _sm.accept_bounty("b_deftype")
	assert_false(ok, "fourth accept must be rejected when 3 already active")
	assert_eq(_sm.active_bounties.size(), 3)
	assert_eq(_sm.offered_bounties.size(), 3, "offered must remain unchanged on rejection")

# ---------------------------------------------------------------------------
# claim_bounty
# ---------------------------------------------------------------------------

func _setup_claimable_bounty() -> void:
	_sm.accept_bounty("b_chests")
	# Fast-forward progress to complete
	for i: int in range(_sm.active_bounties.size()):
		if str(_sm.active_bounties[i].get("id", "")) == "b_chests":
			_sm.active_bounties[i]["progress"] = 2  # count=2

func test_claim_complete_bounty_returns_reward() -> void:
	_setup_claimable_bounty()
	var paid: int = _sm.claim_bounty("b_chests")
	assert_eq(paid, 60)

func test_claim_marks_claimed() -> void:
	_setup_claimable_bounty()
	_sm.claim_bounty("b_chests")
	var found: bool = false
	for b: Dictionary in _sm.active_bounties:
		if str(b.get("id", "")) == "b_chests":
			assert_true(bool(b.get("claimed", false)), "bounty must be marked claimed")
			found = true
	assert_true(found, "bounty must still be in active list after claim")

func test_claim_adds_coins() -> void:
	_sm.coins = 0
	_setup_claimable_bounty()
	_sm.claim_bounty("b_chests")
	assert_eq(_sm.coins, 60)

func test_claim_already_claimed_returns_zero() -> void:
	_setup_claimable_bounty()
	_sm.claim_bounty("b_chests")
	var second: int = _sm.claim_bounty("b_chests")
	assert_eq(second, 0, "second claim must return 0")
	assert_eq(_sm.coins, 60, "coins must not be doubled")

func test_claim_incomplete_bounty_returns_zero() -> void:
	_sm.accept_bounty("b_chests")
	# progress stays at 0, count=2
	var paid: int = _sm.claim_bounty("b_chests")
	assert_eq(paid, 0, "incomplete bounty must not be claimable")
	assert_eq(_sm.coins, 0, "no coins must be added")

func test_claim_unknown_id_returns_zero() -> void:
	var paid: int = _sm.claim_bounty("nonexistent")
	assert_eq(paid, 0)

func test_claim_does_not_affect_other_active_bounties() -> void:
	_sm.accept_bounty("b_deftype")
	_setup_claimable_bounty()
	_sm.claim_bounty("b_chests")
	var deftype_found: bool = false
	for b: Dictionary in _sm.active_bounties:
		if str(b.get("id", "")) == "b_deftype":
			deftype_found = true
			assert_false(bool(b.get("claimed", false)), "unrelated bounty must not be claimed")
	assert_true(deftype_found, "other bounty must still exist after unrelated claim")
