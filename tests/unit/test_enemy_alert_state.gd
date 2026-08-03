## Unit tests for EnemyAlertState.gd (pure detection/pursuit state machine, GID-113).
extends "res://tests/framework/test_case.gd"

const EnemyAlertState = preload("res://game_logic/world/EnemyAlertState.gd")

const _AWARENESS_RANGE: float = 6.0
const _GIVEUP_RANGE: float = 9.0
const _REACTION_TIME: float = 0.4
const _HOLD_TIME: float = 2.0

# ---------------------------------------------------------------------------
# check_awareness
# ---------------------------------------------------------------------------

func test_awareness_distance_below_radius_stays_idle() -> void:
	var state: int = EnemyAlertState.check_awareness(EnemyAlertState.State.IDLE, 10.0, _AWARENESS_RANGE)
	assert_eq(state, EnemyAlertState.State.IDLE)

func test_awareness_distance_within_radius_becomes_alerted() -> void:
	var state: int = EnemyAlertState.check_awareness(EnemyAlertState.State.IDLE, 4.0, _AWARENESS_RANGE)
	assert_eq(state, EnemyAlertState.State.ALERTED)

func test_awareness_exactly_at_radius_becomes_alerted() -> void:
	var state: int = EnemyAlertState.check_awareness(EnemyAlertState.State.IDLE, _AWARENESS_RANGE, _AWARENESS_RANGE)
	assert_eq(state, EnemyAlertState.State.ALERTED)

func test_awareness_already_chasing_is_unaffected() -> void:
	var state: int = EnemyAlertState.check_awareness(EnemyAlertState.State.CHASING, 1.0, _AWARENESS_RANGE)
	assert_eq(state, EnemyAlertState.State.CHASING)

# ---------------------------------------------------------------------------
# tick_reaction
# ---------------------------------------------------------------------------

func test_reaction_not_yet_elapsed_stays_alerted() -> void:
	var result: Dictionary = EnemyAlertState.tick_reaction(EnemyAlertState.State.ALERTED, 0.0, 0.1, _REACTION_TIME)
	assert_eq(int(result["state"]), EnemyAlertState.State.ALERTED)
	assert_almost_eq(float(result["alert_timer"]), 0.1, 0.001)

func test_reaction_elapsed_becomes_chasing() -> void:
	var result: Dictionary = EnemyAlertState.tick_reaction(EnemyAlertState.State.ALERTED, 0.35, 0.1, _REACTION_TIME)
	assert_eq(int(result["state"]), EnemyAlertState.State.CHASING)
	assert_eq(float(result["alert_timer"]), 0.0)

func test_reaction_noop_outside_alerted() -> void:
	var result: Dictionary = EnemyAlertState.tick_reaction(EnemyAlertState.State.IDLE, 5.0, 0.1, _REACTION_TIME)
	assert_eq(int(result["state"]), EnemyAlertState.State.IDLE)
	assert_eq(float(result["alert_timer"]), 5.0)

# ---------------------------------------------------------------------------
# tick_giveup
# ---------------------------------------------------------------------------

func test_giveup_noop_at_idle() -> void:
	var result: Dictionary = EnemyAlertState.tick_giveup(
		EnemyAlertState.State.IDLE, 0.0, 1.0, 50.0, _GIVEUP_RANGE, _HOLD_TIME)
	assert_eq(int(result["state"]), EnemyAlertState.State.IDLE)
	assert_false(bool(result["gave_up"]))

func test_giveup_within_range_resets_timer() -> void:
	var result: Dictionary = EnemyAlertState.tick_giveup(
		EnemyAlertState.State.CHASING, 1.5, 0.1, 3.0, _GIVEUP_RANGE, _HOLD_TIME)
	assert_eq(float(result["giveup_timer"]), 0.0)
	assert_eq(int(result["state"]), EnemyAlertState.State.CHASING)
	assert_false(bool(result["gave_up"]))

func test_giveup_beyond_range_accumulates_without_reverting_immediately() -> void:
	var result: Dictionary = EnemyAlertState.tick_giveup(
		EnemyAlertState.State.CHASING, 0.0, 0.5, _GIVEUP_RANGE + 1.0, _GIVEUP_RANGE, _HOLD_TIME)
	assert_eq(int(result["state"]), EnemyAlertState.State.CHASING)
	assert_almost_eq(float(result["giveup_timer"]), 0.5, 0.001)
	assert_false(bool(result["gave_up"]))

func test_giveup_sustained_duration_reverts_to_idle() -> void:
	var result: Dictionary = EnemyAlertState.tick_giveup(
		EnemyAlertState.State.CHASING, 1.9, 0.5, _GIVEUP_RANGE + 1.0, _GIVEUP_RANGE, _HOLD_TIME)
	assert_eq(int(result["state"]), EnemyAlertState.State.IDLE)
	assert_eq(float(result["giveup_timer"]), 0.0)
	assert_true(bool(result["gave_up"]))

func test_giveup_from_alerted_also_reverts() -> void:
	var result: Dictionary = EnemyAlertState.tick_giveup(
		EnemyAlertState.State.ALERTED, 1.9, 0.5, _GIVEUP_RANGE + 1.0, _GIVEUP_RANGE, _HOLD_TIME)
	assert_eq(int(result["state"]), EnemyAlertState.State.IDLE)
	assert_true(bool(result["gave_up"]))

# A brief re-entry into range mid-accumulation resets the clock instead of
# carrying partial progress toward giving up (no boundary flicker).
func test_giveup_reentry_resets_before_threshold() -> void:
	var accumulating: Dictionary = EnemyAlertState.tick_giveup(
		EnemyAlertState.State.CHASING, 0.0, 1.5, _GIVEUP_RANGE + 1.0, _GIVEUP_RANGE, _HOLD_TIME)
	assert_almost_eq(float(accumulating["giveup_timer"]), 1.5, 0.001)
	var reentered: Dictionary = EnemyAlertState.tick_giveup(
		EnemyAlertState.State.CHASING, float(accumulating["giveup_timer"]), 0.1, 2.0, _GIVEUP_RANGE, _HOLD_TIME)
	assert_eq(float(reentered["giveup_timer"]), 0.0)
	assert_false(bool(reentered["gave_up"]))

# ---------------------------------------------------------------------------
# classify_ambush
# ---------------------------------------------------------------------------

func test_classify_ambush_idle_is_player_ambush() -> void:
	var result: Dictionary = EnemyAlertState.classify_ambush(EnemyAlertState.State.IDLE)
	assert_true(bool(result["player_ambush"]))
	assert_false(bool(result["enemy_ambush"]))

func test_classify_ambush_chasing_is_enemy_ambush() -> void:
	var result: Dictionary = EnemyAlertState.classify_ambush(EnemyAlertState.State.CHASING)
	assert_false(bool(result["player_ambush"]))
	assert_true(bool(result["enemy_ambush"]))

func test_classify_ambush_alerted_is_neutral() -> void:
	var result: Dictionary = EnemyAlertState.classify_ambush(EnemyAlertState.State.ALERTED)
	assert_false(bool(result["player_ambush"]))
	assert_false(bool(result["enemy_ambush"]))

func test_classify_ambush_flags_are_mutually_exclusive() -> void:
	for state: int in [EnemyAlertState.State.IDLE, EnemyAlertState.State.ALERTED, EnemyAlertState.State.CHASING]:
		var result: Dictionary = EnemyAlertState.classify_ambush(state)
		var both: bool = bool(result["player_ambush"]) and bool(result["enemy_ambush"])
		assert_false(both)

# ---------------------------------------------------------------------------
# Full-cycle: give-up correctly re-arms the ambush bonus (Research Notes case 5)
# ---------------------------------------------------------------------------

func test_give_up_then_recontact_is_player_ambush_again() -> void:
	# Simulate: chasing, player escapes beyond giveup range for the full hold time.
	var result: Dictionary = EnemyAlertState.tick_giveup(
		EnemyAlertState.State.CHASING, _HOLD_TIME - 0.1, 0.2, _GIVEUP_RANGE + 2.0, _GIVEUP_RANGE, _HOLD_TIME)
	assert_true(bool(result["gave_up"]))
	var reverted_state: int = int(result["state"])
	assert_eq(reverted_state, EnemyAlertState.State.IDLE)
	# A subsequent contact from the reverted state is a player_ambush again.
	var ambush: Dictionary = EnemyAlertState.classify_ambush(reverted_state)
	assert_true(bool(ambush["player_ambush"]))
