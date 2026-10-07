## Madrian's starter-zone camps (GID-141 / TID-591): keeps each `StarterZone`
## camp near the player stocked with its authored enemies, refilling a fallen
## slot after `StarterZone.CAMP_RESPAWN_S`. Camp enemies are loose enemies (like
## night-hunt spectres) with a preset `enemy_level`, and never saved as defeated.
## Created by `WorldScene._ensure_world_modules()` as `starter_camps`; ticked
## from WorldScene's overworld branch.
extends Node

const _WorldScene = preload("res://scenes/world/WorldScene.gd")
const _StarterZone = preload("res://game_logic/world/StarterZone.gd")
const _EnemyRegistry = preload("res://autoloads/EnemyRegistry.gd")
const _LooseEnemySpawner = preload("res://scenes/world/LooseEnemySpawner.gd")
const _SpriteRegistry = preload("res://game_logic/SpriteRegistry.gd")
const _RealmLayout = preload("res://game_logic/world/RealmLayout.gd")
const _WorldEntityBase = preload("res://scenes/world/entities/WorldEntityBase.gd")
const _CampDressing = preload("res://game_logic/world/CampDressing.gd")
const _TownDecor = preload("res://game_logic/world/TownDecor.gd")
## TownDecor set-piece animations (GID-167 / GID-170, tools/generate_fountain.py + generate_town_pieces.py).
const _DECOR_FRAMES: Dictionary = {
	"fountain": [preload("res://assets/textures/props/fountain_0.png"),
		preload("res://assets/textures/props/fountain_1.png"),
		preload("res://assets/textures/props/fountain_2.png"),
		preload("res://assets/textures/props/fountain_3.png")],
	# GID-170, tools/generate_town_pieces.py
	"well": [preload("res://assets/textures/props/well_0.png"),
		preload("res://assets/textures/props/well_1.png"),
		preload("res://assets/textures/props/well_2.png"),
		preload("res://assets/textures/props/well_3.png")],
	"brazier": [preload("res://assets/textures/props/brazier_0.png"),
		preload("res://assets/textures/props/brazier_1.png"),
		preload("res://assets/textures/props/brazier_2.png"),
		preload("res://assets/textures/props/brazier_3.png")],
	"grand_fountain": [preload("res://assets/textures/props/grand_fountain_0.png"),
		preload("res://assets/textures/props/grand_fountain_1.png"),
		preload("res://assets/textures/props/grand_fountain_2.png"),
		preload("res://assets/textures/props/grand_fountain_3.png")],
	"statue": [preload("res://assets/textures/props/statue_0.png"),
		preload("res://assets/textures/props/statue_1.png"),
		preload("res://assets/textures/props/statue_2.png"),
		preload("res://assets/textures/props/statue_3.png")],
}
const _DECOR_FPS: float = 6.0
const _POOL_STEP := Color(0.67, 0.65, 0.63)
const _POOL_MARBLE := Color(0.89, 0.87, 0.82)
const _POOL_GOLD := Color(0.94, 0.77, 0.28)
const _POOL_WATER := Color(0.28, 0.55, 0.81)
## Wall collision layer (ChunkRenderer wall bodies), so Ghost Phase passes through it too.
const _WALL_LAYER: int = 4

## How often camps are checked (s).
const CHECK_INTERVAL: float = 1.5

var _world: _WorldScene = null
var _timer: float = 0.0
## member id → live node
var _members: Dictionary = {}
## member id → seconds until it may refill (only while fallen)
var _cooldowns: Dictionary = {}
## Graveyard + camp dressing root (GID-143 / TID-605, GID-166), built once per overworld load.
var _scenery: Node3D = null


func tick(delta: float) -> void:
	for id: Variant in _cooldowns.keys():
		_cooldowns[id] = float(_cooldowns[id]) - delta
	_timer -= delta
	if _timer > 0.0:
		return
	_timer = CHECK_INTERVAL
	if _scenery == null and _world.map_name == "main" and not NetworkManager.is_dedicated_server():
		_build_scenery()
	var player: Node3D = _world._player
	if player == null or _world.map_name != "main" or NetworkManager.is_active():
		return
	for camp: Dictionary in _StarterZone.CAMPS:
		var t: Vector2i = camp["tile"]
		var centre := Vector3(IsoConst.tile_center(t.x), 0.0, IsoConst.tile_center(t.y))
		var near: bool = Vector2(centre.x - player.position.x, centre.z - player.position.z).length() \
				<= _StarterZone.ACTIVE_RANGE
		for slot: int in range(int(camp["count"])):
			_update_slot(camp, slot, near)
	_update_barrow_king(player)

func _update_slot(camp: Dictionary, slot: int, near: bool) -> void:
	var id: String = _StarterZone.member_id(camp, slot)
	var node: Node3D = _world._valid_node3d(_members.get(id))
	if node != null:
		if not near and not SceneManager.fights_in_world():
			_despawn(id, node)
		return
	if _members.has(id):
		# Fell since the last check: start its refill timer.
		_members.erase(id)
		_world._enemy_nodes.erase(id)
		_world._loose_enemy_nodes.erase(id)
		_cooldowns[id] = _StarterZone.CAMP_RESPAWN_S
		return
	if not near or float(_cooldowns.get(id, 0.0)) > 0.0:
		return
	_cooldowns.erase(id)
	_spawn(camp, slot, id)

func _spawn(camp: Dictionary, slot: int, id: String) -> void:
	var t: Vector2i = _StarterZone.slot_tile(camp, slot)
	var x: float = IsoConst.tile_center(t.x)
	var z: float = IsoConst.tile_center(t.y)
	var etype: String = str(camp["enemy_type"])
	_members[id] = _LooseEnemySpawner.spawn(_world, {
		"id": id,
		"enemy_type": etype,
		"enemy_deck": _EnemyRegistry.get_deck(etype),
		"tracking": bool(camp.get("tracking", false)),
		"enemy_level": int(camp["level"]),
		"camp": str(camp["id"]),
	}, x, z)

## GID-149: the unique Barrow King, spawned beside his crypt once it is opened.
func _update_barrow_king(player: Node3D) -> void:
	var bk: Dictionary = _StarterZone.BARROW_KING
	var id: String = str(bk["id"])
	var save := SceneManager.save_manager
	if _world._valid_node3d(_members.get(id)) != null \
			or not _StarterZone.barrow_king_awake(save.quests_completed, save.defeated_enemies):
		return
	var t: Vector2i = bk["tile"]
	var x: float = IsoConst.tile_center(t.x)
	var z: float = IsoConst.tile_center(t.y)
	if Vector2(x - player.position.x, z - player.position.z).length() > _StarterZone.ACTIVE_RANGE:
		return
	_members[id] = _LooseEnemySpawner.spawn(_world, {"id": id, "enemy_type": str(bk["enemy_type"]),
		"tracking": false, "enemy_deck": _EnemyRegistry.get_deck(str(bk["enemy_type"])),
		"enemy_level": int(bk["level"])}, x, z)

func _despawn(id: String, node: Node3D) -> void:
	_members.erase(id)
	_world._enemy_nodes.erase(id)
	_world._loose_enemy_nodes.erase(id)
	node.queue_free()

## Headstones, the iron fence and the crypt door as static billboards, then the camp dressing.
func _build_scenery() -> void:
	_scenery = Node3D.new()
	_scenery.name = "StarterScenery"
	_world._entity_root.add_child(_scenery)
	for entry: Array in _StarterZone.graveyard_props():
		var tex: Texture2D = _SpriteRegistry.graveyard_prop(str(entry[0]))
		if tex == null:
			continue
		var t: Vector2i = _RealmLayout.to_world_tile("madrian", entry[1] as Vector2i)
		var axis: String = str(entry[2])
		var off: Vector2 = entry[3]
		var x: float = (float(t.x) + 0.5 + off.x) * IsoConst.TILE_SIZE
		var z: float = (float(t.y) + 0.5 + off.y) * IsoConst.TILE_SIZE
		var sprite := Sprite3D.new()
		_SpriteRegistry.apply_billboard_flags(sprite)
		_SpriteRegistry.setup_sprite(sprite, tex)
		var holder := Node3D.new()
		if axis != "":
			# A flat, double-sided panel along the fence line (TID-605 fix).
			sprite.billboard = BaseMaterial3D.BILLBOARD_DISABLED
			holder.rotation.y = PI * 0.5 if axis == "z" else 0.0
		holder.position = Vector3(x, _world.get_terrain_height(x, z), z)
		holder.add_child(sprite)
		_scenery.add_child(holder)
	_build_camp_dressing()
	_build_town_decor()

## Each camp's themed props (CampDressing): orchard trees, granary, barrow, cart...
func _build_camp_dressing() -> void:
	for entry: Array in _CampDressing.all_props():
		var tex: Texture2D = _CampDressing.texture(str(entry[0]))
		if tex == null:
			continue
		var p: Vector2 = entry[1]
		var x: float = p.x * IsoConst.TILE_SIZE
		var z: float = p.y * IsoConst.TILE_SIZE
		var sprite := Sprite3D.new()
		_SpriteRegistry.apply_billboard_flags(sprite)
		_SpriteRegistry.setup_sprite_height(sprite, tex, float(entry[2]))
		sprite.position.x = x
		sprite.position.z = z
		sprite.position.y += _world.get_terrain_height(x, z)
		_scenery.add_child(sprite)

## Town set pieces (TownDecor): an animated billboard on a solid cylinder.
func _build_town_decor() -> void:
	for town: String in _RealmLayout.town_names():
		for piece: Dictionary in _TownDecor.pieces(town):
			var frames_list: Array = _DECOR_FRAMES.get(str(piece["key"]), [])
			if frames_list.is_empty():
				continue
			var t: Vector2i = _RealmLayout.to_world_tile(town, piece["tile"] as Vector2i)
			var x: float = IsoConst.tile_center(t.x)
			var z: float = IsoConst.tile_center(t.y)
			var frames := SpriteFrames.new()
			frames.set_animation_speed(&"default", _DECOR_FPS)
			for tex: Texture2D in frames_list:
				frames.add_frame(&"default", tex)
			var sprite := AnimatedSprite3D.new()
			_SpriteRegistry.apply_billboard_flags(sprite)
			sprite.sprite_frames = frames
			var first: Texture2D = frames_list[0]
			var h: float = float(piece["height"])
			sprite.pixel_size = h / float(first.get_height())
			sprite.position.y = h * 0.5 + 0.02
			var half: float = (float(piece["radius"]) + 0.5) * IsoConst.TILE_SIZE
			var body := StaticBody3D.new()
			body.name = "Decor_%s_%s" % [town, str(piece["key"])]
			body.collision_layer = _WALL_LAYER
			body.collision_mask = 0
			var shape := CollisionShape3D.new()
			var cyl := CylinderShape3D.new()
			cyl.radius = half * 0.9
			cyl.height = 2.0
			shape.shape = cyl
			shape.position.y = 1.0
			body.add_child(shape)
			body.add_child(sprite)
			if bool(piece.get("pool", false)):
				_add_pool(body, half)
			body.position = Vector3(x, _world.get_terrain_height(x, z), z)
			_scenery.add_child(body)
			sprite.play(&"default")

## A wide, low octagonal marble basin of water on the ground under a set piece
## (GID-170): a step, the marble wall with a gold band, then the water, so a big
## fountain sits in the square instead of standing on it.
func _add_pool(body: StaticBody3D, half: float) -> void:
	var layers: Array = [  # [radius share, height, colour]
		[1.0, 0.14, _POOL_STEP], [0.9, 0.44, _POOL_GOLD], [0.88, 0.5, _POOL_MARBLE], [0.76, 0.52, _POOL_WATER]]
	for layer: Array in layers:
		var cyl := CylinderMesh.new()
		cyl.top_radius = half * float(layer[0])
		cyl.bottom_radius = cyl.top_radius
		cyl.height = float(layer[1])
		cyl.radial_segments = 8
		cyl.rings = 1
		var mi := MeshInstance3D.new()
		mi.mesh = cyl
		mi.material_override = _WorldEntityBase.unshaded_material(layer[2] as Color)
		mi.position.y = float(layer[1]) * 0.5
		body.add_child(mi)

## Camp members alive right now (tests / debugging).
func alive_count() -> int:
	var n: int = 0
	for id: Variant in _members:
		if _world._valid_node3d(_members[id]) != null:
			n += 1
	return n
