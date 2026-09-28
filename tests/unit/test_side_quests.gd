## SideQuests table + SaveQuests accept/progress/turn-in (GID-136 / TID-533).
extends "res://tests/framework/test_case.gd"

const SideQuests = preload("res://game_logic/quests/SideQuests.gd")
const QuestLog = preload("res://game_logic/quests/QuestLog.gd")
const SaveManagerScript = preload("res://autoloads/SaveManager.gd")

const Q_ID: String = "rats_in_grain"


func _fresh() -> SaveManagerScript:
	var sm: SaveManagerScript = SaveManagerScript.new()
	sm.level = 1
	sm.coins = 0
	return sm


func test_table_is_well_formed() -> void:
	var ids: Dictionary = {}
	for q: Dictionary in SideQuests.all():
		var id: String = str(q.get("id", ""))
		for k: String in ["id", "title", "giver", "giver_name", "summary"]:
			assert_true(str(q.get(k, "")) != "", "%s has %s" % [id, k])
		assert_false(ids.has(id), "quest id %s is unique" % id)
		ids[id] = true
		assert_gt(SideQuests.objectives(q).size(), 0, "%s has objectives" % id)
		for o: Dictionary in SideQuests.objectives(q):
			assert_true(SideQuests.OBJECTIVE_TYPES.has(str(o.get("type", ""))), "%s objective type" % id)
			assert_gt(int(o.get("count", 0)), 0, "%s objective count" % id)
	for q: Dictionary in SideQuests.all():
		var prereqs: Array = q.get("prereqs", [])
		for p: Variant in prereqs:
			assert_true(ids.has(str(p)), "%s prereq %s exists" % [str(q["id"]), str(p)])


func test_objective_matching() -> void:
	var any_kill: Dictionary = {"type": "kill", "target": "", "count": 1}
	var rat_kill: Dictionary = {"type": "kill", "target": "rat", "count": 1}
	assert_true(SideQuests.objective_matches(any_kill, "kill", "wraith"))
	assert_true(SideQuests.objective_matches(rat_kill, "kill", "rat"))
	assert_false(SideQuests.objective_matches(rat_kill, "kill", "wraith"))
	assert_false(SideQuests.objective_matches(any_kill, "talk", "rat"))


func test_can_offer_gates() -> void:
	var q: Dictionary = {"id": "x", "min_level": 3, "req_flag": "f", "prereqs": ["y"]}
	assert_false(SideQuests.can_offer(q, 2, {"f": true}, {}, ["y"]), "under level")
	assert_false(SideQuests.can_offer(q, 3, {}, {}, ["y"]), "flag missing")
	assert_false(SideQuests.can_offer(q, 3, {"f": true}, {}, []), "prereq missing")
	assert_true(SideQuests.can_offer(q, 3, {"f": true}, {}, ["y"]))
	assert_false(SideQuests.can_offer(q, 3, {"f": true}, {"x": {}}, ["y"]), "already active")
	assert_false(SideQuests.can_offer(q, 3, {"f": true}, {}, ["y", "x"]), "already done")


func test_accept_progress_turn_in() -> void:
	var sm := _fresh()
	var q: Dictionary = SideQuests.def(Q_ID)
	assert_false(q.is_empty(), "starter quest exists")
	assert_eq(sm.quests.offers_for(str(q["giver"])).size(), 1, "giver offers it")
	assert_true(sm.quests.accept(Q_ID))
	assert_false(sm.quests.accept(Q_ID), "cannot accept twice")
	assert_eq(sm.quests.offers_for(str(q["giver"])).size(), 0, "no longer offered")
	assert_true(sm.quests.turn_in(Q_ID).is_empty(), "not ready yet")
	var need: int = int(SideQuests.objectives(q)[0]["count"])
	for i: int in range(need + 2):
		sm.quests.progress_event("kill", "undead_basic")
	assert_eq(int(sm.quests.progress_of(Q_ID)[0]), need, "progress clamps at count")
	assert_true(sm.quests.is_ready(Q_ID))
	assert_eq(sm.quests.turn_ins_for(SideQuests.turn_in_npc(q)).size(), 1)
	var rewards: Dictionary = q["rewards"]
	var granted: Dictionary = sm.quests.turn_in(Q_ID)
	assert_false(granted.is_empty())
	assert_eq(sm.coins, int(rewards.get("coins", 0)), "coins paid")
	assert_eq(sm.xp, int(rewards.get("xp", 0)), "xp paid")
	assert_true(sm.quests.is_turned_in(Q_ID))
	assert_false(sm.quests.is_active(Q_ID))
	assert_true(sm.quests.turn_in(Q_ID).is_empty(), "cannot turn in twice")


func test_unrelated_event_does_not_progress() -> void:
	var sm := _fresh()
	sm.quests.accept(Q_ID)
	assert_false(sm.quests.progress_event("talk", "someone"))
	assert_eq(int(sm.quests.progress_of(Q_ID)[0]), 0)


func test_save_round_trip() -> void:
	var sm := _fresh()
	sm.quests.accept(Q_ID)
	sm.quests.progress_event("kill", "")
	var data: Dictionary = JSON.parse_string(JSON.stringify(sm._collect_save_data()))
	var sm2 := _fresh()
	for key: String in SaveManagerScript.PERSISTED_FIELDS:
		sm2._restore_field(data, key, SaveManagerScript.PERSISTED_FIELDS[key])
	assert_true(sm2.quests.is_active(Q_ID))
	assert_eq(int(sm2.quests.progress_of(Q_ID)[0]), 1)
	sm2.quests_completed.append("done_one")
	var data2: Dictionary = JSON.parse_string(JSON.stringify(sm2._collect_save_data()))
	var sm3 := _fresh()
	for key: String in SaveManagerScript.PERSISTED_FIELDS:
		sm3._restore_field(data2, key, SaveManagerScript.PERSISTED_FIELDS[key])
	assert_true(sm3.quests.is_turned_in("done_one"))


func test_quest_log_lists_side_quests() -> void:
	var sm := _fresh()
	sm.quests.accept(Q_ID)
	var qs: Array[Dictionary] = QuestLog.active_quests({}, {}, [], sm.quests.log_entries())
	var side: Dictionary = {}
	for q: Dictionary in qs:
		if str(q["id"]) == QuestLog.SIDE_PREFIX + Q_ID:
			side = q
	assert_false(side.is_empty(), "side quest listed")
	assert_eq(str(side["kind"]), "side")
	assert_true(str(side["progress"]).contains("0 / "), "progress text")
	for i: int in range(5):
		sm.quests.progress_event("kill", "")
	var ready: Dictionary = QuestLog.side_quest(sm.quests.log_entries()[0])
	assert_true(str(ready["label"]).begins_with("Return to"), "points back at the giver once ready")
