extends Node3D

const WorldMap    = preload("res://game_logic/world/WorldMap.gd")
const TextureGen  = preload("res://game_logic/TextureGen.gd")
const GrassBlades = preload("res://scenes/world/GrassBlades.gd")

@export var map_name: String = "main"
@export var target_door_id: String = ""

var world_map: WorldMap
var _player: CharacterBody3D
var _grass: Node3D
var _enemy_nodes: Dictionary = {}   # id -> Node3D
var _chest_nodes: Dictionary = {}   # id -> Node3D
var _door_nodes: Dictionary = {}    # id -> Node3D
var _tile_meshes: Node3D
var _wall_meshes: Node3D
var _entity_root: Node3D

@onready var _camera: Camera3D = $Camera3D
@onready var _hud: CanvasLayer = $HUD
@onready var _interact_label: Label = $HUD/InteractPrompt
@onready var _map_label: Label = $HUD/MapLabel

const WALL_FACE_H: float = 0.625

func _ready() -> void:
	world_map = WorldMap.new(map_name)
	_tile_meshes = Node3D.new()
	_tile_meshes.name = "TileGrid"
	add_child(_tile_meshes)
	_wall_meshes = Node3D.new()
	_wall_meshes.name = "WallGrid"
	add_child(_wall_meshes)
	_entity_root = Node3D.new()
	_entity_root.name = "Entities"
	add_child(_entity_root)

	_build_floor_collision()
	_build_tiles()
	_build_walls()
	_build_grass_blades()
	_spawn_entities()
	_spawn_player()
	_update_hud()

	_interact_label.hide()

func _update_hud() -> void:
	_map_label.text = "Map: %s" % map_name

func _build_grass_blades() -> void:
	_grass = GrassBlades.new()
	_grass.name = "GrassBlades"
	add_child(_grass)
	_grass.build(world_map)

func _build_floor_collision() -> void:
	var floor_body := StaticBody3D.new()
	floor_body.name = "FloorCollision"
	var col := CollisionShape3D.new()
	var box := BoxShape3D.new()
	var map_size: float = WorldMap.MAP_WIDTH * IsoConst.TILE_SIZE
	box.size = Vector3(map_size, 0.1, map_size)
	col.shape = box
	floor_body.position = Vector3(map_size * 0.5, -0.05, map_size * 0.5)
	floor_body.add_child(col)
	add_child(floor_body)

func _build_tiles() -> void:
	var grass_shader := load("res://assets/shaders/grass.gdshader") as Shader
	var grass_mat := ShaderMaterial.new()
	grass_mat.shader = grass_shader

	var hill_tex := TextureGen.hill_top()
	var hill_mat := StandardMaterial3D.new()
	hill_mat.albedo_texture = hill_tex

	var tile_size := Vector2(IsoConst.TILE_SIZE * 0.98, IsoConst.TILE_SIZE * 0.98)
	var grass_quad := PlaneMesh.new()
	grass_quad.size = tile_size
	grass_quad.subdivide_width = 8
	grass_quad.subdivide_depth = 8
	var hill_quad := PlaneMesh.new()
	hill_quad.size = tile_size

	for tz in range(WorldMap.MAP_HEIGHT):
		for tx in range(WorldMap.MAP_WIDTH):
			var tile := world_map.get_tile(tx, tz)
			if tile == WorldMap.TILE_GRASS or tile == WorldMap.TILE_HILL:
				var mi := MeshInstance3D.new()
				mi.mesh = grass_quad if tile == WorldMap.TILE_GRASS else hill_quad
				mi.material_override = hill_mat if tile == WorldMap.TILE_HILL else grass_mat
				mi.position = Vector3(
					tx * IsoConst.TILE_SIZE + IsoConst.TILE_SIZE * 0.5,
					0.0,
					tz * IsoConst.TILE_SIZE + IsoConst.TILE_SIZE * 0.5
				)
				_tile_meshes.add_child(mi)

func _build_walls() -> void:
	var wall_mat := StandardMaterial3D.new()
	wall_mat.albedo_texture = TextureGen.wall_side(true)

	for tz in range(WorldMap.MAP_HEIGHT):
		for tx in range(WorldMap.MAP_WIDTH):
			var tile := world_map.get_tile(tx, tz)
			if tile == WorldMap.TILE_WALL:
				var h := world_map.get_height(tx, tz)
				for level in range(h):
					var sb := StaticBody3D.new()
					var mi := MeshInstance3D.new()
					var box := BoxMesh.new()
					box.size = Vector3(IsoConst.TILE_SIZE, WALL_FACE_H, IsoConst.TILE_SIZE)
					mi.mesh = box
					mi.material_override = wall_mat
					var col := CollisionShape3D.new()
					col.shape = BoxShape3D.new()
					col.shape.size = box.size
					sb.add_child(mi)
					sb.add_child(col)
					sb.position = Vector3(
						tx * IsoConst.TILE_SIZE + IsoConst.TILE_SIZE * 0.5,
						level * WALL_FACE_H + WALL_FACE_H * 0.5,
						tz * IsoConst.TILE_SIZE + IsoConst.TILE_SIZE * 0.5
					)
					_wall_meshes.add_child(sb)

func flush_save_position() -> void:
	if _player:
		SaveManager.update_position(map_name, _player.position.x, _player.position.z)

func _spawn_player() -> void:
	var px: float
	var pz: float

	if not target_door_id.is_empty():
		# Spawning at a specific door (e.g. returning from a sub-map)
		var door := world_map.find_door_by_id(target_door_id)
		if not door.is_empty():
			px = door["x"]
			pz = door["z"]
		else:
			px = _get_default_px()
			pz = _get_default_pz()
	elif SaveManager.current_map == map_name and (SaveManager.player_x != 0.0 or SaveManager.player_z != 0.0):
		# Resume from saved position on this map
		px = SaveManager.player_x
		pz = SaveManager.player_z
	else:
		px = _get_default_px()
		pz = _get_default_pz()

	_player = _create_player_node()
	_player.position = Vector3(px, 0.1, pz)
	_entity_root.add_child(_player)

	# Position camera above player (rotation is fixed in scene, only translate)
	_camera.position = _player.position + Vector3(20, 20, 20)

func _get_default_px() -> float:
	if world_map.has_player_spawn():
		return world_map.player_spawn_x * IsoConst.TILE_SIZE + IsoConst.TILE_SIZE * 0.5
	return 3.0 * IsoConst.TILE_SIZE

func _get_default_pz() -> float:
	if world_map.has_player_spawn():
		return world_map.player_spawn_z * IsoConst.TILE_SIZE + IsoConst.TILE_SIZE * 0.5
	return 3.0 * IsoConst.TILE_SIZE

func _create_player_node() -> CharacterBody3D:
	var packed := load("res://scenes/world/entities/Player.tscn")
	if packed:
		return packed.instantiate()
	# Fallback: build inline
	var body := CharacterBody3D.new()
	body.name = "Player"
	body.set_script(load("res://scenes/world/entities/Player.gd"))
	var mi := MeshInstance3D.new()
	mi.mesh = BoxMesh.new()
	mi.mesh.size = Vector3(0.5, 1.0, 0.5)
	body.add_child(mi)
	var col := CollisionShape3D.new()
	col.shape = CapsuleShape3D.new()
	col.shape.radius = 0.3
	col.shape.height = 1.0
	body.add_child(col)
	return body

func _spawn_entities() -> void:
	# Enemies — skip any already defeated in this save
	for e_data in world_map.enemies:
		var eid: String = str(e_data.get("id", ""))
		if SaveManager.is_enemy_defeated(eid):
			continue
		_spawn_enemy(e_data)
	# Chests — mark opened ones as already-opened in the world data
	for c_data in world_map.chests:
		var cid: String = str(c_data.get("id", ""))
		if SaveManager.is_chest_opened(cid):
			c_data["opened"] = true
		_spawn_chest(c_data)
	# Doors
	for d_data in world_map.doors:
		_spawn_door(d_data)

func _spawn_enemy(e_data: Dictionary) -> void:
	var packed := load("res://scenes/world/entities/EnemyNPC.tscn")
	var node: Node3D
	if packed:
		node = packed.instantiate()
	else:
		node = _make_colored_box(Color.RED, 0.5, 1.0)
		node.name = "Enemy_" + e_data["id"]
	node.position = Vector3(e_data["x"], 0.5, e_data["z"])
	if node.has_method("init_from_data"):
		node.init_from_data(e_data)
	_entity_root.add_child(node)
	_enemy_nodes[e_data["id"]] = node

func _spawn_chest(c_data: Dictionary) -> void:
	var packed := load("res://scenes/world/entities/Chest.tscn")
	var node: Node3D
	if packed:
		node = packed.instantiate()
	else:
		node = _make_colored_box(Color(1.0, 0.8, 0.0), 0.6, 0.5)
		node.name = "Chest_" + c_data["id"]
	node.position = Vector3(c_data["x"], 0.25, c_data["z"])
	if node.has_method("init_from_data"):
		node.init_from_data(c_data)
	_entity_root.add_child(node)
	_chest_nodes[c_data["id"]] = node

func _spawn_door(d_data: Dictionary) -> void:
	var packed := load("res://scenes/world/entities/Door.tscn")
	var node: Node3D
	if packed:
		node = packed.instantiate()
	else:
		node = _make_colored_box(Color(0.5, 0.3, 0.1), 0.4, 1.5)
		node.name = "Door_" + d_data["id"]
	node.position = Vector3(d_data["x"], 0.75, d_data["z"])
	if node.has_method("init_from_data"):
		node.init_from_data(d_data)
	_entity_root.add_child(node)
	_door_nodes[d_data["id"]] = node

func _make_colored_box(color: Color, width: float, height: float) -> StaticBody3D:
	var sb := StaticBody3D.new()
	var mi := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(width, height, width)
	mi.mesh = box
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mi.material_override = mat
	sb.add_child(mi)
	var col := CollisionShape3D.new()
	col.shape = BoxShape3D.new()
	col.shape.size = box.size
	sb.add_child(col)
	return sb

func _process(delta: float) -> void:
	if _player == null:
		return
	_camera.position = _player.position + Vector3(20, 20, 20)
	if _grass:
		_grass.update_player(_player.position, delta, _player.is_on_floor())
	_check_interactions()
	SaveManager.update_position(map_name, _player.position.x, _player.position.z)

func _check_interactions() -> void:
	var px := _player.position.x
	var pz := _player.position.z

	# Check nearby door for [E] prompt
	var door := world_map.find_nearby_door(px, pz, IsoConst.INTERACT_RANGE)
	var chest := world_map.find_nearby_chest(px, pz, IsoConst.INTERACT_RANGE)

	if not door.is_empty() or not chest.is_empty():
		_interact_label.show()
	else:
		_interact_label.hide()

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("interact"):
		_handle_interact()

func _handle_interact() -> void:
	if _player == null:
		return
	var px := _player.position.x
	var pz := _player.position.z

	# Door
	var door := world_map.find_nearby_door(px, pz, IsoConst.INTERACT_RANGE)
	if not door.is_empty():
		var target_map: String = door.get("target_map", "")
		var tdoor: String = door.get("target_door_id", "")
		if target_map.is_empty():
			SceneManager.exit_map()
		else:
			SceneManager.enter_map(target_map, tdoor)
		return

	# Chest
	var chest := world_map.find_nearby_chest(px, pz, IsoConst.INTERACT_RANGE)
	if not chest.is_empty() and not chest.get("opened", false):
		chest["opened"] = true
		var cid: String = str(chest.get("id", ""))
		SaveManager.mark_chest_opened(cid)
		var node := _chest_nodes.get(chest["id"]) as Node3D
		if node and node.has_method("mark_opened"):
			node.mark_opened()
		GameBus.chest_opened.emit(chest.get("card_ids", []))
		return
