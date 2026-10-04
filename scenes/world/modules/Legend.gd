## The Pear Pudding legend in the world (GID-153 / TID-655): places the riddle
## spots (RiddleSpots) on the overworld as unmarked scenery and resolves a look
## or a Dig at one. Tales themselves are told by NpcInteractions (Tales.gd).
## Created by `WorldScene._ensure_world_modules()` as `legend`; ticked from
## WorldScene's overworld branch.
extends Node

const _WorldScene = preload("res://scenes/world/WorldScene.gd")
const _RiddleSpots = preload("res://game_logic/world/RiddleSpots.gd")
const _RiddleSpot = preload("res://scenes/world/entities/RiddleSpot.gd")
const _SpriteRegistry = preload("res://game_logic/SpriteRegistry.gd")

## Live spot nodes (WorldScene._find_nearby_riddle_spot scans these).
var spot_nodes: Array[Node3D] = []
var _world: _WorldScene = null
var _root: Node3D = null


func tick(_delta: float) -> void:
	if _root == null and _world.map_name == "main" and not NetworkManager.is_dedicated_server():
		_build_spots()


func _build_spots() -> void:
	_root = Node3D.new()
	_root.name = "LegendSpots"
	_world._entity_root.add_child(_root)
	spot_nodes.clear()
	for spot: Dictionary in _RiddleSpots.SPOTS:
		var t: Vector2i = spot["tile"]
		var x: float = IsoConst.tile_center(t.x)
		var z: float = IsoConst.tile_center(t.y)
		var node := _RiddleSpot.new()
		node.name = "RiddleSpot_" + str(spot["id"])
		node.setup(str(spot["id"]), _texture_for(spot), float(spot["height"]), examine)
		node.position = Vector3(x, _world.get_terrain_height(x, z), z)
		_root.add_child(node)
		spot_nodes.append(node)


## The prop as it should look now (the pear tree loses its pear once taken).
func _texture_for(spot: Dictionary) -> Texture2D:
	var key: String = str(spot["prop"])
	if key == "legend_pear_tree" and SceneManager.save_manager.get_story_flag(str(spot["sets_flag"])):
		key = "legend_pear_tree_bare"
	return _SpriteRegistry.legend_prop(key)


func _ctx() -> Dictionary:
	var t: float = _world._dnc.get_time_of_day() if _world._dnc != null else 0.4
	return {"flags": SceneManager.save_manager.story_flags, "time_of_day": t,
		"weather": WeatherManager.current_weather}


## A look ("interact") or a Dig ("dig") at spot `spot_id`.
func examine(spot_id: String, action: String) -> void:
	var spot: Dictionary = _RiddleSpots.def(spot_id)
	if spot.is_empty():
		return
	var result: String = _RiddleSpots.evaluate(spot, action, _ctx())
	_world._show_dialogue(_RiddleSpots.line_for(spot, result))
	if result == _RiddleSpots.RESULT_SOLVED:
		_solve(spot)


func _solve(spot: Dictionary) -> void:
	SceneManager.save_manager.set_story_flag(str(spot["sets_flag"]))
	GameBus.legend_riddle_solved.emit(str(spot["id"]))
	for n: Node3D in spot_nodes:
		var rs := n as _RiddleSpot
		if rs != null and is_instance_valid(rs) and rs.spot_id == str(spot["id"]):
			rs.set_texture(_texture_for(spot), float(spot["height"]))


## Skeleton Dig next to a "dig" spot; true when one was in reach (Cantrips).
func try_dig(px: float, pz: float) -> bool:
	var node := _world._first_node_in_range(spot_nodes, px, pz, IsoConst.INTERACT_RANGE) as _RiddleSpot
	if node == null or str(_RiddleSpots.def(node.spot_id).get("action", "")) != "dig":
		return false
	examine(node.spot_id, "dig")
	return true
