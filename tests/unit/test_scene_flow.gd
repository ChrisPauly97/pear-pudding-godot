## SceneManager's state machine (SceneFlow). Checks the transition table's
## shape, and that SceneManager only ever writes `_state` through
## `_transition_to`: a bare assignment would bypass the edge check and the
## `state_changed` signal without any test noticing.
extends "res://tests/framework/test_case.gd"

const _SceneFlow = preload("res://game_logic/SceneFlow.gd")
# gdlint:ignore = constant-name
const State = _SceneFlow.State

var _saved_state: int = -1
var _seen: Array[Array] = []


func before_each() -> void:
	_saved_state = SceneManager._state
	_seen.clear()


func after_each() -> void:
	if SceneManager.state_changed.is_connected(_on_state_changed):
		SceneManager.state_changed.disconnect(_on_state_changed)
	SceneManager._state = _saved_state


func _on_state_changed(from: int, to: int) -> void:
	_seen.append([from, to])


func _read(path: String) -> String:
	var f := FileAccess.open(path, FileAccess.READ)
	return "" if f == null else f.get_as_text()


func test_every_state_has_a_row() -> void:
	for s: int in State.values():
		assert_true(_SceneFlow.TRANSITIONS.has(s), "no TRANSITIONS row for " + _SceneFlow.state_name(s))


func test_every_state_but_menu_is_reachable() -> void:
	for target: int in State.values():
		if target == State.MENU:
			continue
		var reached := false
		for from: int in State.values():
			if from != target and _SceneFlow.can_transition(from, target):
				reached = true
		assert_true(reached, _SceneFlow.state_name(target) + " is unreachable")


func test_world_overlays_only_open_from_world() -> void:
	for overlay: int in _SceneFlow.WORLD_OVERLAYS:
		for from: int in State.values():
			if _SceneFlow.can_transition(from, overlay):
				# The pack-opening ceremony replaces the shop it was bought in.
				var ok: bool = from == State.WORLD or (from == State.SHOP and overlay == State.PACK_OPEN)
				assert_true(ok, "%s -> %s" % [_SceneFlow.state_name(from), _SceneFlow.state_name(overlay)])


func test_world_overlays_close_back_to_world() -> void:
	for overlay: int in _SceneFlow.WORLD_OVERLAYS:
		assert_true(_SceneFlow.can_transition(overlay, State.WORLD), _SceneFlow.state_name(overlay))
		assert_false(_SceneFlow.can_transition(overlay, State.BATTLE), _SceneFlow.state_name(overlay))


func test_battle_is_entered_only_from_world_or_battle() -> void:
	for from: int in State.values():
		if _SceneFlow.can_transition(from, State.BATTLE):
			assert_true(from == State.WORLD or from == State.BATTLE, _SceneFlow.state_name(from))


func test_menu_cannot_jump_into_battle() -> void:
	assert_false(_SceneFlow.can_transition(State.MENU, State.BATTLE))


func test_world_hosted_covers_world_and_overlays_only() -> void:
	assert_true(_SceneFlow.is_world_hosted(State.WORLD))
	assert_true(_SceneFlow.is_world_hosted(State.MENU_HUB))
	assert_false(_SceneFlow.is_world_hosted(State.BATTLE))
	assert_false(_SceneFlow.is_world_hosted(State.MENU))


func test_transition_to_updates_state_and_emits() -> void:
	SceneManager._state = State.WORLD
	SceneManager.state_changed.connect(_on_state_changed)
	SceneManager._transition_to(State.SHOP)
	assert_eq(SceneManager.current_state(), State.SHOP)
	assert_false(SceneManager.is_in_world())
	assert_eq(_seen, [[State.WORLD, State.SHOP]])


func test_scene_manager_writes_state_only_through_transition_to() -> void:
	var src := _read("res://autoloads/SceneManager.gd")
	var re := RegEx.create_from_string("(?m)^\\s*_state\\s*=[^=]")
	var hits := re.search_all(src)
	# Exactly one: the assignment inside _transition_to itself.
	assert_eq(hits.size(), 1, "bare `_state =` outside _transition_to")


func test_no_script_reads_scene_manager_private_state() -> void:
	var re := RegEx.create_from_string("SceneManager\\._state\\b")
	for dir_path: String in ["res://scenes", "res://autoloads", "res://game_logic"]:
		for path: String in _gd_files(dir_path):
			assert_eq(re.search(_read(path)), null, path + " reads SceneManager._state; use current_state()")


func _gd_files(dir_path: String) -> Array[String]:
	var out: Array[String] = []
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return out
	for f: String in dir.get_files():
		if f.ends_with(".gd"):
			out.append(dir_path.path_join(f))
	for d: String in dir.get_directories():
		out.append_array(_gd_files(dir_path.path_join(d)))
	return out


func get_suite_name() -> String:
	return "SceneFlow"
