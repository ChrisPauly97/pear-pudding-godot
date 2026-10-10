## Crafting stations (GID-182 / TID-762): places the cooking fire, alchemy table and
## workbench from `StationSites` — in the stitched towns of the overworld and in the
## player-home interior — and opens `ProfessionPanel` for one. The station nodes live
## in WorldScene._crafting_station_nodes, where `_find_nearby_crafting_station` reads
## them. Created by `WorldScene._ensure_world_modules()` as `crafting_stations`.
extends Node

const _WorldScene = preload("res://scenes/world/WorldScene.gd")
const _StationSites = preload("res://game_logic/professions/StationSites.gd")
const _RealmLayout = preload("res://game_logic/world/RealmLayout.gd")
const _CraftingStation = preload("res://scenes/world/entities/CraftingStation.gd")
const _ProfessionPanel = preload("res://scenes/ui/ProfessionPanel.gd")

var _world: _WorldScene = null
var _panel: Control = null


## Overworld ("main"): every stitched town's stations, at their world tiles.
func spawn_overworld() -> void:
	_clear()
	if _world.map_name != "main":
		return
	for town: String in _RealmLayout.town_names():
		for site: Dictionary in _StationSites.sites_in(town):
			_spawn(site, _RealmLayout.to_world_tile(town, site["tile"] as Vector2i))


## Player-home interior: the home stations, at their home tiles.
func spawn_home() -> void:
	_clear()
	for site: Dictionary in _StationSites.sites_in(""):
		_spawn(site, site["tile"] as Vector2i)


## Opens the profession panel for a station node. One panel at a time.
func show_panel(station: Node3D) -> void:
	var node: _CraftingStation = station as _CraftingStation
	if node == null or _panel != null:
		return
	var panel: _ProfessionPanel = _ProfessionPanel.new()
	panel.setup(node.profession, SceneManager.save_manager)
	_world.add_child(panel)
	panel.closed.connect(_on_panel_closed)
	_panel = panel


func _on_panel_closed() -> void:
	if is_instance_valid(_panel):
		_panel.queue_free()
	_panel = null


func _spawn(site: Dictionary, tile: Vector2i) -> void:
	var x: float = IsoConst.tile_center(tile.x)
	var z: float = IsoConst.tile_center(tile.y)
	var node: _CraftingStation = _CraftingStation.new()
	node.init_from_data(site)
	node.position = Vector3(x, _world.get_terrain_height(x, z), z)
	_world._entity_root.add_child(node)
	_world._crafting_station_nodes.append(node)


func _clear() -> void:
	for raw: Variant in _world._crafting_station_nodes:
		var n: Node3D = _world._valid_node3d(raw)
		if n != null:
			n.queue_free()
	_world._crafting_station_nodes.clear()
