## Unit tests for LongPressTracker — the hold timing shared by LongPressDetector
## and the map overlays' long-press waypoint.
extends "res://tests/framework/test_case.gd"

const _Tracker = preload("res://scenes/ui/LongPressTracker.gd")

func test_fires_once_after_threshold() -> void:
	var t := _Tracker.new()
	t.press(Vector2(10, 10))
	assert_false(t.tick(_Tracker.THRESHOLD_SEC * 0.5), "not yet")
	assert_true(t.tick(_Tracker.THRESHOLD_SEC * 0.5), "fires at the threshold")
	assert_false(t.tick(1.0), "fires only once")
	assert_eq(t.start_pos, Vector2(10, 10))

func test_no_fire_without_press() -> void:
	var t := _Tracker.new()
	assert_false(t.tick(10.0))

func test_cancel_stops_hold() -> void:
	var t := _Tracker.new()
	t.press(Vector2.ZERO)
	t.cancel()
	assert_false(t.tick(10.0))

func test_small_move_keeps_hold() -> void:
	var t := _Tracker.new()
	t.press(Vector2.ZERO)
	t.move(Vector2(_Tracker.SLOP_PX - 1.0, 0))
	assert_true(t.is_holding())
	assert_true(t.tick(_Tracker.THRESHOLD_SEC))

func test_move_past_slop_cancels() -> void:
	var t := _Tracker.new()
	t.press(Vector2.ZERO)
	t.move(Vector2(_Tracker.SLOP_PX + 1.0, 0))
	assert_false(t.is_holding())
	assert_false(t.tick(10.0))

func test_new_press_restarts_timer() -> void:
	var t := _Tracker.new()
	t.press(Vector2.ZERO)
	t.tick(_Tracker.THRESHOLD_SEC * 0.9)
	t.press(Vector2(5, 5))
	assert_false(t.tick(_Tracker.THRESHOLD_SEC * 0.5), "timer restarted")
	assert_eq(t.start_pos, Vector2(5, 5))
