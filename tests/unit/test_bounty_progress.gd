## Unit tests for bounty progress tracking via increment_bounty_progress (TID-190).
##
## Covers: type matching, biome matching, chest tracking, completion flag,
## no-progress-while-not-accepted, double-claim guard, coin payout.
extends "res://tests/framework/test_case.gd"

const SaveManagerScript = preload("res://autoloads/SaveManager.gd")

var _sm: Node

func before_each() -> void:
	_sm = SaveManagerScript.new()
	_sm._loaded = true
	_sm.world_seed = 7
	_sm.days_elapsed = 0
	_sm.coins = 0
	_sm.offered_bounties.assign([
		{"id": "b_deftype", "type": "defeat_enemy_type", "target": "ghoul_pack",
			"count": 2, "reward": 80, "offered_at_day": 0},
		{"id": "b_biome",   "type": "defeat_in_biome",   "target": "forest",
			"count": 3, "reward": 95, "offered_at_day": 0},
		{"id": "b_chests",  "type": "open_chests",        "target": "chest",
			"count": 2, "reward": 60, "offered_at_day": 0},
	])
	_sm.bounty_day = 0

func after_each() -> void:
	_sm.free()

# ---------------------------------------------------------------------------
# defeat_enemy_type matching
# ---------------------------------------------------------------------------

func test_matching_enemy_type_increments_progress() -> void:
	_sm.accept_bounty("b_deftype")
	_sm.increment_bounty_progress("defeat_enemy_type", {"enemy_type": "ghoul_pack"})
	var b: Dictionary = _active_by_id("b_deftype")
	assert_eq(int(b.get("progress", 0)), 1)

func test_non_matching_enemy_type_does_not_increment() -> void:
	_sm.accept_bounty("b_deftype")
	_sm.increment_bounty_progress("defeat_enemy_type", {"enemy_type": "undead_basic"})
	var b: Dictionary = _active_by_id("b_deftype")
	assert_eq(int(b.get("progress", 0)), 0)

func test_enemy_type_increment_does_not_affect_biome_bounty() -> void:
	_sm.accept_bounty("b_biome")
	_sm.increment_bounty_progress("defeat_enemy_type", {"enemy_type": "ghoul_pack"})
	var b: Dictionary = _active_by_id("b_biome")
	assert_eq(int(b.get("progress", 0)), 0)

# ---------------------------------------------------------------------------
# defeat_in_biome matching
# ---------------------------------------------------------------------------

func test_matching_biome_increments_progress() -> void:
	_sm.accept_bounty("b_biome")
	_sm.increment_bounty_progress("defeat_in_biome", {"biome_name": "forest"})
	var b: Dictionary = _active_by_id("b_biome")
	assert_eq(int(b.get("progress", 0)), 1)

func test_non_matching_biome_does_not_increment() -> void:
	_sm.accept_bounty("b_biome")
	_sm.increment_bounty_progress("defeat_in_biome", {"biome_name": "desert"})
	var b: Dictionary = _active_by_id("b_biome")
	assert_eq(int(b.get("progress", 0)), 0)

# ---------------------------------------------------------------------------
# open_chests
# ---------------------------------------------------------------------------

func test_chest_increment_always_matches() -> void:
	_sm.accept_bounty("b_chests")
	_sm.increment_bounty_progress("open_chests", {})
	var b: Dictionary = _active_by_id("b_chests")
	assert_eq(int(b.get("progress", 0)), 1)

func test_chest_increment_does_not_affect_other_types() -> void:
	_sm.accept_bounty("b_deftype")
	_sm.increment_bounty_progress("open_chests", {})
	var b: Dictionary = _active_by_id("b_deftype")
	assert_eq(int(b.get("progress", 0)), 0)

# ---------------------------------------------------------------------------
# Completion detection
# ---------------------------------------------------------------------------

func test_progress_reaching_count_sets_completed() -> void:
	_sm.accept_bounty("b_chests")
	_sm.increment_bounty_progress("open_chests", {})
	_sm.increment_bounty_progress("open_chests", {})
	var b: Dictionary = _active_by_id("b_chests")
	assert_true(bool(b.get("completed", false)), "completed flag must be set when progress >= count")

func test_progress_below_count_does_not_set_completed() -> void:
	_sm.accept_bounty("b_chests")
	_sm.increment_bounty_progress("open_chests", {})
	var b: Dictionary = _active_by_id("b_chests")
	assert_false(bool(b.get("completed", false)), "completed must not be set before reaching count")

func test_completed_bounty_not_incremented_again() -> void:
	_sm.accept_bounty("b_chests")
	_sm.increment_bounty_progress("open_chests", {})
	_sm.increment_bounty_progress("open_chests", {})
	# One more increment after completion — should be ignored
	_sm.increment_bounty_progress("open_chests", {})
	var b: Dictionary = _active_by_id("b_chests")
	assert_eq(int(b.get("progress", 0)), 2, "progress must not exceed count after completion")

# ---------------------------------------------------------------------------
# No progress while not accepted
# ---------------------------------------------------------------------------

func test_offered_bounty_does_not_increment_on_signal() -> void:
	# b_deftype is in offered_bounties, not active
	_sm.increment_bounty_progress("defeat_enemy_type", {"enemy_type": "ghoul_pack"})
	# Verify the offered bounty has no progress field set
	for b: Dictionary in _sm.offered_bounties:
		if str(b.get("id", "")) == "b_deftype":
			assert_eq(int(b.get("progress", 0)), 0,
				"offered (not accepted) bounty must not receive progress")

# ---------------------------------------------------------------------------
# Coin payout on claim
# ---------------------------------------------------------------------------

func test_claim_complete_bounty_adds_coins() -> void:
	_sm.accept_bounty("b_chests")
	_sm.increment_bounty_progress("open_chests", {})
	_sm.increment_bounty_progress("open_chests", {})
	var paid: int = _sm.claim_bounty("b_chests")
	assert_eq(paid, 60)
	assert_eq(_sm.coins, 60)

func test_claim_twice_returns_zero_second_time() -> void:
	_sm.accept_bounty("b_chests")
	_sm.increment_bounty_progress("open_chests", {})
	_sm.increment_bounty_progress("open_chests", {})
	_sm.claim_bounty("b_chests")
	var second: int = _sm.claim_bounty("b_chests")
	assert_eq(second, 0, "second claim must return 0")
	assert_eq(_sm.coins, 60, "coins must not be doubled")

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

func _active_by_id(bid: String) -> Dictionary:
	for b: Dictionary in _sm.active_bounties:
		if str(b.get("id", "")) == bid:
			return b
	return {}
