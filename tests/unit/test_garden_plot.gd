## Unit tests for GardenPlot entity and supporting helpers (GID-056 TID-204).
##
## GardenPlot.get_growth_stage() and get_plot_data() delegate to
## SceneManager.save_manager, which is an autoload not safely mockable here.
## We therefore test the pure-logic helpers used by the plot interaction:
##   - SaveManager plot/seed/plant helpers
##   - GardenDefs growth_stage boundaries (mirrors test_garden_model, ensuring
##     TID-204 integration path correctness)
##   - init_from_data field assignment (no SceneManager dependency)
extends "res://tests/framework/test_case.gd"

const GardenDefs        = preload("res://game_logic/GardenDefs.gd")
const GardenPlotScript  = preload("res://scenes/world/entities/GardenPlot.gd")
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
# GardenPlot.init_from_data — no SceneManager dependency
# ---------------------------------------------------------------------------

func test_init_from_data_sets_plot_idx() -> void:
	var plot: Node = GardenPlotScript.new()
	plot.init_from_data({"plot_idx": 2})
	assert_eq(plot.plot_idx, 2)
	plot.free()

func test_init_from_data_defaults_plot_idx_to_zero() -> void:
	var plot: Node = GardenPlotScript.new()
	plot.init_from_data({})
	assert_eq(plot.plot_idx, 0)
	plot.free()

func test_init_from_data_plot_idx_1() -> void:
	var plot: Node = GardenPlotScript.new()
	plot.init_from_data({"plot_idx": 1})
	assert_eq(plot.plot_idx, 1)
	plot.free()

# ---------------------------------------------------------------------------
# SaveManager helpers: set_plot / clear_plot
# ---------------------------------------------------------------------------

func test_set_plot_stores_seed_id_and_day() -> void:
	_sm.set_plot(0, "sunpetal", 3)
	var p: Dictionary = _sm.garden_plots[0]
	assert_eq(str(p.get("seed_id", "")), "sunpetal")
	assert_eq(int(p.get("planted_day", -1)), 3)

func test_clear_plot_empties_dict() -> void:
	_sm.set_plot(1, "moonroot", 1)
	_sm.clear_plot(1)
	assert_true(_sm.garden_plots[1].is_empty())

func test_set_plot_out_of_range_is_safe() -> void:
	_sm.set_plot(99, "sunpetal", 0)
	assert_eq(_sm.garden_plots.size(), 3)

# ---------------------------------------------------------------------------
# SaveManager helpers: seeds
# ---------------------------------------------------------------------------

func test_add_seeds_increments_count() -> void:
	_sm.add_seeds("sunpetal", 2)
	assert_eq(int(_sm.seeds.get("sunpetal", 0)), 2)

func test_remove_seeds_decrements_count() -> void:
	_sm.seeds["moonroot"] = 3
	var ok: bool = _sm.remove_seeds("moonroot", 1)
	assert_true(ok)
	assert_eq(int(_sm.seeds.get("moonroot", 0)), 2)

func test_remove_seeds_fails_when_insufficient() -> void:
	_sm.seeds["embercap"] = 0
	var ok: bool = _sm.remove_seeds("embercap", 1)
	assert_false(ok)
	assert_eq(int(_sm.seeds.get("embercap", 0)), 0)

# ---------------------------------------------------------------------------
# SaveManager helpers: plants
# ---------------------------------------------------------------------------

func test_harvest_sunpetal_adds_one_plant() -> void:
	_sm.set_plot(0, "sunpetal", 0)
	var yield_count: int = int(GardenDefs.SEEDS["sunpetal"].get("yield", 1))
	var plant_id: String = str(GardenDefs.SEEDS["sunpetal"].get("plant_id", ""))
	_sm.add_plants(plant_id, yield_count)
	_sm.clear_plot(0)
	assert_eq(int(_sm.plants.get("sunpetal_plant", 0)), 1)
	assert_true(_sm.garden_plots[0].is_empty())

func test_harvest_moonroot_adds_two_plants() -> void:
	_sm.set_plot(1, "moonroot", 0)
	var yield_count: int = int(GardenDefs.SEEDS["moonroot"].get("yield", 1))
	var plant_id: String = str(GardenDefs.SEEDS["moonroot"].get("plant_id", ""))
	_sm.add_plants(plant_id, yield_count)
	_sm.clear_plot(1)
	assert_eq(int(_sm.plants.get("moonroot_plant", 0)), 2)
	assert_true(_sm.garden_plots[1].is_empty())

func test_harvest_embercap_adds_two_plants() -> void:
	_sm.set_plot(2, "embercap", 0)
	var yield_count: int = int(GardenDefs.SEEDS["embercap"].get("yield", 1))
	var plant_id: String = str(GardenDefs.SEEDS["embercap"].get("plant_id", ""))
	_sm.add_plants(plant_id, yield_count)
	_sm.clear_plot(2)
	assert_eq(int(_sm.plants.get("embercap_plant", 0)), 2)
	assert_true(_sm.garden_plots[2].is_empty())

# ---------------------------------------------------------------------------
# SaveManager.get_plot_growth_stage — the core logic used by GardenPlot
# ---------------------------------------------------------------------------

func test_empty_plot_returns_zero() -> void:
	assert_eq(_sm.get_plot_growth_stage(0), 0)

func test_sunpetal_stage_1_at_day_0() -> void:
	_sm.set_plot(0, "sunpetal", 0)
	_sm.days_elapsed = 0
	assert_eq(_sm.get_plot_growth_stage(0), 1)

func test_sunpetal_stage_2_at_day_1() -> void:
	_sm.set_plot(0, "sunpetal", 0)
	_sm.days_elapsed = 1
	assert_eq(_sm.get_plot_growth_stage(0), 2)

func test_sunpetal_mature_at_day_2() -> void:
	_sm.set_plot(0, "sunpetal", 0)
	_sm.days_elapsed = 2
	assert_eq(_sm.get_plot_growth_stage(0), 3)

func test_moonroot_stage_1_at_day_0() -> void:
	_sm.set_plot(0, "moonroot", 0)
	_sm.days_elapsed = 0
	assert_eq(_sm.get_plot_growth_stage(0), 1)

func test_moonroot_stage_2_at_day_2() -> void:
	_sm.set_plot(0, "moonroot", 0)
	_sm.days_elapsed = 2
	assert_eq(_sm.get_plot_growth_stage(0), 2)

func test_moonroot_mature_at_day_3() -> void:
	_sm.set_plot(0, "moonroot", 0)
	_sm.days_elapsed = 3
	assert_eq(_sm.get_plot_growth_stage(0), 3)

func test_planted_day_offset_is_respected() -> void:
	_sm.set_plot(0, "sunpetal", 5)
	_sm.days_elapsed = 6  # age = 1 => stage 2 for sunpetal (growth_days=2)
	assert_eq(_sm.get_plot_growth_stage(0), 2)
	_sm.days_elapsed = 7  # age = 2 => stage 3
	assert_eq(_sm.get_plot_growth_stage(0), 3)
