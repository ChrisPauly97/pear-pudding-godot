## SideQuests table + SaveQuests accept/progress/turn-in (GID-136 / TID-533).
extends "res://tests/framework/test_case.gd"

const SideQuests = preload("res://game_logic/quests/SideQuests.gd")
const QuestLog = preload("res://game_logic/quests/QuestLog.gd")
const SaveManagerScript = preload("res://autoloads/SaveManager.gd")
const RealmLayout = preload("res://game_logic/world/RealmLayout.gd")
const UnlockLadder = preload("res://game_logic/progression/UnlockLadder.gd")
const StarterZone = preload("res://game_logic/world/StarterZone.gd")
const ZoneLevels = preload("res://game_logic/world/ZoneLevels.gd")
const EnemyRegistry = preload("res://autoloads/EnemyRegistry.gd")

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
		var keys: Array[String] = ["id", "title", "summary"]
		if not bool(q.get("auto", false)):  # bonus objectives (GID-177) have no giver
			keys.append_array(["giver", "giver_name"])
		for k: String in keys:
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
	sm.quests.progress_event("kill", "undead_basic")
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
		sm.quests.progress_event("kill", "undead_basic")
	var ready: Dictionary = QuestLog.side_quest(sm.quests.log_entries()[0])
	assert_true(str(ready["label"]).begins_with("Return to"), "points back at the giver once ready")


func test_every_giver_stands_in_a_stitched_town() -> void:
	var ids: Dictionary = {}
	for npc: Dictionary in RealmLayout.entities("npcs"):
		ids[str(npc.get("id", ""))] = true
	for q: Dictionary in SideQuests.all():
		if bool(q.get("auto", false)):
			continue  # camp bonus objectives (GID-177) have no giver
		assert_true(ids.has(str(q["giver"])), "%s giver %s is placed" % [str(q["id"]), str(q["giver"])])
		assert_true(ids.has(SideQuests.turn_in_npc(q)), "%s turn-in NPC is placed" % str(q["id"]))


func test_npc_state_and_marks() -> void:
	var sm := _fresh()
	var giver: String = str(SideQuests.def(Q_ID)["giver"])
	assert_eq(sm.quests.npc_state(giver), "offer")
	assert_eq(str(QuestLog.npc_mark({}, null, false, false, "offer")["text"]), "!")
	sm.quests.accept(Q_ID)
	assert_eq(sm.quests.npc_state(giver), "")
	for i: int in range(5):
		sm.quests.progress_event("kill", "undead_basic")
	assert_eq(sm.quests.npc_state(giver), "turn_in")
	var story_tile := Vector2i(0, 0)
	var mark: Dictionary = QuestLog.npc_mark({"x": 0.0, "z": 0.0}, story_tile, false, false, "turn_in")
	assert_eq(str(mark["text"]), "?", "hand-in outranks the story mark")
	var story: Dictionary = QuestLog.npc_mark({"x": 0.0, "z": 0.0}, story_tile, false, false, "offer")
	assert_eq(str(story["kind"]), "story", "story mark outranks a new offer")
	assert_eq(str(QuestLog.npc_mark({}, null, false, false, "upcoming")["kind"]), "side_upcoming")


func test_talk_objective() -> void:
	var q: Dictionary = {"objectives": [{"type": "talk", "target": "bob", "count": 1}]}
	assert_true(SideQuests.objective_matches(SideQuests.objectives(q)[0], "talk", "bob"))
	assert_false(SideQuests.objective_matches(SideQuests.objectives(q)[0], "talk", "alice"))


## GID-141 / TID-592: walk the starter chain through the save API — only the
## quest's own kills (camp level, real kill XP + coins), learning each training
## with the gold earned — and check the level and gold line up at every step.
func test_starter_chain_paces_levels_and_gold() -> void:
	var sm := _fresh()
	sm.new_game(false)
	var chain: Array[String] = ["rats_in_grain", "bruised_and_battered", "hedge_witch_chant",
		"raise_the_fallen", "first_spark"]
	var grind: int = 0
	for qid: String in chain:
		var q: Dictionary = SideQuests.def(qid)
		grind += _grind_to(sm, int(q.get("min_level", 1)))
		assert_gte(sm.level, int(q.get("min_level", 1)), "level reached for %s" % qid)
		assert_true(sm.quests.accept(qid), "accepted %s" % qid)
		for o: Dictionary in SideQuests.objectives(q):
			var t: String = str(o["type"])
			var target: String = str(o["target"])
			for _i: int in range(int(o["count"])):
				if t == "learn":
					assert_true(UnlockLadder.can_learn(target, sm.level, sm.coins, sm.learned_abilities),
							"%s: can afford + learn %s (level %d, %d gold)" % [qid, target, sm.level, sm.coins])
					sm.learn_ability(target, UnlockLadder.cost(target))
				elif t == "kill":
					var camp: Dictionary = StarterZone.camp_for_level(sm.level)
					for c: Dictionary in StarterZone.CAMPS:
						if int(c["tile"].x) == int(o.get("tx", 0)) and int(c["tile"].y) == int(o.get("tz", 0)):
							camp = c
					assert_eq(str(camp["enemy_type"]), target, "%s kills at a camp of %s" % [qid, target])
					sm.add_xp(ZoneLevels.scaled_xp(EnemyRegistry.get_xp_reward(target), StarterZone.camp_level(camp), sm.level))
					sm.add_coins(EnemyRegistry.get_coin_reward(target))
					sm.quests.progress_event("kill", target)
				else:
					sm.quests.progress_event(t, target)
		assert_false(sm.quests.turn_in(qid).is_empty(), "turned in %s" % qid)
	# GID-176 / TID-719: camp levels follow the zone, so a little camp grinding
	# between quests is expected (GID-177 slows levelling further on purpose).
	grind += _grind_to(sm, UnlockLadder.level_req(UnlockLadder.FEAT_COMPANION))
	assert_lte(grind, 40, "grinding between starter quests stays modest (%d extra kills)" % grind)
	assert_gte(sm.level, 6, "the townsfolk chain (+ grinding) reaches level 6")
	assert_true(sm.get_story_flag("town_quests_done"), "Maiteln is called")
	assert_true(UnlockLadder.can_learn(UnlockLadder.FEAT_COMPANION, sm.level, sm.coins, sm.learned_abilities),
			"…with gold to learn to fight beside him (%d gold)" % sm.coins)


## Kills at the camp nearest the player's level until `level`; returns the kill count.
func _grind_to(sm: Object, level: int) -> int:
	var n: int = 0
	while int(sm.get("level")) < level and n < 200:
		var camp: Dictionary = StarterZone.camp_for_level(int(sm.get("level")))
		var etype: String = str(camp["enemy_type"])
		sm.call("add_xp", ZoneLevels.scaled_xp(EnemyRegistry.get_xp_reward(etype), StarterZone.camp_level(camp),
				int(sm.get("level"))))
		sm.call("add_coins", EnemyRegistry.get_coin_reward(etype))
		n += 1
	return n


func test_starter_quest_targets_match_camps_and_learns() -> void:
	for q: Dictionary in SideQuests.all():
		for o: Dictionary in SideQuests.objectives(q):
			if str(o["type"]) == "learn":
				assert_true(UnlockLadder.has(str(o["target"])), "%s teaches a ladder entry" % str(q["id"]))
				assert_gte(int(q.get("min_level", 1)), UnlockLadder.level_req(str(o["target"])),
						"%s is offered no earlier than its training" % str(q["id"]))


## GID-162: the one-pass npc_states() must agree with the per-NPC rule
## (turn_ins_for, then offers_for, then SideQuests.upcoming_for) at every level
## and as quests get accepted, finished and handed in.
func test_npc_states_matches_per_npc_rule() -> void:
	var sm := _fresh()
	var npcs: Dictionary = {}
	for q: Dictionary in SideQuests.all():
		npcs[str(q["giver"])] = true
		npcs[SideQuests.turn_in_npc(q)] = true
	var checked: int = 0
	for level: int in range(1, 12):
		sm.level = level
		for q: Dictionary in SideQuests.all():
			var id: String = str(q["id"])
			for step: int in 3:
				var states: Dictionary = sm.quests.npc_states()
				for npc: Variant in npcs:
					var n: String = str(npc)
					var want: String = ""
					if not sm.quests.turn_ins_for(n).is_empty():
						want = "turn_in"
					elif not sm.quests.offers_for(n).is_empty():
						want = "offer"
					elif not SideQuests.upcoming_for(n, sm.level, sm.story_flags, sm.quests_active,
							sm.quests_completed).is_empty():
						want = "upcoming"
					assert_eq(str(states.get(n, "")), want, "lvl %d %s step %d npc %s" % [level, id, step, n])
					checked += 1
				if step == 0:
					sm.quests.accept(id)
				elif step == 1 and sm.quests.is_active(id):
					for o: Dictionary in SideQuests.objectives(q):
						for _i: int in int(o.get("count", 1)):
							sm.quests.progress_event(str(o.get("type", "")), str(o.get("target", "")))
	assert_gt(checked, 100, "covered the quest table")


## Kill objectives get a shaded quest area on the maps; hand-ins are a single spot.
func test_kill_objective_has_map_zone() -> void:
	var sm := _fresh()
	sm.quests.accept(Q_ID)
	var q: Dictionary = QuestLog.side_quest({"quest": SideQuests.def(Q_ID), "progress": [0], "ready": false})
	var zones: Array[Dictionary] = QuestLog.zones(q)
	assert_eq(zones.size(), 1, "one area: the camp")
	assert_eq((zones[0]["pts"] as Array).size(), 4, "camp centre + its 3 enemy slots")
	var done: Dictionary = QuestLog.side_quest({"quest": SideQuests.def(Q_ID), "progress": [5], "ready": true})
	assert_true(QuestLog.zones(done).is_empty(), "return-to-giver: no area")
