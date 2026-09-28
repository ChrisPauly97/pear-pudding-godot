## Journal Quests tab (GID-140): lists active quests + story so far, Track button.
extends "res://tests/framework/test_case.gd"

const JournalScene = preload("res://scenes/ui/JournalScene.gd")

var _j: Node = null
var _saved_flags: Dictionary = {}
var _saved_tracked: String = ""
var _saved_treasure: Dictionary = {}


func before_each() -> void:
	_saved_flags = SaveManager.story_flags.duplicate()
	_saved_tracked = SaveManager.tracked_quest
	_saved_treasure = SaveManager.active_treasure.duplicate()


func after_each() -> void:
	SaveManager.story_flags = _saved_flags
	SaveManager.tracked_quest = _saved_tracked
	SaveManager.active_treasure = _saved_treasure
	if is_instance_valid(_j):
		_j.free()


func _buttons(root: Node, out: Array[Button] = []) -> Array[Button]:
	for c in root.get_children():
		if c is Button:
			out.append(c as Button)
		_buttons(c, out)
	return out


func _open() -> Node:
	# The unit runner is synchronous: _ready never fires, so build by hand.
	_j = JournalScene.new()
	_j.call("_build_ui")
	_j.call("_on_tab_selected", "quests")
	return _j


func _texts() -> Array[String]:
	var out: Array[String] = []
	for b: Button in _buttons(_j):
		out.append(b.text)
	return out


func test_lists_story_quest_and_story_so_far() -> void:
	SaveManager.story_flags = {"story_intro_complete": true, "chapter1_left_madrian": true}
	SaveManager.active_treasure = {}
	_open()
	var texts: Array[String] = _texts()
	assert_true(texts.has("★ Make camp for the night"), "current step listed and tracked: %s" % str(texts))
	assert_true(texts.has("✓ Speak to Maiteln"), "finished steps listed")
	assert_true(texts.has("✓ Leave Madrian"))


func test_track_button_switches_tracked_quest() -> void:
	SaveManager.story_flags = {}
	SaveManager.active_treasure = {"site_x": 10, "site_z": 10, "completed": false}
	SaveManager.tracked_quest = ""
	_open()
	_j.call("_on_quest_selected", "treasure")
	var track: Button = _j.get("_track_btn")
	assert_eq(track.text, "Track")
	_j.call("_on_track_pressed")
	assert_eq(SaveManager.tracked_quest, "treasure", "tracked quest saved")
	assert_eq(track.text, "Tracking")
	assert_true(_texts().has("★ Dig at the treasure site"))
