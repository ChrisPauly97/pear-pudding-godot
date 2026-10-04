## Unit tests for the Pear Pudding legend tales (GID-153 / TID-654).
extends "res://tests/framework/test_case.gd"

const Tales    = preload("res://game_logic/quests/Tales.gd")
const QuestLog = preload("res://game_logic/quests/QuestLog.gd")

func get_suite_name() -> String:
	return "Tales"

func test_table_integrity() -> void:
	var ids: Array[String] = []
	var npcs: Array[String] = []
	for t: Dictionary in Tales.TALES:
		for key: String in ["id", "npc", "npc_name", "town", "title", "lines", "riddle", "after", "solve_flag"]:
			assert_true(t.has(key), "%s missing %s" % [t.get("id", "?"), key])
		assert_false(ids.has(str(t["id"])), "duplicate id")
		assert_false(npcs.has(str(t["npc"])), "one tale per teller")
		var after: String = str(t["after"])
		assert_true(after == "" or ids.has(after), "after must name an earlier tale")
		assert_true(Tales.is_personal_flag(Tales.flag_for(str(t["id"]))))
		assert_true(Tales.is_personal_flag(str(t["solve_flag"])))
		ids.append(str(t["id"]))
		npcs.append(str(t["npc"]))
	assert_eq(ids.size(), 4)

func test_tales_unlock_in_order() -> void:
	var flags: Dictionary = {}
	assert_eq(str(Tales.tale_for_npc("old_garrick", flags).get("id", "")), "soldier")
	assert_true(Tales.tale_for_npc("little_pip", flags).is_empty(), "rhyme waits for the soldier's tale")
	flags[Tales.flag_for("soldier")] = true
	assert_true(Tales.tale_for_npc("old_garrick", flags).is_empty(), "told once")
	assert_eq(str(Tales.tale_for_npc("little_pip", flags).get("id", "")), "rhyme")

func test_heard_and_solved() -> void:
	var flags: Dictionary = {Tales.flag_for("soldier"): true, Tales.flag_for("rhyme"): true}
	var heard: Array[Dictionary] = Tales.heard(flags)
	assert_eq(heard.size(), 2)
	assert_eq(str(heard[0]["id"]), "soldier")
	assert_false(Tales.is_solved(heard[0], flags))
	flags["legend_recipe"] = true
	assert_true(Tales.is_solved(heard[0], flags))

func test_unknown_npc_has_no_tale() -> void:
	assert_true(Tales.tale_for_npc("madrian:npc_2", {}).is_empty())
	assert_true(Tales.def("nope").is_empty())

func test_never_touches_quest_systems() -> void:
	# The legend must stay invisible: no quest-log, tracker or marker code may read Tales.
	for path: String in ["res://game_logic/quests/QuestLog.gd", "res://game_logic/ObjectiveTracker.gd",
			"res://scenes/world/modules/QuestTracker.gd", "res://game_logic/quests/SideQuests.gd"]:
		var src: String = FileAccess.get_file_as_string(path)
		assert_false(src.contains("Tales.gd") or src.contains("legend_"), "%s references the legend" % path)
