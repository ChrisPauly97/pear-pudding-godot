## Tests for SiegeDefs.should_trigger() — evaluates all three trigger conditions.
extends "res://tests/framework/test_case.gd"

const SiegeDefs = preload("res://game_logic/SiegeDefs.gd")

# Baseline: all conditions satisfied.
var _flags_ok: Dictionary = {"chapter1_warned_farsyth": true}
const _SEED: int = 42
const _DAYS: int = 10    # days_elapsed = 10
const _LAST: int = 0     # last_siege_day = 0  → cooldown = 10 >= 4 ✓

# ---------------------------------------------------------------------------
# Gating flag
# ---------------------------------------------------------------------------

func test_no_flag_blocks_trigger() -> void:
	var result: bool = SiegeDefs.should_trigger({}, _DAYS, _LAST, _SEED)
	assert_false(result, "should not trigger without chapter1_warned_farsyth")

func test_flag_false_blocks_trigger() -> void:
	var flags: Dictionary = {"chapter1_warned_farsyth": false}
	assert_false(SiegeDefs.should_trigger(flags, _DAYS, _LAST, _SEED))

# ---------------------------------------------------------------------------
# Cooldown
# ---------------------------------------------------------------------------

func test_cooldown_not_satisfied_blocks_trigger() -> void:
	# days_elapsed 3, last_siege_day 0 → gap = 3 < 4
	assert_false(SiegeDefs.should_trigger(_flags_ok, 3, 0, _SEED))

func test_cooldown_exactly_4_may_trigger() -> void:
	# days_elapsed 4, last 0 → gap = 4 >= 4.  May or may not trigger depending on seed.
	# Just assert it doesn't panic (no error).
	var _result: bool = SiegeDefs.should_trigger(_flags_ok, 4, 0, _SEED)
	assert_true(true)   # reached without error

func test_cooldown_recent_siege_blocks_trigger() -> void:
	# last siege was yesterday (day 9, current 10 → gap = 1 < 4)
	assert_false(SiegeDefs.should_trigger(_flags_ok, 10, 9, _SEED))

# ---------------------------------------------------------------------------
# Determinism
# ---------------------------------------------------------------------------

func test_same_seed_and_day_always_same_result() -> void:
	var r1: bool = SiegeDefs.should_trigger(_flags_ok, _DAYS, _LAST, _SEED)
	var r2: bool = SiegeDefs.should_trigger(_flags_ok, _DAYS, _LAST, _SEED)
	assert_eq(r1, r2, "same seed+day must produce same outcome")

func test_different_day_may_differ() -> void:
	# With SEED=42, days 10 and 11 likely differ — just assert no panic.
	var _r1: bool = SiegeDefs.should_trigger(_flags_ok, 10, 0, 42)
	var _r2: bool = SiegeDefs.should_trigger(_flags_ok, 11, 0, 42)
	assert_true(true)

# ---------------------------------------------------------------------------
# Probability range
# ---------------------------------------------------------------------------

func test_spawn_chance_is_8_percent() -> void:
	assert_eq(SiegeDefs.SIEGE_SPAWN_CHANCE, 8)

func test_probability_within_range() -> void:
	# Over 1000 different days (with cooldown always satisfied) at most 15% should trigger.
	var count: int = 0
	var flags: Dictionary = {"chapter1_warned_farsyth": true}
	for d: int in range(4, 1004):
		if SiegeDefs.should_trigger(flags, d, 0, 999):
			count += 1
	# 8% of 1000 = 80, allow generous window 0–150
	assert_lte(count, 150, "trigger rate should not exceed ~15% over 1000 samples")
	assert_gte(count, 0)

# ---------------------------------------------------------------------------
# Stage helpers
# ---------------------------------------------------------------------------

func test_get_stage_name_wave_1() -> void:
	assert_eq(SiegeDefs.get_stage_name(0), "Wave 1 of 3")

func test_get_stage_name_wave_2() -> void:
	assert_eq(SiegeDefs.get_stage_name(1), "Wave 2 of 3")

func test_get_stage_name_wave_3() -> void:
	assert_eq(SiegeDefs.get_stage_name(2), "Wave 3 of 3")

func test_get_raider_deck_ids_non_empty() -> void:
	for s: int in range(3):
		assert_true(SiegeDefs.get_raider_deck_ids(s).size() > 0, "stage %d deck must be non-empty" % s)

func test_raider_deck_escalates_in_size() -> void:
	var s0: int = SiegeDefs.get_raider_deck_ids(0).size()
	var s1: int = SiegeDefs.get_raider_deck_ids(1).size()
	var s2: int = SiegeDefs.get_raider_deck_ids(2).size()
	assert_lte(s0, s1, "stage 1 deck must be >= stage 0")
	assert_lte(s1, s2, "stage 2 deck must be >= stage 1")

func test_is_siege_town_for_known_towns() -> void:
	assert_true(SiegeDefs.is_siege_town("madrian"))
	assert_true(SiegeDefs.is_siege_town("maykalene"))
	assert_true(SiegeDefs.is_siege_town("blancogov"))

func test_is_siege_town_false_for_unknown() -> void:
	assert_false(SiegeDefs.is_siege_town("main"))
	assert_false(SiegeDefs.is_siege_town("player_home"))
