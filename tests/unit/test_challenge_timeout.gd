## Unit tests for ChallengeTimeout (GID-115 / TID-431, fixes BID-034) — the pure
## expiry check backing PvP challenge/wager/draft-duel handshake timeouts.
## Mirrors test_scene_manager_state.gd's style for a small pure predicate.
extends "res://tests/framework/test_case.gd"

const ChallengeTimeout = preload("res://game_logic/net/ChallengeTimeout.gd")


func test_not_expired_when_idle() -> void:
	assert_false(ChallengeTimeout.has_expired(-1, 999999999))


func test_not_expired_before_timeout_elapses() -> void:
	var armed_at: int = 1000
	var now: int = armed_at + ChallengeTimeout.TIMEOUT_MSEC - 1
	assert_false(ChallengeTimeout.has_expired(armed_at, now))


func test_expired_exactly_at_timeout() -> void:
	var armed_at: int = 1000
	var now: int = armed_at + ChallengeTimeout.TIMEOUT_MSEC
	assert_true(ChallengeTimeout.has_expired(armed_at, now))


func test_expired_well_past_timeout() -> void:
	var armed_at: int = 1000
	var now: int = armed_at + ChallengeTimeout.TIMEOUT_MSEC * 5
	assert_true(ChallengeTimeout.has_expired(armed_at, now))


func test_not_expired_immediately_after_arming() -> void:
	var armed_at: int = 5000
	assert_false(ChallengeTimeout.has_expired(armed_at, armed_at))
