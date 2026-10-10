## Guardrail (GID-181 / TID-749): every damage event goes through DamageResolver.deal.
##
## Static source scan of the production code (game_logic/, scenes/, autoloads/, ai/,
## tools/). Any direct `take_damage(` call outside the resolver fails here, so a new
## damage site cannot skip the school profile. Only the resolver itself and the raw
## definitions on HeroState / CardInstance are allowed. tests/ is not scanned: unit
## tests set HP up by calling take_damage directly, which is fixture setup, not a game
## damage event.
extends "res://tests/framework/test_case.gd"

const _SCAN_ROOTS: Array[String] = [
	"res://game_logic", "res://scenes", "res://autoloads", "res://ai", "res://tools",
]
## Files allowed to contain `take_damage(`: the resolver and the raw HP operations.
const _ALLOWED_FILES: Array[String] = [
	"res://game_logic/battle/DamageResolver.gd",
	"res://game_logic/battle/HeroState.gd",
	"res://game_logic/battle/CardInstance.gd",
]
const _NEEDLE: String = "take_damage("

func test_no_direct_take_damage_outside_the_resolver() -> void:
	var files: Array[String] = []
	for root: String in _SCAN_ROOTS:
		_collect_gd(root, files)
	# Sanity: the scan must actually see the battle code, or a broken walk passes silently.
	assert_gt(files.size(), 40, "guardrail scanned too few .gd files")
	var offenders: Array[String] = []
	for path: String in files:
		if _ALLOWED_FILES.has(path):
			continue
		var lines: PackedStringArray = _read_file(path).split("\n")
		for i: int in range(lines.size()):
			var line: String = lines[i].strip_edges()
			if line.begins_with("#") or line.begins_with("func take_damage("):
				continue
			if line.contains(_NEEDLE):
				offenders.append("%s:%d: %s" % [path, i + 1, line])
	assert_eq(offenders.size(), 0,
		"direct take_damage( outside DamageResolver (use DamageResolver.deal):\n" + "\n".join(offenders))

func test_allow_listed_files_exist() -> void:
	# If an allow-listed file moves, the scan above would silently exempt nothing; fail loudly.
	for path: String in _ALLOWED_FILES:
		assert_true(FileAccess.file_exists(path), "allow-listed file missing: " + path)

func _collect_gd(dir_path: String, out: Array[String]) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return
	dir.list_dir_begin()
	var entry: String = dir.get_next()
	while entry != "":
		if not entry.begins_with("."):
			var full: String = dir_path + "/" + entry
			if dir.current_is_dir():
				_collect_gd(full, out)
			elif entry.ends_with(".gd"):
				out.append(full)
		entry = dir.get_next()
	dir.list_dir_end()

func _read_file(path: String) -> String:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return ""
	var text: String = f.get_as_text()
	f.close()
	return text
