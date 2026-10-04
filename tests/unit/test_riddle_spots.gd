## Unit tests for the Pear Pudding riddle spots (GID-153 / TID-655).
extends "res://tests/framework/test_case.gd"

const RiddleSpots = preload("res://game_logic/world/RiddleSpots.gd")
const Tales       = preload("res://game_logic/quests/Tales.gd")
const SpriteRegistry = preload("res://game_logic/SpriteRegistry.gd")

const DUSK: float = 0.75
const NOON: float = 0.5

func get_suite_name() -> String:
	return "RiddleSpots"

func _ctx(flags: Dictionary, t: float = NOON, weather: String = "clear") -> Dictionary:
	return {"flags": flags, "time_of_day": t, "weather": weather}

func test_table_integrity() -> void:
	var ids: Array[String] = []
	for s: Dictionary in RiddleSpots.SPOTS:
		for key: String in ["id", "prop", "tile", "height", "tale", "needs", "time", "weather", "action",
				"sets_flag", "name", "idle", "solved", "done"]:
			assert_true(s.has(key), "%s missing %s" % [s.get("id", "?"), key])
		assert_false(ids.has(str(s["id"])))
		ids.append(str(s["id"]))
		assert_false(Tales.def(str(s["tale"])).is_empty(), "unknown tale %s" % s["tale"])
		assert_true(Tales.is_personal_flag(str(s["sets_flag"])))
		assert_true(["interact", "dig"].has(str(s["action"])))
		assert_not_null(SpriteRegistry.legend_prop(str(s["prop"])), "missing prop art %s" % s["prop"])

func test_phase() -> void:
	assert_eq(RiddleSpots.phase(0.5), "day")
	assert_eq(RiddleSpots.phase(0.75), "dusk")
	assert_eq(RiddleSpots.phase(0.25), "dawn")
	assert_eq(RiddleSpots.phase(0.95), "night")
	assert_eq(RiddleSpots.phase(0.05), "night")

func test_idle_until_tale_heard() -> void:
	var stones: Dictionary = RiddleSpots.def("leaning_stones")
	assert_eq(RiddleSpots.evaluate(stones, "dig", _ctx({}, DUSK)), RiddleSpots.RESULT_IDLE)

func test_stones_need_dig_at_dusk() -> void:
	var stones: Dictionary = RiddleSpots.def("leaning_stones")
	var flags: Dictionary = {Tales.flag_for("soldier"): true}
	assert_eq(RiddleSpots.evaluate(stones, "dig", _ctx(flags, NOON)), RiddleSpots.RESULT_HINT)
	assert_eq(RiddleSpots.evaluate(stones, "interact", _ctx(flags, DUSK)), RiddleSpots.RESULT_HINT)
	assert_eq(RiddleSpots.evaluate(stones, "dig", _ctx(flags, DUSK)), RiddleSpots.RESULT_SOLVED)
	flags["legend_recipe"] = true
	assert_eq(RiddleSpots.evaluate(stones, "dig", _ctx(flags, DUSK)), RiddleSpots.RESULT_DONE)

func test_pear_tree_any_time_once_rhyme_heard() -> void:
	var tree: Dictionary = RiddleSpots.def("golden_pear_tree")
	assert_eq(RiddleSpots.evaluate(tree, "interact", _ctx({})), RiddleSpots.RESULT_IDLE)
	var flags: Dictionary = {Tales.flag_for("rhyme"): true}
	assert_eq(RiddleSpots.evaluate(tree, "interact", _ctx(flags, 0.95)), RiddleSpots.RESULT_SOLVED)

func test_well_needs_rain_and_ingredients() -> void:
	var well: Dictionary = RiddleSpots.def("queens_well")
	var flags: Dictionary = {Tales.flag_for("farmer"): true}
	assert_eq(RiddleSpots.evaluate(well, "interact", _ctx(flags, NOON, "clear")), RiddleSpots.RESULT_HINT)
	assert_eq(RiddleSpots.evaluate(well, "interact", _ctx(flags, NOON, "rain")), RiddleSpots.RESULT_MISSING)
	for f: String in ["legend_recipe", "legend_golden_pear", "legend_sigh"]:
		flags[f] = true
	assert_eq(RiddleSpots.evaluate(well, "interact", _ctx(flags, NOON, "storm")), RiddleSpots.RESULT_SOLVED)

func test_line_for_falls_back_to_idle() -> void:
	var tree: Dictionary = RiddleSpots.def("golden_pear_tree")
	assert_eq(RiddleSpots.line_for(tree, RiddleSpots.RESULT_HINT), str(tree["idle"]))
