## Base class for all unit test suites.
##
## Tests are discovered by naming convention: any method starting with "test_"
## is run automatically. Use before_each / after_each for per-test setup and
## teardown; use before_all / after_all for suite-level fixtures.
##
## Compatible with the GUT (Godot Unit Testing) API so tests can be executed
## under GUT without modification once it is installed as a plugin.
##
## Run headlessly with:
##   godot --headless --path . -s tests/runner.gd
extends RefCounted

var pass_count: int = 0
var fail_count: int = 0
var pending_count: int = 0
var _suite_name: String = ""
var _current_test: String = ""
var _test_failed: bool = false


func get_suite_name() -> String:
	return _suite_name if _suite_name != "" else get_script().resource_path.get_file().get_basename()


## Override in subclass for once-per-suite setup (runs before any test_* method).
func before_all() -> void:
	pass


## Override in subclass for once-per-suite teardown (runs after all test_* methods).
func after_all() -> void:
	pass


## Override in subclass for per-test setup (runs before each test_* method).
func before_each() -> void:
	pass


## Override in subclass for per-test teardown (runs after each test_* method).
func after_each() -> void:
	pass


## Discover and run all test_* methods, collect pass/fail counts.
func run_all() -> void:
	before_all()
	for method in get_method_list():
		var mname: String = method["name"]
		if not mname.begins_with("test_"):
			continue
		_current_test = mname
		_test_failed = false
		before_each()
		call(mname)
		after_each()
		if not _test_failed:
			pass_count += 1
			_log_pass(mname)
	after_all()


func _log_pass(test_name: String) -> void:
	print("    [PASS] %s::%s" % [get_suite_name(), test_name])


func _log_fail(test_name: String, message: String) -> void:
	print("    [FAIL] %s::%s — %s" % [get_suite_name(), test_name, message])


func _fail(message: String) -> void:
	if not _test_failed:
		fail_count += 1
		_test_failed = true
	_log_fail(_current_test, message)


# ---------------------------------------------------------------------------
# Assertions
# ---------------------------------------------------------------------------

## Assert two values are equal.
func assert_eq(actual: Variant, expected: Variant, msg: String = "") -> void:
	if actual != expected:
		var detail := "expected [%s] got [%s]" % [expected, actual]
		_fail(detail if msg == "" else "%s — %s" % [msg, detail])


## Assert two values are not equal.
func assert_ne(actual: Variant, not_expected: Variant, msg: String = "") -> void:
	if actual == not_expected:
		var detail := "expected [%s] to differ" % [actual]
		_fail(detail if msg == "" else "%s — %s" % [msg, detail])


## Assert a boolean condition is true.
func assert_true(condition: bool, msg: String = "") -> void:
	if not condition:
		_fail(msg if msg != "" else "expected true, got false")


## Assert a boolean condition is false.
func assert_false(condition: bool, msg: String = "") -> void:
	if condition:
		_fail(msg if msg != "" else "expected false, got true")


## Assert a value is null.
func assert_null(val: Variant, msg: String = "") -> void:
	if val != null:
		_fail(msg if msg != "" else "expected null, got [%s]" % [val])


## Assert a value is not null.
func assert_not_null(val: Variant, msg: String = "") -> void:
	if val == null:
		_fail(msg if msg != "" else "expected non-null value")


## Assert actual > expected.
func assert_gt(actual: Variant, expected: Variant, msg: String = "") -> void:
	if not (actual > expected):
		var detail := "expected [%s] > [%s]" % [actual, expected]
		_fail(detail if msg == "" else "%s — %s" % [msg, detail])


## Assert actual < expected.
func assert_lt(actual: Variant, expected: Variant, msg: String = "") -> void:
	if not (actual < expected):
		var detail := "expected [%s] < [%s]" % [actual, expected]
		_fail(detail if msg == "" else "%s — %s" % [msg, detail])


## Assert actual >= expected.
func assert_gte(actual: Variant, expected: Variant, msg: String = "") -> void:
	if not (actual >= expected):
		var detail := "expected [%s] >= [%s]" % [actual, expected]
		_fail(detail if msg == "" else "%s — %s" % [msg, detail])


## Assert actual <= expected.
func assert_lte(actual: Variant, expected: Variant, msg: String = "") -> void:
	if not (actual <= expected):
		var detail := "expected [%s] <= [%s]" % [actual, expected]
		_fail(detail if msg == "" else "%s — %s" % [msg, detail])


## Assert val is between lo and hi inclusive.
func assert_between(val: Variant, lo: Variant, hi: Variant, msg: String = "") -> void:
	if not (val >= lo and val <= hi):
		var detail := "expected [%s] in [%s, %s]" % [val, lo, hi]
		_fail(detail if msg == "" else "%s — %s" % [msg, detail])


## Assert array/string contains a value.
func assert_has(container: Variant, val: Variant, msg: String = "") -> void:
	var found := false
	if container is Array:
		found = (container as Array).has(val)
	elif container is String:
		found = (container as String).contains(str(val))
	if not found:
		var detail := "[%s] does not contain [%s]" % [container, val]
		_fail(detail if msg == "" else "%s — %s" % [msg, detail])


## Assert array/string does not contain a value.
func assert_does_not_have(container: Variant, val: Variant, msg: String = "") -> void:
	var found := false
	if container is Array:
		found = (container as Array).has(val)
	elif container is String:
		found = (container as String).contains(str(val))
	if found:
		var detail := "[%s] should not contain [%s]" % [container, val]
		_fail(detail if msg == "" else "%s — %s" % [msg, detail])


## Assert two floats are approximately equal within an optional epsilon.
func assert_almost_eq(actual: float, expected: float, eps: float = 0.0001, msg: String = "") -> void:
	if abs(actual - expected) > eps:
		var detail := "expected ~[%s] got [%s] (eps=%s)" % [expected, actual, eps]
		_fail(detail if msg == "" else "%s — %s" % [msg, detail])


## Mark a test as pending / not yet implemented (it is not counted as failure).
func pending(msg: String = "not implemented") -> void:
	pending_count += 1
	print("    [PEND] %s::%s — %s" % [get_suite_name(), _current_test, msg])
