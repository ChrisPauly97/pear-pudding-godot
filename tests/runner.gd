## Headless test runner for Pear Pudding TCG.
##
## Usage:
##   godot --headless --path /path/to/project -s tests/runner.gd
##
## The --path flag ensures autoloads (IsoConst, GameBus, SceneManager) are
## initialised before any test runs, mirroring the production environment.
##
## Exit codes:
##   0  — all tests passed
##   1  — one or more tests failed
extends SceneTree

const SUITES: Array = [
	preload("res://tests/unit/test_card_instance.gd"),
	preload("res://tests/unit/test_hero_state.gd"),
	preload("res://tests/unit/test_zone_state.gd"),
	preload("res://tests/unit/test_player_state.gd"),
	preload("res://tests/unit/test_game_state.gd"),
	preload("res://tests/unit/test_world_entity.gd"),
	preload("res://tests/unit/test_iso_const.gd"),
	preload("res://tests/unit/test_basic_ai.gd"),
	preload("res://tests/unit/test_card_registry.gd"),
	preload("res://tests/unit/test_chunk_data.gd"),
	preload("res://tests/unit/test_infinite_world_gen.gd"),
	preload("res://tests/unit/test_terrain_math.gd"),
]


func _initialize() -> void:
	var total_pass := 0
	var total_fail := 0
	var total_pending := 0

	print("\n===== Pear Pudding TCG — Unit Tests =====\n")

	for suite_script in SUITES:
		var suite = suite_script.new()
		var suite_name: String = suite.get_suite_name()
		print("  Suite: %s" % suite_name)
		suite.run_all()
		total_pass += suite.pass_count
		total_fail += suite.fail_count
		total_pending += suite.pending_count
		print("")

	print("=========================================")
	print("  Passed:  %d" % total_pass)
	print("  Failed:  %d" % total_fail)
	if total_pending > 0:
		print("  Pending: %d" % total_pending)
	print("=========================================\n")

	if total_fail > 0:
		print("RESULT: FAIL\n")
		quit(1)
	else:
		print("RESULT: PASS\n")
		quit(0)
