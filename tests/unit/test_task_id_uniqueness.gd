## Guardrail suggested by BID-057: TID/GID/BID ids must be globally unique
## across tasks/, so a collision is caught the moment it's created rather than
## at merge time (BID-057 found GID-123/TID-466-468 collided with main, and
## TID-352 collides between GID-096 and GID-097 — the latter is a documented,
## accepted exception since both tasks predate discovery and are complete).
extends "res://tests/framework/test_case.gd"

## TID-352 is used by both GID-096 and GID-097 (BID-057) — both complete,
## left unrenumbered per that item's own resolution. No other duplicate is
## allowed.
const _KNOWN_TID_DUPES: Array[String] = ["TID-352"]

static func _list_files_recursive(path: String, out: Array[String]) -> void:
	var dir := DirAccess.open(path)
	if dir == null:
		return
	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "":
		if entry != "." and entry != "..":
			var full: String = path.path_join(entry)
			if dir.current_is_dir():
				_list_files_recursive(full, out)
			else:
				out.append(entry)
		entry = dir.get_next()
	dir.list_dir_end()

static func _collect_ids(root: String, prefix: String) -> Dictionary:
	var files: Array[String] = []
	_list_files_recursive(root, files)
	var re := RegEx.new()
	re.compile("^(%s-\\d+)--" % prefix)
	var counts: Dictionary = {}
	for f: String in files:
		var m := re.search(f)
		if m == null:
			continue
		var id: String = m.get_string(1)
		counts[id] = int(counts.get(id, 0)) + 1
	return counts

func test_tid_ids_are_unique_except_known_dupes() -> void:
	var counts: Dictionary = _collect_ids("res://tasks/goals", "TID")
	for id: String in counts.keys():
		var count: int = int(counts[id])
		if count > 1:
			assert_true(_KNOWN_TID_DUPES.has(id),
				"TID id '%s' appears %d times — not in the known-exceptions list" % [id, count])

func test_gid_ids_are_unique() -> void:
	var dir := DirAccess.open("res://tasks/goals")
	assert_not_null(dir, "tasks/goals directory must be readable")
	var re := RegEx.new()
	re.compile("^(GID-\\d+)--")
	var counts: Dictionary = {}
	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "":
		if entry != "." and entry != "..":
			var m := re.search(entry)
			if m != null:
				var id: String = m.get_string(1)
				counts[id] = int(counts.get(id, 0)) + 1
		entry = dir.get_next()
	dir.list_dir_end()
	for id: String in counts.keys():
		assert_eq(int(counts[id]), 1, "GID id '%s' names more than one goal directory" % id)

func test_bid_ids_are_unique_across_open_and_resolved() -> void:
	var counts: Dictionary = _collect_ids("res://tasks/backlog", "BID")
	var resolved: Dictionary = _collect_ids("res://tasks/archive/backlog", "BID")
	for id: String in resolved.keys():
		counts[id] = int(counts.get(id, 0)) + int(resolved[id])
	for id: String in counts.keys():
		assert_eq(int(counts[id]), 1, "BID id '%s' appears more than once across open+resolved backlog" % id)
