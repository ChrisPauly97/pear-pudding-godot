## GID-188 / TID-794: the vertical slice gate. SliceRules is the one table of what the
## slice keeps; the unlock ladder, main menu and battle mode read it, and turning it off
## restores the full game.
extends "res://tests/framework/test_case.gd"

const SliceRules = preload("res://game_logic/SliceRules.gd")
const UnlockLadder = preload("res://game_logic/progression/UnlockLadder.gd")
const SaveManagerScript = preload("res://autoloads/SaveManager.gd")
const SideQuests = preload("res://game_logic/quests/SideQuests.gd")
const StarterZone = preload("res://game_logic/world/StarterZone.gd")
const XpCurve = preload("res://game_logic/progression/XpCurve.gd")


func after_each() -> void:
	SliceRules.override = 0  # the runner's default: suites test the full game


func test_project_ships_with_the_slice_on() -> void:
	assert_true(bool(ProjectSettings.get_setting(SliceRules.SETTING, false)), "project.godot turns the slice on")


func test_slice_ladder_rows_are_real_and_reachable() -> void:
	for id: String in SliceRules.LADDER:
		assert_true(UnlockLadder.has(id), "%s is a ladder row" % id)
		assert_lte(UnlockLadder.level_req(id), SliceRules.LEVEL_CAP, "%s reachable by the level cap" % id)


func test_slice_keeps_dig_the_deck_unlocks_world_moment() -> void:
	assert_has(SliceRules.LADDER, UnlockLadder.FEAT_DIG)


func test_ladder_lists_skip_out_of_slice_rows() -> void:
	SliceRules.override = 1
	var pending: Array[String] = UnlockLadder.pending(60, [])
	for id: String in pending:
		assert_has(SliceRules.LADDER, id, "%s pending in the slice" % id)
	assert_eq(pending.size(), SliceRules.LADDER.size(), "every slice row pending at 60")
	assert_does_not_have(UnlockLadder.for_trainer("stable"), UnlockLadder.FEAT_MOUNT)
	assert_true(UnlockLadder.available_at(UnlockLadder.level_req(UnlockLadder.FEAT_PHASE)).is_empty(),
			"Phase never becomes available")
	assert_false(UnlockLadder.can_learn(UnlockLadder.FEAT_PHASE, 60, 99999, []), "Phase can't be learned")
	assert_true(UnlockLadder.can_learn(UnlockLadder.FEAT_DIG, 10, 99999, []), "Dig can be learned")


func test_turning_the_slice_off_restores_the_full_ladder() -> void:
	SliceRules.override = 0
	assert_eq(UnlockLadder.pending(60, []).size(), UnlockLadder.all_ids().size())
	assert_true(UnlockLadder.can_learn(UnlockLadder.FEAT_PHASE, 60, 99999, []))


func test_menu_hides_out_of_slice_entries() -> void:
	SliceRules.override = 1
	assert_false(SliceRules.allows_menu("coop"))
	assert_false(SliceRules.allows_menu("map_editor"))
	assert_true(SliceRules.allows_menu("new_game"))
	SliceRules.override = 0
	assert_true(SliceRules.allows_menu("coop"))


func test_slice_forces_real_time_battles() -> void:
	var sm: SaveManagerScript = SaveManagerScript.new()
	sm.learned_abilities.assign(UnlockLadder.all_ids())
	sm.settings["battle_mode"] = "turn"
	SliceRules.override = 0
	assert_eq(sm.battle_mode(), "turn", "full game honours the setting")
	SliceRules.override = 1
	assert_eq(sm.battle_mode(), SliceRules.BATTLE_MODE, "slice ignores the setting")
	sm.free()


func test_full_game_toggle_round_trips_per_device() -> void:
	var path: String = "user://test_full_game.cfg"
	assert_false(SliceRules.full_game_enabled(path), "off when no file")
	assert_eq(SliceRules.set_full_game(true, path), OK)
	assert_true(SliceRules.full_game_enabled(path), "on after enabling")
	assert_eq(SliceRules.set_full_game(false, path), OK)
	assert_false(SliceRules.full_game_enabled(path), "off after disabling")
	assert_false(FileAccess.file_exists(path), "disabling removes the file")


func test_full_game_turns_the_slice_off() -> void:
	SliceRules.override = -1
	var was: int = SliceRules._full_game
	SliceRules._full_game = 1
	assert_false(SliceRules.active(), "Full Game on: the slice is off")
	SliceRules._full_game = 0
	assert_true(SliceRules.active(), "Full Game off: the shipped slice")
	SliceRules._full_game = was


func test_xp_stops_at_the_level_cap() -> void:
	var sm: SaveManagerScript = SaveManagerScript.new()
	SliceRules.override = 1
	sm.add_xp(XpCurve.xp_to_reach(SliceRules.LEVEL_CAP + 5))
	assert_eq(sm.level, SliceRules.LEVEL_CAP, "level stops at the cap")
	assert_eq(sm.xp, XpCurve.xp_to_reach(SliceRules.LEVEL_CAP), "XP stops at the cap")
	SliceRules.override = 0
	sm.add_xp(XpCurve.xp_to_reach(SliceRules.LEVEL_CAP + 5))
	assert_gt(sm.level, SliceRules.LEVEL_CAP, "full game keeps levelling")
	sm.free()


func test_out_of_slice_quests_are_not_offered() -> void:
	SliceRules.override = 1
	for id: String in ["sealed_crypt", "board_by_the_well", "after_dark", "into_the_rift"]:
		assert_false(SliceRules.allows_quest(SideQuests.def(id)), "%s is outside the slice" % id)
	for id: String in ["rats_in_grain", "old_bones"]:
		assert_true(SliceRules.allows_quest(SideQuests.def(id)), "%s is in the slice" % id)
	var completed: Array = ["old_bones"]
	assert_true(SideQuests.offers_for("gravedigger_madrian", 60, {}, {}, completed).is_empty(),
			"the Gravedigger has nothing past Dig in the slice")
	SliceRules.override = 0
	assert_false(SideQuests.offers_for("gravedigger_madrian", 60, {}, {}, completed).is_empty(),
			"full game offers The Sealed Crypt")


func test_every_slice_quest_is_finishable() -> void:
	SliceRules.override = 1
	for q: Dictionary in SideQuests.all():
		if not SliceRules.allows_quest(q):
			continue
		for o: Dictionary in SideQuests.objectives(q):
			if str(o.get("type", "")) == "learn":
				assert_has(SliceRules.LADDER, str(o.get("target", "")), "%s learn target" % str(q["id"]))


func test_barrow_king_is_the_slice_boss() -> void:
	assert_eq(str(StarterZone.BARROW_KING["enemy_type"]), SliceRules.BOSS_ENEMY_TYPE)
	assert_lte(int(StarterZone.BARROW_KING["level"]), SliceRules.LEVEL_CAP)
	SliceRules.override = 1
	assert_true(StarterZone.barrow_king_awake([SliceRules.BOSS_QUEST], []), "wakes after the Dig quest")
	assert_false(StarterZone.barrow_king_awake([SliceRules.BOSS_QUEST], [str(StarterZone.BARROW_KING["id"])]))
	SliceRules.override = 0
	assert_false(StarterZone.barrow_king_awake([SliceRules.BOSS_QUEST], []), "full game: needs the crypt")
	assert_true(SideQuests.def(SliceRules.BOSS_QUEST).size() > 0, "boss quest exists")
