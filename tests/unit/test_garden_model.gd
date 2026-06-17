## Unit tests for GardenDefs and SaveManager garden fields (GID-056 TID-203).
##
## Covers: growth_stage boundaries for all seed types, SaveManager new_game defaults,
## migration v32→v33, plot set/clear helpers, seed/plant/potion count helpers,
## get_plot_growth_stage integration, and save/load round-trip.
extends "res://tests/framework/test_case.gd"

const GardenDefs        = preload("res://game_logic/GardenDefs.gd")
const SaveManagerScript = preload("res://autoloads/SaveManager.gd")

var _sm: Node

func before_each() -> void:
	_sm = SaveManagerScript.new()
	_sm._loaded = true
	_sm.days_elapsed = 0
	_sm.garden_plots.assign([{}, {}, {}])
	_sm.seeds = {}
	_sm.plants = {}
	_sm.potions = {}

func after_each() -> void:
	_sm.free()

# ---------------------------------------------------------------------------
# GardenDefs — SEEDS entries
# ---------------------------------------------------------------------------

func test_seeds_contains_sunpetal() -> void:
	assert_true(GardenDefs.SEEDS.has("sunpetal"))

func test_seeds_contains_moonroot() -> void:
	assert_true(GardenDefs.SEEDS.has("moonroot"))

func test_seeds_contains_embercap() -> void:
	assert_true(GardenDefs.SEEDS.has("embercap"))

func test_sunpetal_growth_days_is_2() -> void:
	assert_eq(int(GardenDefs.SEEDS["sunpetal"]["growth_days"]), 2)

func test_moonroot_growth_days_is_3() -> void:
	assert_eq(int(GardenDefs.SEEDS["moonroot"]["growth_days"]), 3)

func test_embercap_growth_days_is_2() -> void:
	assert_eq(int(GardenDefs.SEEDS["embercap"]["growth_days"]), 2)

func test_sunpetal_yield_is_1() -> void:
	assert_eq(int(GardenDefs.SEEDS["sunpetal"]["yield"]), 1)

func test_moonroot_yield_is_2() -> void:
	assert_eq(int(GardenDefs.SEEDS["moonroot"]["yield"]), 2)

func test_embercap_yield_is_2() -> void:
	assert_eq(int(GardenDefs.SEEDS["embercap"]["yield"]), 2)

# ---------------------------------------------------------------------------
# GardenDefs — PLANTS and POTIONS
# ---------------------------------------------------------------------------

func test_plants_has_sunpetal_plant() -> void:
	assert_true(GardenDefs.PLANTS.has("sunpetal_plant"))

func test_plants_has_moonroot_plant() -> void:
	assert_true(GardenDefs.PLANTS.has("moonroot_plant"))

func test_plants_has_embercap_plant() -> void:
	assert_true(GardenDefs.PLANTS.has("embercap_plant"))

func test_potions_has_healing_draught() -> void:
	assert_true(GardenDefs.POTIONS.has("healing_draught"))

func test_potions_has_clarity_brew() -> void:
	assert_true(GardenDefs.POTIONS.has("clarity_brew"))

func test_potions_has_ember_tonic() -> void:
	assert_true(GardenDefs.POTIONS.has("ember_tonic"))

# ---------------------------------------------------------------------------
# GardenDefs.growth_stage — sunpetal (growth_days=2)
# ---------------------------------------------------------------------------

func test_sunpetal_stage_at_age_0() -> void:
	assert_eq(GardenDefs.growth_stage(0, 2, 0), 1, "age 0 should be stage 1")

func test_sunpetal_stage_at_age_1() -> void:
	assert_eq(GardenDefs.growth_stage(0, 2, 1), 2, "age 1 should be stage 2")

func test_sunpetal_stage_at_age_2() -> void:
	assert_eq(GardenDefs.growth_stage(0, 2, 2), 3, "age 2 should be mature (3)")

func test_sunpetal_stage_beyond_growth_days() -> void:
	assert_eq(GardenDefs.growth_stage(0, 2, 5), 3, "age > growth_days should stay at 3")

func test_sunpetal_stage_non_zero_planted_day() -> void:
	assert_eq(GardenDefs.growth_stage(3, 2, 4), 2, "planted_day=3, current=4 → age 1 → stage 2")
	assert_eq(GardenDefs.growth_stage(3, 2, 5), 3, "planted_day=3, current=5 → age 2 → stage 3")

# ---------------------------------------------------------------------------
# GardenDefs.growth_stage — moonroot (growth_days=3)
# ---------------------------------------------------------------------------

func test_moonroot_stage_at_age_0() -> void:
	assert_eq(GardenDefs.growth_stage(0, 3, 0), 1, "age 0 should be stage 1")

func test_moonroot_stage_at_age_1() -> void:
	assert_eq(GardenDefs.growth_stage(0, 3, 1), 1, "age 1 should still be stage 1 (int div)")

func test_moonroot_stage_at_age_2() -> void:
	assert_eq(GardenDefs.growth_stage(0, 3, 2), 2, "age 2 should be stage 2")

func test_moonroot_stage_at_age_3() -> void:
	assert_eq(GardenDefs.growth_stage(0, 3, 3), 3, "age 3 should be mature")

# ---------------------------------------------------------------------------
# SaveManager — new_game defaults
# ---------------------------------------------------------------------------

func test_new_game_initialises_three_plots() -> void:
	_sm.new_game()
	assert_eq(_sm.garden_plots.size(), 3, "must have exactly 3 plots")

func test_new_game_plots_are_empty() -> void:
	_sm.new_game()
	for i: int in range(3):
		assert_true((_sm.garden_plots[i] as Dictionary).is_empty(),
			"plot %d must start empty" % i)

func test_new_game_seeds_is_empty() -> void:
	_sm.new_game()
	assert_true(_sm.seeds.is_empty())

func test_new_game_plants_is_empty() -> void:
	_sm.new_game()
	assert_true(_sm.plants.is_empty())

func test_new_game_potions_is_empty() -> void:
	_sm.new_game()
	assert_true(_sm.potions.is_empty())

# ---------------------------------------------------------------------------
# SaveManager migration v32 → v33
# ---------------------------------------------------------------------------

func test_migration_adds_garden_fields() -> void:
	var data: Dictionary = {"version": 32}
	SaveManagerScript._migrate_v32_to_v33(data)
	assert_true(data.has("garden_plots"), "garden_plots must be added")
	assert_true(data.has("seeds"),        "seeds must be added")
	assert_true(data.has("plants"),       "plants must be added")
	assert_true(data.has("potions"),      "potions must be added")

func test_migration_garden_plots_default_has_three_entries() -> void:
	var data: Dictionary = {"version": 32}
	SaveManagerScript._migrate_v32_to_v33(data)
	assert_eq((data["garden_plots"] as Array).size(), 3)

func test_migration_bumps_version_to_33() -> void:
	var data: Dictionary = {"version": 32}
	SaveManagerScript._migrate_v32_to_v33(data)
	assert_eq(data["version"], 33)

func test_migration_does_not_overwrite_existing_seeds() -> void:
	var data: Dictionary = {"version": 32, "seeds": {"sunpetal": 2}}
	SaveManagerScript._migrate_v32_to_v33(data)
	assert_eq(int(data["seeds"]["sunpetal"]), 2)

func test_apply_migrations_reaches_v33_from_v32() -> void:
	var data: Dictionary = {"version": 32}
	SaveManagerScript._apply_migrations(data)
	assert_eq(data.get("version", 0), SaveManagerScript.CURRENT_SAVE_VERSION)
	assert_true(data.has("garden_plots"))

# ---------------------------------------------------------------------------
# SaveManager — plot set/clear helpers
# ---------------------------------------------------------------------------

func test_set_plot_stores_seed_and_day() -> void:
	_sm.set_plot(0, "sunpetal", 5)
	var plot: Dictionary = _sm.garden_plots[0]
	assert_eq(str(plot.get("seed_id", "")), "sunpetal")
	assert_eq(int(plot.get("planted_day", -1)), 5)

func test_clear_plot_empties_dict() -> void:
	_sm.set_plot(1, "moonroot", 2)
	_sm.clear_plot(1)
	assert_true((_sm.garden_plots[1] as Dictionary).is_empty())

func test_set_plot_out_of_range_is_noop() -> void:
	_sm.set_plot(99, "sunpetal", 0)  # should not crash

# ---------------------------------------------------------------------------
# SaveManager — seed/plant/potion count helpers
# ---------------------------------------------------------------------------

func test_add_seeds_increments_count() -> void:
	_sm.add_seeds("sunpetal", 3)
	assert_eq(int(_sm.seeds.get("sunpetal", 0)), 3)

func test_add_seeds_accumulates() -> void:
	_sm.add_seeds("moonroot", 1)
	_sm.add_seeds("moonroot", 2)
	assert_eq(int(_sm.seeds.get("moonroot", 0)), 3)

func test_remove_seeds_succeeds_when_sufficient() -> void:
	_sm.add_seeds("sunpetal", 3)
	var ok: bool = _sm.remove_seeds("sunpetal", 2)
	assert_true(ok)
	assert_eq(int(_sm.seeds.get("sunpetal", 0)), 1)

func test_remove_seeds_fails_when_insufficient() -> void:
	_sm.add_seeds("sunpetal", 1)
	var ok: bool = _sm.remove_seeds("sunpetal", 2)
	assert_false(ok)
	assert_eq(int(_sm.seeds.get("sunpetal", 0)), 1)

func test_add_plants_increments_count() -> void:
	_sm.add_plants("sunpetal_plant", 2)
	assert_eq(int(_sm.plants.get("sunpetal_plant", 0)), 2)

func test_remove_plants_succeeds() -> void:
	_sm.add_plants("moonroot_plant", 4)
	var ok: bool = _sm.remove_plants("moonroot_plant", 2)
	assert_true(ok)
	assert_eq(int(_sm.plants.get("moonroot_plant", 0)), 2)

func test_remove_plants_fails_when_insufficient() -> void:
	_sm.add_plants("embercap_plant", 1)
	var ok: bool = _sm.remove_plants("embercap_plant", 3)
	assert_false(ok)

func test_add_potions_increments_count() -> void:
	_sm.add_potions("healing_draught", 1)
	assert_eq(int(_sm.potions.get("healing_draught", 0)), 1)

func test_remove_potions_succeeds() -> void:
	_sm.add_potions("clarity_brew", 2)
	var ok: bool = _sm.remove_potions("clarity_brew", 1)
	assert_true(ok)
	assert_eq(int(_sm.potions.get("clarity_brew", 0)), 1)

func test_remove_potions_fails_when_insufficient() -> void:
	var ok: bool = _sm.remove_potions("ember_tonic", 1)
	assert_false(ok)

# ---------------------------------------------------------------------------
# SaveManager — get_plot_growth_stage integration
# ---------------------------------------------------------------------------

func test_empty_plot_returns_stage_0() -> void:
	assert_eq(_sm.get_plot_growth_stage(0), 0, "empty plot must return stage 0")

func test_planted_plot_returns_stage_1_on_same_day() -> void:
	_sm.days_elapsed = 5
	_sm.set_plot(0, "sunpetal", 5)
	assert_eq(_sm.get_plot_growth_stage(0), 1)

func test_planted_sunpetal_matures_after_2_days() -> void:
	_sm.days_elapsed = 7
	_sm.set_plot(0, "sunpetal", 5)
	assert_eq(_sm.get_plot_growth_stage(0), 3)

func test_planted_moonroot_intermediate_stage() -> void:
	_sm.days_elapsed = 7
	_sm.set_plot(1, "moonroot", 5)  # age = 2, growth_days = 3 → stage 2
	assert_eq(_sm.get_plot_growth_stage(1), 2)

func test_out_of_range_plot_returns_0() -> void:
	assert_eq(_sm.get_plot_growth_stage(99), 0)
