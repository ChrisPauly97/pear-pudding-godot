## Player-home garden (GID-059): the three plots outside the home, and the
## plant / grow / harvest panel shared with the co-op guildhall garden
## (`plot.session_mode`, TID-393), which routes through CoopSession instead of
## the save. The plot node list stays on WorldScene (`_garden_plot_nodes`)
## because the guildhall furnishing code shares it.
extends Node

const GardenDefs = preload("res://game_logic/GardenDefs.gd")
const _GardenPlotScript = preload("res://scenes/world/entities/GardenPlot.gd")
const _UiUtil = preload("res://scenes/ui/UiUtil.gd")

## Home-interior tiles the plots sit on, in plot_idx order.
const HOME_PLOT_TILES: Array[Vector2i] = [Vector2i(52, 54), Vector2i(55, 54), Vector2i(58, 54)]
## Growth stage at which a plot is ready to harvest (GardenPlot.get_growth_stage).
const MATURE_STAGE: int = 3
const _PANEL_BG := Color(0.05, 0.08, 0.05, 0.96)

var _world: Node = null

func spawn_home_plots() -> void:
	_world._garden_plot_nodes.clear()
	for i: int in range(HOME_PLOT_TILES.size()):
		var wx: float = float(HOME_PLOT_TILES[i].x) * IsoConst.TILE_SIZE
		var wz: float = float(HOME_PLOT_TILES[i].y) * IsoConst.TILE_SIZE
		var plot: Node3D = _GardenPlotScript.new()
		plot.init_from_data({"plot_idx": i})
		plot.position = Vector3(wx, _world.get_terrain_height(wx, wz), wz)
		_world._entity_root.add_child(plot)
		_world._garden_plot_nodes.append(plot)

## Opens the panel for `plot`: a seed picker when empty, a countdown while
## growing, a harvest button once mature.
func show_panel(plot: Node3D) -> void:
	var modal: Dictionary = _world._build_modal(0.7, 0.5, _PANEL_BG, 0.012)
	var layer: CanvasLayer = modal["layer"]
	var vbox: VBoxContainer = modal["vbox"]
	var vh: float = _world.get_viewport().get_visible_rect().size.y
	var font_size: int = int(vh * 0.03)
	var btn_h: float = vh * 0.07
	_UiUtil.make_label("Garden Plot %d" % (int(plot.plot_idx) + 1), int(vh * 0.045),
		Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, vbox)

	var plot_data: Dictionary = plot.get_plot_data()
	if plot_data.is_empty():
		_build_seed_picker(plot, layer, vbox, vh, font_size, btn_h)
	elif plot.get_growth_stage() < MATURE_STAGE:
		_build_growing_info(plot, plot_data, vbox, font_size)
	else:
		_build_harvest(plot, plot_data, layer, vbox, font_size, btn_h)
	_UiUtil.make_button("Close", Vector2(0, btn_h), font_size, layer.queue_free, vbox)

func _build_seed_picker(plot: Node3D, layer: CanvasLayer, vbox: VBoxContainer,
		vh: float, font_size: int, btn_h: float) -> void:
	var sm: Node = SceneManager.save_manager
	var session_mode: bool = bool(plot.session_mode)
	var plot_idx: int = int(plot.plot_idx)
	_UiUtil.make_label("Choose a seed to plant:", font_size, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, vbox)
	var has_any_seed: bool = false
	for seed_id: String in GardenDefs.SEEDS:
		var sdata: Dictionary = GardenDefs.SEEDS[seed_id]
		var sname: String = str(sdata.get("display_name", seed_id))
		var days: int = int(sdata.get("growth_days", 2))
		var seed_count: int = int(sm.seeds.get(seed_id, 0))
		var row := _UiUtil.make_hbox(0, vbox)
		# The co-op guildhall garden is free to plant (no session seed economy
		# is modeled, TID-393) — the owned count only applies solo.
		var text: String = ("%s — %d days" % [sname, days]) if session_mode \
			else "%s — %d days  (owned: %d)" % [sname, days, seed_count]
		var lbl := _UiUtil.make_label(text, font_size, Color.WHITE, HORIZONTAL_ALIGNMENT_LEFT, row)
		lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var plant := func() -> void:
			if session_mode:
				_world.coop_session._submit_session_plant(plot_idx, seed_id)
			elif sm.garden.remove_seeds(seed_id, 1):
				sm.garden.set_plot(plot_idx, seed_id, sm.days_elapsed)
				plot.refresh_visual()
			else:
				return
			SceneManager.show_toast("Planted!", sname + " planted.")
			layer.queue_free()
		var btn := _UiUtil.make_button("Plant", Vector2(vh * 0.14, btn_h), font_size, plant, row)
		btn.disabled = not session_mode and seed_count <= 0
		has_any_seed = has_any_seed or not btn.disabled
	if not has_any_seed:
		_UiUtil.make_label("No seeds — buy some from a merchant.", font_size, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER,
				vbox)

func _build_growing_info(plot: Node3D, plot_data: Dictionary, vbox: VBoxContainer, font_size: int) -> void:
	var sdata: Dictionary = GardenDefs.SEEDS.get(str(plot_data.get("seed_id", "")), {})
	var sname: String = str(sdata.get("display_name", plot_data.get("seed_id", "")))
	var ready_day: int = int(plot_data.get("planted_day", 0)) + int(sdata.get("growth_days", 2))
	var today: int = _world.coop_session._coop_current_days_elapsed() if bool(plot.session_mode) \
		else SceneManager.save_manager.days_elapsed
	var info := _UiUtil.make_label("%s growing — ready in %d day(s)" % [sname, maxi(0, ready_day - today)],
		font_size, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, vbox)
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

func _build_harvest(plot: Node3D, plot_data: Dictionary, layer: CanvasLayer,
		vbox: VBoxContainer, font_size: int, btn_h: float) -> void:
	var sdata: Dictionary = GardenDefs.SEEDS.get(str(plot_data.get("seed_id", "")), {})
	var sname: String = str(sdata.get("display_name", plot_data.get("seed_id", "")))
	var plant_id: String = str(sdata.get("plant_id", ""))
	var yield_count: int = int(sdata.get("yield", 1))
	var plot_idx: int = int(plot.plot_idx)
	var session_mode: bool = bool(plot.session_mode)
	_UiUtil.make_label("%s is ready to harvest!" % sname, font_size, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, vbox)
	var harvest := func() -> void:
		if session_mode:
			_world.coop_session._submit_session_harvest(plot_idx)
		else:
			var sm: Node = SceneManager.save_manager
			sm.garden.add_plants(plant_id, yield_count)
			sm.garden.clear_plot(plot_idx)
			GameBus.plant_harvested.emit(plot_idx, yield_count)
		SceneManager.show_toast("Harvested!", "%d× %s" % [yield_count, sname])
		layer.queue_free()
	_UiUtil.make_button("Harvest (%d× %s)" % [yield_count, sname], Vector2(0, btn_h), font_size, harvest, vbox)
