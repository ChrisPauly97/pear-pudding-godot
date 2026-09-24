## Home garden: plot contents and growth, and the seed / plant / potion inventories
## (GID-056).
##
## Owned by SaveManager (`SaveManager.garden`), created in its `_init`. The state
## stays on SaveManager because PERSISTED_FIELDS walks its properties, so this
## reads and writes it through `_save.<field>`.
extends RefCounted

var _save: Node


func _init(save_manager: Node) -> void:
	_save = save_manager


func set_plot(plot_idx: int, seed_id: String, planted_day: int) -> void:
	if plot_idx < 0 or plot_idx >= _save.garden_plots.size():
		return
	_save.garden_plots[plot_idx] = {"seed_id": seed_id, "planted_day": planted_day}
	_save._dirty = true

func clear_plot(plot_idx: int) -> void:
	if plot_idx < 0 or plot_idx >= _save.garden_plots.size():
		return
	_save.garden_plots[plot_idx] = {}
	_save._dirty = true

func add_seeds(seed_id: String, count: int) -> void:
	_save.seeds[seed_id] = int(_save.seeds.get(seed_id, 0)) + count
	_save._dirty = true
	GameBus.inventory_changed.emit()

func remove_seeds(seed_id: String, count: int) -> bool:
	var current: int = int(_save.seeds.get(seed_id, 0))
	if current < count:
		return false
	_save.seeds[seed_id] = current - count
	_save._dirty = true
	return true

func add_plants(plant_id: String, count: int) -> void:
	_save.plants[plant_id] = int(_save.plants.get(plant_id, 0)) + count
	_save._dirty = true

func remove_plants(plant_id: String, count: int) -> bool:
	var current: int = int(_save.plants.get(plant_id, 0))
	if current < count:
		return false
	_save.plants[plant_id] = current - count
	_save._dirty = true
	return true

func add_potions(potion_id: String, count: int) -> void:
	_save.potions[potion_id] = int(_save.potions.get(potion_id, 0)) + count
	_save._dirty = true

func remove_potions(potion_id: String, count: int) -> bool:
	var current: int = int(_save.potions.get(potion_id, 0))
	if current < count:
		return false
	_save.potions[potion_id] = current - count
	_save._dirty = true
	return true

func get_plot_growth_stage(plot_idx: int) -> int:
	if plot_idx < 0 or plot_idx >= _save.garden_plots.size():
		return 0
	var plot: Dictionary = _save.garden_plots[plot_idx]
	if plot.is_empty() or not plot.has("seed_id"):
		return 0
	const GardenDefs = preload("res://game_logic/GardenDefs.gd")
	var seed_id: String = str(plot.get("seed_id", ""))
	var seed_def: Dictionary = GardenDefs.SEEDS.get(seed_id, {})
	if seed_def.is_empty():
		return 0
	var growth_days: int = int(seed_def.get("growth_days", 1))
	var planted_day: int = int(plot.get("planted_day", 0))
	return GardenDefs.growth_stage(planted_day, growth_days, _save.days_elapsed)
