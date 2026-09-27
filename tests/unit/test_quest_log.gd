## StoryQuests step table + QuestLog aggregation (GID-139).
extends "res://tests/framework/test_case.gd"

const StoryQuests = preload("res://game_logic/quests/StoryQuests.gd")
const QuestLog = preload("res://game_logic/quests/QuestLog.gd")
const RealmLayout = preload("res://game_logic/world/RealmLayout.gd")


func _all_done_flags(upto: int) -> Dictionary:
	var d: Dictionary = {}
	for i: int in range(upto):
		d[str(StoryQuests.STEPS[i]["done_flag"])] = true
	return d


func test_every_step_is_complete() -> void:
	var ids: Dictionary = {}
	for s: Dictionary in StoryQuests.STEPS:
		for k: String in ["id", "chapter", "label", "giver", "summary", "done_flag", "map"]:
			assert_true(s.has(k) and str(s[k]) != "", "%s has %s" % [str(s.get("id", "?")), k])
		assert_true(StoryQuests.CHAPTERS.has(int(s["chapter"])), "%s chapter has a title" % str(s["id"]))
		assert_false(ids.has(s["id"]), "step id %s is unique" % str(s["id"]))
		ids[s["id"]] = true


func test_steps_advance_in_order() -> void:
	for i: int in range(StoryQuests.STEPS.size()):
		var step: Dictionary = StoryQuests.current_step(_all_done_flags(i))
		assert_eq(str(step.get("id", "")), str(StoryQuests.STEPS[i]["id"]), "step %d is current" % i)
		assert_eq(StoryQuests.completed_steps(_all_done_flags(i)).size(), i, "%d steps behind" % i)
	assert_true(StoryQuests.current_step(_all_done_flags(StoryQuests.STEPS.size())).is_empty())


func test_most_advanced_flag_wins() -> void:
	# A later flag without the earlier ones still lands after it.
	var step: Dictionary = StoryQuests.current_step({"chapter1_reached_blancogov": true})
	assert_eq(str(step["label"]), "Enter the Temple")


func test_story_quest_never_blank_after_last_step() -> void:
	var q: Dictionary = QuestLog.story_quest({"chapter2_complete": true})
	assert_eq(str(q["id"]), QuestLog.STORY_ID)
	assert_true(str(q["label"]) != "", "post-story quest has a label")
	assert_true(QuestLog.has_target(q), "post-story quest points at a bounty board")


func test_story_quest_carries_chapter_and_summary() -> void:
	var q: Dictionary = QuestLog.story_quest({})
	assert_eq(str(q["title"]), "Chapter 1: Into the Wild World")
	assert_eq(str(q["label"]), "Speak to Maiteln")
	assert_true(str(q["summary"]) != "")


func test_bounty_boards_found_in_towns() -> void:
	var boards: Array[Dictionary] = QuestLog.bounty_board_targets()
	assert_true(boards.size() >= 3, "a board in each board town")
	var madrian: Vector2i = RealmLayout.to_world_tile("madrian", Vector2i(46, 30))
	var found: bool = false
	for b: Dictionary in boards:
		if Vector2i(int(b["tx"]), int(b["tz"])) == madrian:
			found = true
	assert_true(found, "Madrian's board is at its stitched tile")


func test_treasure_and_bounties_listed() -> void:
	var bounties: Array = [
		{"id": "b1", "type": "open_chests", "target": "chest", "count": 3, "progress": 1},
		{"id": "b2", "type": "open_chests", "target": "chest", "count": 2, "progress": 2, "completed": true},
		{"id": "b3", "type": "open_chests", "target": "chest", "count": 2, "progress": 2, "claimed": true},
	]
	var qs: Array[Dictionary] = QuestLog.active_quests({}, {"site_x": 30, "site_z": -40}, bounties)
	assert_eq(qs.size(), 4, "story + treasure + two unclaimed bounties")
	assert_eq(str(qs[1]["id"]), QuestLog.TREASURE_ID)
	var tpos: Variant = QuestLog.world_pos(qs[1], "main", Vector3.ZERO)
	assert_almost_eq((tpos as Vector3).x, 30.5 * IsoConst.TILE_SIZE, 0.001, "dig site tile centre")
	assert_eq(str(qs[2]["progress"]), "1 / 3")
	assert_false(QuestLog.has_target(qs[2]), "an unfinished bounty has no place")
	assert_true(QuestLog.has_target(qs[3]), "a finished bounty points at a board")


func test_nearest_target_wins() -> void:
	var q: Dictionary = {"targets": [{"map": "main", "tx": 0, "tz": 0}, {"map": "main", "tx": 100, "tz": 0}]}
	var near_far: Vector3 = QuestLog.world_pos(q, "main", Vector3(99.0 * IsoConst.TILE_SIZE, 0, 0)) as Vector3
	assert_almost_eq(near_far.x, 100.5 * IsoConst.TILE_SIZE, 0.001, "picks the nearer target")


func test_tracked_falls_back_to_story() -> void:
	var qs: Array[Dictionary] = QuestLog.active_quests({}, {}, [])
	assert_eq(str(QuestLog.tracked(qs, "bounty:gone")["id"]), QuestLog.STORY_ID)
	assert_eq(str(QuestLog.tracked(qs, "")["id"]), QuestLog.STORY_ID)


func test_targets_off_map_hide() -> void:
	var qs: Array[Dictionary] = QuestLog.active_quests({}, {"site_x": 5, "site_z": 5}, [])
	assert_null(QuestLog.world_pos(qs[1], "blancogov_temple", Vector3.ZERO), "no overworld marker indoors")
