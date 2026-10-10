## GID-141 / TID-587: the unlock ladder — one thing per level, learned at a trainer.
extends "res://tests/framework/test_case.gd"

const UnlockLadder = preload("res://game_logic/progression/UnlockLadder.gd")
const TechniqueDefs = preload("res://game_logic/battle/TechniqueDefs.gd")
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
			assert_ne(TechniqueDefs.card_for(id), "", "%s is a technique card" % id)


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
	assert_eq(TechniqueDefs.known_cards([]), ["tech_strike"] as Array[String])


func test_every_learnable_technique_is_on_the_ladder() -> void:
	for card_id: String in TechniqueDefs.ORDER:  # skill-tree techniques come from the tree (GID-179)
		if card_id != "tech_strike":
			assert_true(UnlockLadder.has(TechniqueDefs.ability_for(card_id)), "%s taught by a trainer" % card_id)


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
	assert_eq(TechniqueDefs.known_cards(sm.learned_abilities), ["tech_strike"] as Array[String])
	sm.new_game(true)
	for id: String in UnlockLadder.all_ids():
		assert_true(sm.learned_abilities.has(id), "head start learns %s" % id)


func test_learn_slots_skill_and_charges() -> void:
	var sm: SaveManagerScript = SaveManagerScript.new()
	sm.new_game(false)
	sm.coins = 100
	assert_true(sm.learn_ability("mend", UnlockLadder.cost("mend")))
	assert_eq(sm.coins, 100 - UnlockLadder.cost("mend"))
	assert_true(sm.get_deck_template_ids().has("tech_mend"), "learned technique card joins the deck (GID-175)")
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


## GID-185 / TID-774: every feature row grants real, non-technique cards.
func test_every_feature_row_grants_cards() -> void:
	var CardRegistry: GDScript = preload("res://autoloads/CardRegistry.gd")
	for row: Dictionary in UnlockLadder.all():
		var id: String = str(row["id"])
		if str(row["kind"]) != "feature":
			assert_true(UnlockLadder.cards_for(id, "light").is_empty(), "skill row %s grants via TechniqueDefs" % id)
			continue
		var cards: Array[String] = UnlockLadder.cards_for(id, "dark")
		assert_false(cards.is_empty(), "%s grants a card" % id)
		for card_id: String in cards:
			assert_false((CardRegistry.call("get_template", card_id) as Dictionary).is_empty(), "%s exists" % card_id)
			assert_false(TechniqueDefs.is_technique(card_id), "%s is not a technique" % card_id)
	assert_true(UnlockLadder.cards_for(UnlockLadder.FEAT_SKILLS, "").is_empty(), "skills card waits for a type")


func _count(sm: SaveManagerScript, card_id: String) -> int:
	var n: int = 0
	for inst: Dictionary in sm.owned_cards + sm.mailbox_cards:
		if str(inst.get("template_id", "")) == card_id:
			n += 1
	return n


func test_learning_a_feature_grants_its_cards_once() -> void:
	var sm: SaveManagerScript = SaveManagerScript.new()
	sm.new_game(false)
	sm.coins = 1000
	var before: int = _count(sm, "wolf")
	assert_true(sm.learn_ability(UnlockLadder.FEAT_MINIONS, 40))
	assert_eq(_count(sm, "wolf"), before + 1, "wolf granted")
	sm._grant_ladder_cards()
	assert_eq(_count(sm, "wolf"), before + 1, "not granted twice")


func test_old_save_gets_learned_row_cards_once_and_skills_card_follows_type() -> void:
	var sm: SaveManagerScript = SaveManagerScript.new()
	sm.new_game(false)
	sm.learned_abilities.assign([UnlockLadder.FEAT_DIG, UnlockLadder.FEAT_SKILLS])
	sm.ladder_cards_granted = []
	var skel: int = _count(sm, "skeleton")
	var dealt: Array[String] = sm._grant_ladder_cards()
	assert_eq(_count(sm, "skeleton"), skel + 2, "Dig's two skeletons on load")
	assert_false(dealt.has("wither"), "no magic type yet")
	assert_false(sm.ladder_cards_granted.has(UnlockLadder.FEAT_SKILLS), "skills row stays pending")
	sm.set_magic_type("dark")
	assert_eq(_count(sm, "wither"), 1, "dark starter card once a type is chosen")
	sm._grant_ladder_cards()
	assert_eq(_count(sm, "skeleton"), skel + 2, "still once")


## GID-185 / TID-775: the technique-slot row lets a deck hold a fourth technique.
func test_technique_slot_row_allows_a_fourth() -> void:
	var BattleSetup: GDScript = preload("res://game_logic/battle/BattleSetup.gd")
	var four: Array = ["tech_strike", "tech_kick", "tech_mend", "tech_guard"]
	assert_ne(TechniqueDefs.deck_violation(four, UnlockLadder.technique_slots([])), "")
	var learned: Array = ["mend", "kick", "guard", UnlockLadder.FEAT_TECH_SLOT]
	assert_eq(UnlockLadder.technique_slots(learned), 4)
	assert_eq(TechniqueDefs.deck_violation(four, UnlockLadder.technique_slots(learned)), "")
	var deck: Array[String] = BattleSetup.call("level_deck", learned)
	var n: int = 0
	for id: String in deck:
		if TechniqueDefs.is_technique(id):
			n += 1
	assert_eq(n, 4, "the default deck fills the fourth slot")
