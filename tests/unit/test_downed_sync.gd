## Unit tests for DownedSync — the co-op downed/rescue timeout + revive-guard helpers.
extends "res://tests/framework/test_case.gd"

const DownedSync = preload("res://game_logic/net/DownedSync.gd")


# ---------------------------------------------------------------------------
# remaining_time
# ---------------------------------------------------------------------------

func test_remaining_time_at_start_is_full_timeout() -> void:
	assert_almost_eq(DownedSync.remaining_time(0.0), DownedSync.RESCUE_TIMEOUT)


func test_remaining_time_decreases_with_elapsed() -> void:
	var r: float = DownedSync.remaining_time(10.0)
	assert_almost_eq(r, DownedSync.RESCUE_TIMEOUT - 10.0)


func test_remaining_time_clamps_to_zero_past_timeout() -> void:
	var r: float = DownedSync.remaining_time(DownedSync.RESCUE_TIMEOUT + 30.0)
	assert_almost_eq(r, 0.0)


func test_remaining_time_at_exact_timeout_is_zero() -> void:
	var r: float = DownedSync.remaining_time(DownedSync.RESCUE_TIMEOUT)
	assert_almost_eq(r, 0.0)


# ---------------------------------------------------------------------------
# can_revive — race-guard predicate
# ---------------------------------------------------------------------------

func test_can_revive_true_when_target_downed() -> void:
	assert_true(DownedSync.can_revive(true), "a currently-downed target should be revivable")


func test_can_revive_false_when_target_not_downed() -> void:
	# Stale request: the target already respawned via timeout or was already revived.
	assert_false(DownedSync.can_revive(false), "a non-downed target must not be revivable")
