## Shape of the save migration table (SaveMigrations). The per-feature suites
## check individual rows. This one checks the table as a whole: it is ordered,
## it ends at CURRENT_VERSION, and SaveManager writes that same version.
extends "res://tests/framework/test_case.gd"

const _SaveMigrations = preload("res://game_logic/save/SaveMigrations.gd")
const _SaveManagerScript = preload("res://autoloads/SaveManager.gd")


func test_rows_are_strictly_ascending() -> void:
	var prev: int = 0
	for row: Array in _SaveMigrations.table():
		var target: int = row[0]
		assert_true(target > prev, "row %d after %d" % [target, prev])
		prev = target


func test_last_row_is_current_version() -> void:
	var rows: Array = _SaveMigrations.table()
	assert_eq(int(rows[rows.size() - 1][0]), _SaveMigrations.CURRENT_VERSION)


func test_save_manager_writes_current_version() -> void:
	assert_eq(_SaveManagerScript.CURRENT_SAVE_VERSION, _SaveMigrations.CURRENT_VERSION)


func test_empty_save_migrates_to_current() -> void:
	var data: Dictionary = {}
	_SaveMigrations.apply(data)
	assert_eq(int(data["version"]), _SaveMigrations.CURRENT_VERSION)


func test_up_to_stops_at_that_row() -> void:
	var data: Dictionary = {"version": 19}
	_SaveMigrations.apply(data, 20)
	assert_eq(int(data["version"]), 20)
	assert_true(data.has("treasure_fragments"))
	assert_false(data.has("activated_waystones"), "the v21 row must not run")


func test_callable_rows_bump_version() -> void:
	for row: Array in _SaveMigrations.table():
		if row[1] is Callable:
			var target: int = row[0]
			var data: Dictionary = {"version": target - 1}
			(row[1] as Callable).call(data)
			assert_eq(int(data["version"]), target, "Callable row %d must set version" % target)


func get_suite_name() -> String:
	return "SaveMigrations"
