## GID-188 / TID-799: playtest fun metrics — first-time stamps, counters, the quit
## point, and the save round-trip.
extends "res://tests/framework/test_case.gd"

const PlaytestMetrics = preload("res://game_logic/PlaytestMetrics.gd")
const SaveManagerScript = preload("res://autoloads/SaveManager.gd")


func test_first_stamps_keep_the_first_time() -> void:
	var m: Dictionary = {}
	PlaytestMetrics.tick(m, 90.0)
	PlaytestMetrics.note(m, PlaytestMetrics.FIGHT)
	PlaytestMetrics.tick(m, 30.0)
	PlaytestMetrics.note(m, PlaytestMetrics.FIGHT)
	assert_almost_eq(PlaytestMetrics.first_at(m, PlaytestMetrics.FIGHT), 90.0)
	assert_eq(PlaytestMetrics.count_of(m, PlaytestMetrics.FIGHT), 2)
	assert_almost_eq(PlaytestMetrics.first_at(m, PlaytestMetrics.CAPTURE), -1.0, 0.0001, "never captured")


func test_last_event_is_the_quit_point_and_sessions_do_not_move_it() -> void:
	var m: Dictionary = {}
	PlaytestMetrics.tick(m, 10.0)
	PlaytestMetrics.note(m, PlaytestMetrics.DECK_EDIT)
	PlaytestMetrics.note(m, PlaytestMetrics.SESSION)
	var last: Dictionary = m["last"]
	assert_eq(str(last["event"]), PlaytestMetrics.DECK_EDIT)
	assert_eq(int(m["sessions"]), 1)


func test_summary_reads_like_a_report() -> void:
	var m: Dictionary = {}
	PlaytestMetrics.tick(m, 125.0)
	PlaytestMetrics.note(m, PlaytestMetrics.CAPTURE)
	var lines: Array[String] = PlaytestMetrics.summary(m)
	assert_has(lines, "First capture at: 2m 05s")
	assert_has(lines, "First fight at: —")
	assert_has(lines, "Captures: 1")
	assert_eq(PlaytestMetrics.clock(3725.0), "1h 02m")


func test_capture_and_win_are_recorded_from_a_battle_result() -> void:
	var sm: SaveManagerScript = SaveManagerScript.new()
	sm.playtest_log.call("_on_won", {"signature_capture": "sig_wanderer"})
	sm.playtest_log.call("_on_won", {})
	assert_eq(PlaytestMetrics.count_of(sm.playtest, PlaytestMetrics.WIN), 2)
	assert_eq(PlaytestMetrics.count_of(sm.playtest, PlaytestMetrics.CAPTURE), 1)
	sm.free()


func test_playtest_is_a_persisted_field() -> void:
	assert_true(SaveManagerScript.PERSISTED_FIELDS.has("playtest"))
