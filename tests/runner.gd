## Headless test runner for Pear Pudding TCG.
##
## Usage:
##   godot --headless --path /path/to/project -s tests/runner.gd
##
## The --path flag ensures autoloads (IsoConst, GameBus, SceneManager) are
## initialised before any test runs, mirroring the production environment.
##
## Exit codes:
##   0  — all tests passed
##   1  — one or more tests failed
extends SceneTree

const SUITES: Array = [
	preload("res://tests/unit/test_card_instance.gd"),
	preload("res://tests/unit/test_hero_state.gd"),
	preload("res://tests/unit/test_zone_state.gd"),
	preload("res://tests/unit/test_player_state.gd"),
	preload("res://tests/unit/test_game_state.gd"),
	preload("res://tests/unit/test_world_entity.gd"),
	preload("res://tests/unit/test_iso_const.gd"),
	preload("res://tests/unit/test_basic_ai.gd"),
	preload("res://tests/unit/test_card_registry.gd"),
	preload("res://tests/unit/test_chunk_data.gd"),
	preload("res://tests/unit/test_infinite_world_gen.gd"),
	preload("res://tests/unit/test_terrain_math.gd"),
	preload("res://tests/unit/test_named_map_npcs.gd"),
	preload("res://tests/unit/test_status_effects.gd"),
	preload("res://tests/unit/test_spire_run.gd"),
	preload("res://tests/unit/test_spire_draft.gd"),
	preload("res://tests/unit/test_puzzle_registry.gd"),
	preload("res://tests/unit/test_puzzle_mode.gd"),
	preload("res://tests/unit/test_world_event_manager.gd"),
	preload("res://tests/unit/test_weather_manager.gd"),
	preload("res://tests/unit/test_weather_visuals.gd"),
	preload("res://tests/unit/test_weather_battle.gd"),
	preload("res://tests/unit/test_treasure_system.gd"),
	preload("res://tests/unit/test_bestiary_data.gd"),
	preload("res://tests/unit/test_bestiary_completion.gd"),
	preload("res://tests/unit/test_player_home.gd"),
	preload("res://tests/unit/test_pathfinder.gd"),
	preload("res://tests/unit/test_mount_framework.gd"),
	preload("res://tests/unit/test_mount_purchase_hud.gd"),
	preload("res://tests/unit/test_mount_dismount_visuals.gd"),
	preload("res://tests/unit/test_card_packs.gd"),
	preload("res://tests/unit/test_companion_framework.gd"),
	preload("res://tests/unit/test_compass_bearing.gd"),
	preload("res://tests/unit/test_waypoint_transforms.gd"),
	preload("res://tests/unit/test_objective_tracker.gd"),
	preload("res://tests/unit/test_bounty_gen.gd"),
	preload("res://tests/unit/test_bounty_board.gd"),
	preload("res://tests/unit/test_bounty_progress.gd"),
	preload("res://tests/unit/test_weapon_upgrades.gd"),
	preload("res://tests/unit/test_weapon_salvage.gd"),
	preload("res://tests/unit/test_siege_trigger.gd"),
	preload("res://tests/unit/test_siege_state.gd"),
	preload("res://tests/unit/test_town_discount.gd"),
	preload("res://tests/unit/test_siege_timeout.gd"),
	preload("res://tests/unit/test_siege_defeat.gd"),
	preload("res://tests/unit/test_rival.gd"),
	preload("res://tests/unit/test_rival_encounters.gd"),
	preload("res://tests/unit/test_rival_finale.gd"),
	preload("res://tests/unit/test_night_hunts.gd"),
	preload("res://tests/unit/test_garden_model.gd"),
	preload("res://tests/unit/test_garden_plot.gd"),
	preload("res://tests/unit/test_potion_recipes.gd"),
	preload("res://tests/unit/test_battle_potions.gd"),
	preload("res://tests/unit/test_battle_fatigue.gd"),
	preload("res://tests/unit/test_battlefield_rules.gd"),
	preload("res://tests/unit/test_dungeon_secrets.gd"),
	preload("res://tests/unit/test_mimic_chests.gd"),
	preload("res://tests/unit/test_cracked_wall_interact.gd"),
	preload("res://tests/unit/test_loadout_model.gd"),
	preload("res://tests/unit/test_veterancy_util.gd"),
]


func _initialize() -> void:
	var total_pass := 0
	var total_fail := 0
	var total_pending := 0

	print("\n===== Pear Pudding TCG — Unit Tests =====\n")

	for suite_script in SUITES:
		if suite_script == null or not suite_script.can_instantiate():
			print("  [SKIP] suite failed to load (compile error or missing dependency)")
			total_fail += 1
			continue
		var suite = suite_script.new()
		var suite_name: String = suite.get_suite_name()
		print("  Suite: %s" % suite_name)
		suite.run_all()
		total_pass += suite.pass_count
		total_fail += suite.fail_count
		total_pending += suite.pending_count
		print("")

	print("=========================================")
	print("  Passed:  %d" % total_pass)
	print("  Failed:  %d" % total_fail)
	if total_pending > 0:
		print("  Pending: %d" % total_pending)
	print("=========================================\n")

	if total_fail > 0:
		print("RESULT: FAIL\n")
		quit(1)
	else:
		print("RESULT: PASS\n")
		quit(0)
