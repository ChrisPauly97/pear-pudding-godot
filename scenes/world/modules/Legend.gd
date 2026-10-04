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
const _LegendaryPotions = preload("res://game_logic/battle/LegendaryPotions.gd")
const _UiUtil = preload("res://scenes/ui/UiUtil.gd")
const _PUDDING_ICON := preload("res://assets/icons/items/pear_pudding.png")

const _BREW_BG := Color(0.07, 0.06, 0.12, 0.97)
const _GOLD := Color(1.0, 0.82, 0.35)

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
	if result == _RiddleSpots.RESULT_SOLVED:
		AudioManager.play_sfx("dig_success" if action == "dig" else "scroll_pickup")
		_solve(spot)
	if result == _RiddleSpots.RESULT_SOLVED and str(spot["sets_flag"]) == _RiddleSpots.PUDDING_FLAG:
		_brew_pudding(spot)
	else:
		_world._show_dialogue(_RiddleSpots.line_for(spot, result))


func _solve(spot: Dictionary) -> void:
	SceneManager.save_manager.set_story_flag(str(spot["sets_flag"]))
	GameBus.legend_riddle_solved.emit(str(spot["id"]))
	for n: Node3D in spot_nodes:
		var rs := n as _RiddleSpot
		if rs != null and is_instance_valid(rs) and rs.spot_id == str(spot["id"]):
			rs.set_texture(_texture_for(spot), float(spot["height"]))


## The payoff: Perrine's Bottomless Pudding joins the bag, with a brew panel.
func _brew_pudding(spot: Dictionary) -> void:
	SceneManager.save_manager.garden.grant_legendary(_LegendaryPotions.PEAR_PUDDING)
	AudioManager.play_sfx("battle_win")
	var vh: float = _world.get_viewport().get_visible_rect().size.y
	var modal: Dictionary = _world._build_modal(0.7, 0.6, _BREW_BG, 0.016, 0.03, 0.7)
	var layer: CanvasLayer = modal["layer"]
	var vbox: VBoxContainer = modal["vbox"]
	var title := _UiUtil.make_label("Perrine's Bottomless Pudding", int(vh * 0.036), _GOLD,
			HORIZONTAL_ALIGNMENT_CENTER, vbox)
	title.theme_type_variation = &"TitleLabel"
	_UiUtil.make_label("Legendary potion", int(vh * 0.02), Color(0.85, 0.75, 0.5), HORIZONTAL_ALIGNMENT_CENTER, vbox)
	var icon := TextureRect.new()
	icon.texture = _PUDDING_ICON
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.custom_minimum_size = Vector2(vh * 0.16, vh * 0.16)
	vbox.add_child(icon)
	var body := _UiUtil.make_label(str(spot["solved"]), int(vh * 0.021), Color.WHITE, HORIZONTAL_ALIGNMENT_LEFT, vbox)
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var how := _UiUtil.make_label(("Never empties. One sip per battle: full HP, ailments cleared, +1 mana. "
			+ "It sits on your Q / E quick slots — see the backpack's Items tab."), int(vh * 0.019), _GOLD,
			HORIZONTAL_ALIGNMENT_CENTER, vbox)
	how.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var row := _UiUtil.make_hbox(0, vbox)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	_UiUtil.make_button("Drink deep", Vector2(vh * 0.2, vh * 0.06), int(vh * 0.022), layer.queue_free, row)


## Skeleton Dig next to a "dig" spot; true when one was in reach (Cantrips).
func try_dig(px: float, pz: float) -> bool:
	var node := _world._first_node_in_range(spot_nodes, px, pz, IsoConst.INTERACT_RANGE) as _RiddleSpot
	if node == null or str(_RiddleSpots.def(node.spot_id).get("action", "")) != "dig":
		return false
	examine(node.spot_id, "dig")
	return true
