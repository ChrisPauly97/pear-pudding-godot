## Guards UiUtil.make_tab_row's selection semantics.
##
## LeaderboardOverlay and AuctionHouseOverlay both delegate their tab strip here
## and rely on three behaviours that live entirely inside the click closures:
## re-clicking the active tab is a no-op, the gold highlight follows the
## selection, and `on_select` reports the new index. The closures capture the
## button array and the current-tab box before either is finished being built,
## so this pins down that the capture is by reference.
extends "res://tests/framework/test_case.gd"

const _UiUtil = preload("res://scenes/ui/UiUtil.gd")

const _GOLD := Color(1.0, 0.85, 0.2)

var _parent: Control = null


func before_each() -> void:
	_parent = Control.new()


func after_each() -> void:
	if is_instance_valid(_parent):
		_parent.free()
	_parent = null


func _make(active: int, sink: Array) -> Array[Button]:
	return _UiUtil.make_tab_row(_parent, ["A", "B", "C"], Vector2(10, 10), 12,
		func(tab: int) -> void: sink.append(tab), active)


## True when the button is wearing the active-tab gold override.
func _is_active(btn: Button) -> bool:
	return btn.has_theme_color_override("font_color") \
		and btn.get_theme_color("font_color") == _GOLD


func test_builds_one_button_per_label_parented_to_the_row() -> void:
	var picks: Array = []
	var btns := _make(0, picks)
	assert_eq(btns.size(), 3, "one button per label")
	for b in btns:
		assert_eq(b.get_parent(), _parent, "buttons are parented to the row")
	assert_eq(btns[0].text, "A")
	assert_eq(btns[2].text, "C")


func test_initial_active_tab_is_highlighted() -> void:
	var picks: Array = []
	var btns := _make(1, picks)
	assert_false(_is_active(btns[0]), "inactive tab keeps the theme default")
	assert_true(_is_active(btns[1]), "the tab passed as active starts highlighted")
	assert_false(_is_active(btns[2]), "inactive tab keeps the theme default")
	assert_eq(picks, [], "building the row must not fire on_select")


func test_selecting_another_tab_reports_and_restyles() -> void:
	var picks: Array = []
	var btns := _make(0, picks)
	btns[2].pressed.emit()
	assert_eq(picks, [2], "on_select receives the new index")
	assert_true(_is_active(btns[2]), "the new tab is highlighted")
	assert_false(_is_active(btns[0]), "the old tab is un-highlighted")


func test_reclicking_the_active_tab_is_a_no_op() -> void:
	var picks: Array = []
	var btns := _make(0, picks)
	btns[0].pressed.emit()
	assert_eq(picks, [], "re-clicking the active tab must not re-render")
	btns[1].pressed.emit()
	btns[1].pressed.emit()
	assert_eq(picks, [1], "the second click on the now-active tab is swallowed too")


## make_tab_row invokes `on_select` with exactly one argument. Callers pass a
## bare method reference, and a Callable of the wrong arity fails only at click
## time — no parse error, and the overlays can't be built in the synchronous unit
## runner (they need _ready and an in-tree viewport for their tweens), so nothing
## else here would catch it. Static scan, same approach as
## test_hud_registry_guardrail.
func test_every_make_tab_row_caller_passes_a_one_arg_callback() -> void:
	var callers := _scan_make_tab_row_callers()
	# Named explicitly so a scan that silently stops matching fails here rather
	# than passing over an empty set.
	for expected: String in ["res://scenes/ui/LeaderboardOverlay.gd",
			"res://scenes/ui/AuctionHouseOverlay.gd"]:
		assert_true(callers.has(expected), "scan should find %s (found %s)" % [expected, callers.keys()])
	for path: String in callers:
		var method: String = callers[path]
		var script: GDScript = load(path)
		assert_true(script != null, "%s should load" % path)
		var arity: int = -1
		for m: Dictionary in script.get_script_method_list():
			if str(m.get("name", "")) == method:
				arity = (m.get("args", []) as Array).size()
				break
		assert_ne(arity, -1, "%s passes %s to make_tab_row but declares no such method" % [path, method])
		assert_eq(arity, 1, "%s.%s must take exactly the tab index" % [path, method])


## {script_path: callback_method_name} for every `_UiUtil.make_tab_row(...)` call
## whose callback is a plain method reference.
func _scan_make_tab_row_callers() -> Dictionary:
	var found: Dictionary = {}
	var dir := DirAccess.open("res://scenes/ui")
	if dir == null:
		return found
	# Earlier arguments contain nested calls (Vector2(...), int(...)), so match the
	# call's tail — `, _callback, _active)` — instead of parsing arguments.
	var re := RegEx.new()
	re.compile(r",\s*(_\w+)\s*,\s*_\w+\s*\)")
	dir.list_dir_begin()
	var fname := dir.get_next()
	while fname != "":
		if fname.ends_with(".gd"):
			var path := "res://scenes/ui/" + fname
			var text: String = FileAccess.get_file_as_string(path).replace("\n", " ")
			var at: int = text.find("make_tab_row(")
			if at != -1:
				var m := re.search(text.substr(at, 400))
				if m != null:
					found[path] = m.get_string(1)
		fname = dir.get_next()
	dir.list_dir_end()
	return found


func test_tracks_the_active_tab_across_several_switches() -> void:
	var picks: Array = []
	var btns := _make(0, picks)
	btns[1].pressed.emit()
	btns[2].pressed.emit()
	btns[0].pressed.emit()
	assert_eq(picks, [1, 2, 0], "every genuine change is reported in order")
	assert_true(_is_active(btns[0]), "highlight ends on the last selected tab")
	assert_false(_is_active(btns[1]))
	assert_false(_is_active(btns[2]))
