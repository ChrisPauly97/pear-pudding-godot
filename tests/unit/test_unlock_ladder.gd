## GID-141 / TID-587: the unlock ladder — one thing per level, learned at a trainer.
extends "res://tests/framework/test_case.gd"

const UnlockLadder = preload("res://game_logic/progression/UnlockLadder.gd")
const SkillBar = preload("res://game_logic/battle/SkillBar.gd")
const SaveMigrations = preload("res://game_logic/save/SaveMigrations.gd")
const SaveManagerScript = preload("res://autoloads/SaveManager.gd")
const RealmLayout = preload("res://game_logic/world/RealmLayout.gd")
const QuestLog = preload("res://game_logic/quests/QuestLog.gd")


func test_rows_well_formed() -> void:
	var ids: Dictionary = {}
	for row: Dictionary in UnlockLadder.all():
		var id: String = str(row.get("id", ""))
		assert_false(ids.has(id), "%s unique" % id)
		ids[id] = true
		assert_true(UnlockLadder.TRAINERS.has(str(row.get("trainer", ""))), "%s has a known trainer" % id)
		assert_gt(str(row.get("how_to", "")).length(), 40, "%s explains itself" % id)
		assert_true(str(row.get("title", "")) != "", "%s title" % id)
		assert_gt(UnlockLadder.level_req(id), 1, "%s is not free at level 1" % id)
		assert_gt(UnlockLadder.cost(id), 0, "%s costs gold" % id)
		if str(row["kind"]) == "skill":
			assert_true(SkillBar.ABILITIES.has(id), "%s is a SkillBar ability" % id)


func test_levels_ascend_one_new_thing_early() -> void:
	var prev: int = 0
	for row: Dictionary in UnlockLadder.all():
		var lvl: int = UnlockLadder.level_req(str(row["id"]))
		assert_gte(lvl, prev, "%s in level order" % str(row["id"]))
		prev = lvl
	for lvl: int in range(2, 11):
		assert_eq(UnlockLadder.available_at(lvl).size(), 1, "exactly one unlock at level %d" % lvl)


func test_design_anchors() -> void:
	assert_eq(UnlockLadder.level_req(UnlockLadder.FEAT_DIG), 10)
	assert_eq(UnlockLadder.level_req(UnlockLadder.FEAT_PHASE), 12)
	assert_eq(UnlockLadder.level_req(UnlockLadder.FEAT_SPIRE), 15)
	assert_eq(UnlockLadder.level_req(UnlockLadder.FEAT_MOUNT), 40)
	assert_eq(SkillBar.ALWAYS_KNOWN, ["strike"] as Array[String])


func test_every_skill_bar_learnable_is_on_the_ladder() -> void:
	for id: String in SkillBar.learnable_ids():
		assert_true(UnlockLadder.has(id), "%s taught by a trainer" % id)


func test_can_learn_gates() -> void:
	var id: String = UnlockLadder.FEAT_MINIONS
	var c: int = UnlockLadder.cost(id)
	assert_false(UnlockLadder.can_learn(id, 3, 9999, []), "under level")
	assert_false(UnlockLadder.can_learn(id, 4, c - 1, []), "too poor")
	assert_true(UnlockLadder.can_learn(id, 4, c, []))
	assert_false(UnlockLadder.can_learn(id, 4, c, [id]), "already learned")
	assert_true(UnlockLadder.is_learned("not_a_ladder_id", []), "non-ladder ids are always on")


func test_pending_lists_reached_but_unlearned() -> void:
	var p: Array[String] = UnlockLadder.pending(3, ["mend"])
	assert_eq(p, ["kick"] as Array[String])


func test_new_game_knows_only_strike() -> void:
	var sm: SaveManagerScript = SaveManagerScript.new()
	sm.learned_abilities.assign(["mend"])
	sm.new_game(false)
	assert_true(sm.learned_abilities.is_empty())
	assert_eq(SkillBar.new(sm.skill_bar, sm.learned_abilities).ids, ["strike"] as Array[String])
	sm.new_game(true)
	for id: String in UnlockLadder.all_ids():
		assert_true(sm.learned_abilities.has(id), "head start learns %s" % id)


func test_learn_slots_skill_and_charges() -> void:
	var sm: SaveManagerScript = SaveManagerScript.new()
	sm.new_game(false)
	sm.coins = 100
	sm.skill_bar.assign(["strike"])
	assert_true(sm.learn_ability("mend", UnlockLadder.cost("mend")))
	assert_eq(sm.coins, 100 - UnlockLadder.cost("mend"))
	assert_true(sm.skill_bar.has("mend"), "learned skill goes on the bar")
	assert_false(sm.learn_ability("mend", 0), "cannot learn twice")


func test_level_up_announces_training() -> void:
	var sm: SaveManagerScript = SaveManagerScript.new()
	sm.new_game(false)
	var got: Array = []
	var cb: Callable = func(ids: Array[String]) -> void: got.append_array(ids)
	GameBus.training_available.connect(cb)
	sm.add_xp(SaveManagerScript.xp_for_level(3))
	GameBus.training_available.disconnect(cb)
	assert_true(got.has("mend") and got.has("kick"), "levels 2 and 3 announce Mend and Kick")


func test_migration_keeps_veterans_whole() -> void:
	var d: Dictionary = {"version": 43, "xp": 0, "learned_abilities": ["guard"], "owned_mounts": []}
	SaveMigrations.apply(d)
	var learned: Array = d["learned_abilities"]
	for id: String in ["mend", "kick", "guard", UnlockLadder.FEAT_MINIONS, UnlockLadder.FEAT_DIG,
			UnlockLadder.FEAT_SPIRE]:
		assert_true(learned.has(id), "migrated save keeps %s" % id)
	assert_false(learned.has(UnlockLadder.FEAT_MOUNT), "no mount owned → riding stays gated")
	assert_false(learned.has("sweep"), "unbought trainer skills stay unlearned")
	var d2: Dictionary = {"version": 43, "owned_mounts": ["horse"]}
	SaveMigrations.apply(d2)
	assert_true((d2["learned_abilities"] as Array).has(UnlockLadder.FEAT_MOUNT))


func test_locked_message_names_trainer_and_level() -> void:
	var msg: String = UnlockLadder.locked_message(UnlockLadder.FEAT_DIG)
	assert_true(msg.contains("Gravedigger"), msg)
	assert_true(msg.contains("10"), msg)


func test_has_learned_gates_fresh_save() -> void:
	var sm: SaveManagerScript = SaveManagerScript.new()
	sm.new_game(false)
	for id: String in [UnlockLadder.FEAT_DIG, UnlockLadder.FEAT_PHASE, UnlockLadder.FEAT_MOUNT,
			UnlockLadder.FEAT_SKILLS, UnlockLadder.FEAT_BOUNTIES, UnlockLadder.FEAT_NIGHT_HUNTS,
			UnlockLadder.FEAT_SPIRE, UnlockLadder.FEAT_PACKS, UnlockLadder.FEAT_COMPANION]:
		assert_false(sm.has_learned(id), "fresh save has not learned %s" % id)
	assert_true(sm.has_learned("not_on_the_ladder"))
	sm.set_setting("battle_mode", "turn")
	assert_eq(sm.battle_mode(), "realtime", "no hand yet → real time")


func test_every_trainer_has_an_npc_in_town() -> void:
	var ids: Dictionary = {}
	for npc: Dictionary in RealmLayout.entities("npcs"):
		ids[str(npc.get("id", ""))] = true
	for trainer: Variant in UnlockLadder.TRAINERS:
		if str(trainer) == "maiteln":
			continue  # his follower node teaches
		var npc_id: String = str(UnlockLadder.TRAINER_NPCS.get(trainer, ""))
		assert_true(ids.has(npc_id), "%s trainer NPC %s is placed" % [str(trainer), npc_id])
		assert_eq(UnlockLadder.trainer_at(npc_id), str(trainer))


func test_training_quest_points_at_trainers() -> void:
	var q: Dictionary = QuestLog.training_quest(["mend", UnlockLadder.FEAT_BOUNTIES])
	assert_eq(str(q["kind"]), "training")
	assert_true(str(q["label"]).contains("Mend"))
	assert_eq((q["targets"] as Array).size(), 2, "combat trainer + bounty master")
	var mark: Dictionary = QuestLog.npc_mark({}, null, false, false, "", true)
	assert_eq(str(mark["kind"]), "training")
