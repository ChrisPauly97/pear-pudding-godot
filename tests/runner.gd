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
##
## Test suites are auto-discovered from tests/unit/test_*.gd — no need to
## register new files here. Add a test file and it runs automatically.
extends SceneTree


func _initialize() -> void:
	var total_pass := 0
	var total_fail := 0
	var total_pending := 0

	print("\n===== Pear Pudding TCG — Unit Tests =====\n")

	var dir := DirAccess.open("res://tests/unit")
	var files: Array[String] = []
	if dir != null:
		dir.list_dir_begin()
		var fname := dir.get_next()
		while fname != "":
			if fname.begins_with("test_") and fname.ends_with(".gd"):
				files.append(fname)
			fname = dir.get_next()
		dir.list_dir_end()
	files.sort()

	for fname in files:
		var path := "res://tests/unit/" + fname
		var suite_script: GDScript = load(path)
		if suite_script == null or not suite_script.can_instantiate():
			print("  [SKIP] %s (compile error or missing dependency)" % fname)
			total_fail += 1
			continue
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
