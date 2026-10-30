## GID-188 / TID-794: the vertical slice gate. SliceRules is the one table of what the
## slice keeps; the unlock ladder, main menu and battle mode read it, and turning it off
## restores the full game.
extends "res://tests/framework/test_case.gd"

const SliceRules = preload("res://game_logic/SliceRules.gd")
const UnlockLadder = preload("res://game_logic/progression/UnlockLadder.gd")
const SaveManagerScript = preload("res://autoloads/SaveManager.gd")


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
