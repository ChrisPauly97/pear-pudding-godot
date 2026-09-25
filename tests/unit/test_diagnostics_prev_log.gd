## DiagnosticsScene "Last Session Log": picks the newest rotated engine log.
extends "res://tests/framework/test_case.gd"

const DiagnosticsScene = preload("res://scenes/ui/DiagnosticsScene.gd")

func test_picks_newest_rotated_log_not_current() -> void:
	var files := PackedStringArray([
		"godot.log", "godot2026-09-24T10.00.00.log", "godot2026-09-25T09.30.00.log", "other.txt"])
	assert_eq(DiagnosticsScene.newest_previous_log(files), "godot2026-09-25T09.30.00.log")

func test_no_previous_log() -> void:
	assert_eq(DiagnosticsScene.newest_previous_log(PackedStringArray(["godot.log"])), "")

func test_log_tail_keeps_last_lines() -> void:
	assert_eq(DiagnosticsScene.log_tail("a\nb\nc\nd", 2), "c\nd")
	assert_eq(DiagnosticsScene.log_tail("a\nb", 5), "a\nb")
