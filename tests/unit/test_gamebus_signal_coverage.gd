## GameBus signal-coverage guardrail (BID-056).
##
## Two failure modes this catches, both silent:
##
## 1. **Declared but never emitted.** A signal that nothing emits reads as
##    working to any future subscriber — it connects fine and simply never
##    fires, so the feature under-reports instead of failing loudly. BID-006
##    found three of these in the battle layer; BID-056 found `exited_to_world`
##    still dangling after that fix.
##
## 2. **Emitted/connected but not declared.** The dangerous direction. Per
##    CLAUDE.md's "Dead signal connect aborted `_ready`" learning, referencing a
##    nonexistent GameBus signal throws, and a throwing statement in the tail of
##    `_ready` silently kills every statement appended after it.
##
## Static source-text scan rather than live introspection, matching the
## precedent set by test_hud_registry_guardrail.gd and test_card_registry.gd:
## GameBus's collaborators have heavy scene-tree dependencies unsuited to
## headless instantiation.
##
## Note both emission spellings are recognised. `X.emit()` is compile-checked;
## `emit_signal("X")` is not, and a typo in the string form fails silently — so
## the string form is accepted here but is not the preferred style.
extends "res://tests/framework/test_case.gd"

const _GAME_BUS_PATH := "res://autoloads/GameBus.gd"
const _SCAN_ROOTS: Array[String] = [
	"res://autoloads",
	"res://ai",
	"res://game_logic",
	"res://scenes",
]

## Signals intentionally declared without an emitter. Each entry needs a reason.
## Adding one to silence this test is a signal to first check whether the
## feature that was supposed to emit it is actually finished.
const _ALLOWED_UNEMITTED: Array[String] = []

var _declared: Array[String] = []
var _sources: String = ""


func get_suite_name() -> String:
	return "test_gamebus_signal_coverage"


func before_all() -> void:
	_declared = _read_declared_signals()
	_sources = _read_all_sources()


func _read_declared_signals() -> Array[String]:
	var out: Array[String] = []
	var f := FileAccess.open(_GAME_BUS_PATH, FileAccess.READ)
	if f == null:
		return out
	var re := RegEx.new()
	re.compile("^signal\\s+([a-zA-Z_][a-zA-Z0-9_]*)")
	while not f.eof_reached():
		var m := re.search(f.get_line())
		if m != null:
			out.append(m.get_string(1))
	f.close()
	return out


func _read_all_sources() -> String:
	var parts: PackedStringArray = []
	for root: String in _SCAN_ROOTS:
		_collect_dir(root, parts)
	return "\n".join(parts)


func _collect_dir(path: String, parts: PackedStringArray) -> void:
	var dir := DirAccess.open(path)
	if dir == null:
		return
	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "":
		var full: String = path + "/" + entry
		if dir.current_is_dir():
			if not entry.begins_with("."):
				_collect_dir(full, parts)
		elif entry.ends_with(".gd"):
			var f := FileAccess.open(full, FileAccess.READ)
			if f != null:
				parts.append(f.get_as_text())
				f.close()
		entry = dir.get_next()
	dir.list_dir_end()


func _is_emitted(sig: String) -> bool:
	# Typed form on the autoload or on a cached local reference
	# (WorldEventManager holds `_game_bus`, WorldEvents holds `game_bus`).
	if _sources.contains("." + sig + ".emit("):
		return true
	# String form — not compile-checked, but a real emission.
	return _sources.contains("emit_signal(\"" + sig + "\"")


func test_gamebus_declares_signals() -> void:
	assert_gt(_declared.size(), 0, "no `signal` declarations parsed from GameBus.gd")


func test_every_declared_signal_is_emitted() -> void:
	var dangling: Array[String] = []
	for sig: String in _declared:
		if _ALLOWED_UNEMITTED.has(sig):
			continue
		if not _is_emitted(sig):
			dangling.append(sig)
	assert_eq(
		dangling,
		[] as Array[String],
		"GameBus signals declared but never emitted — wire them or remove them: %s" % str(dangling)
	)


func test_every_referenced_gamebus_signal_is_declared() -> void:
	# Catches the _ready-killing case: GameBus.<name>.connect/emit where <name>
	# was renamed or removed from GameBus.gd.
	var re := RegEx.new()
	re.compile("GameBus\\.([a-z_][a-z0-9_]*)\\.(?:emit|connect|disconnect|is_connected)\\b")
	var unknown: Array[String] = []
	for m: RegExMatch in re.search_all(_sources):
		var name: String = m.get_string(1)
		if not _declared.has(name) and not unknown.has(name):
			unknown.append(name)
	assert_eq(
		unknown,
		[] as Array[String],
		"referenced on GameBus but not declared in GameBus.gd (throws, aborting the rest of _ready): %s" % str(unknown)
	)


func test_string_form_emit_signal_names_are_declared() -> void:
	# `bus.emit_signal("name")` is NOT compile-checked — a typo emits nothing and
	# raises nothing, so it fails completely silently. Validate the string
	# literals against GameBus's declarations for the call sites that target the
	# bus (WorldEventManager holds `_game_bus`, WorldEvents holds `game_bus`).
	var re := RegEx.new()
	re.compile("(?:GameBus|_?game_bus)\\.emit_signal\\(\"([a-z_][a-z0-9_]*)\"")
	var unknown: Array[String] = []
	for m: RegExMatch in re.search_all(_sources):
		var name: String = m.get_string(1)
		if not _declared.has(name) and not unknown.has(name):
			unknown.append(name)
	assert_eq(
		unknown,
		[] as Array[String],
		"emit_signal(\"...\") names not declared on GameBus — these emit nothing, silently: %s" % str(unknown)
	)
