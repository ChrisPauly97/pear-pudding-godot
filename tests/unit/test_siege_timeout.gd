## Tests that sieges time out correctly after 1 in-game day via increment_day().
extends "res://tests/framework/test_case.gd"

const SaveManagerScript = preload("res://autoloads/SaveManager.gd")

var _sm: Node

func before_each() -> void:
	_sm = SaveManagerScript.new()
	_sm._loaded = true

func after_each() -> void:
	_sm.free()

# ---------------------------------------------------------------------------
# Siege timeout via increment_day
# ---------------------------------------------------------------------------

func test_siege_persists_same_day() -> void:
	_sm.days_elapsed = 5
	_sm.start_siege("madrian")
	# No day rollover yet — siege must still be active.
	assert_false(_sm.get_active_siege().is_empty(), "siege must persist within the same day")

func test_siege_cleared_after_1_day_rollover() -> void:
	_sm.days_elapsed = 5
	_sm.start_siege("madrian")   # day_started = 5
	_sm.increment_day()          # days_elapsed → 6; age = 6-5 = 1 >= 1 → timeout
	assert_true(_sm.get_active_siege().is_empty(), "siege must clear after 1 day")

func test_siege_timeout_updates_last_siege_day() -> void:
	_sm.days_elapsed = 3
	_sm.start_siege("maykalene")
	_sm.increment_day()   # days_elapsed → 4; timeout fires → end_siege_defeat()
	assert_eq(_sm.last_siege_day, 4, "last_siege_day should be updated on timeout")

func test_no_siege_increment_day_works_normally() -> void:
	_sm.days_elapsed = 0
	_sm.increment_day()
	assert_eq(_sm.days_elapsed, 1)
	assert_true(_sm.get_active_siege().is_empty())

func test_siege_started_today_does_not_clear_same_rollover() -> void:
	# Siege started on day 5; rollover immediately to day 6 → age = 1 → clears.
	# Rollover before siege (day 4 → 5), then start: siege starts on day 5, no rollover → persists.
	_sm.days_elapsed = 4
	_sm.increment_day()   # days_elapsed → 5
	_sm.start_siege("madrian")   # day_started = 5
	# Siege just started, no further rollover — must still be active.
	assert_false(_sm.get_active_siege().is_empty())
