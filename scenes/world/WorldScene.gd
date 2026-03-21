extends Node3D

const WorldMap        = preload("res://game_logic/world/WorldMap.gd")
const TextureGen      = preload("res://game_logic/TextureGen.gd")
const GrassBlades     = preload("res://scenes/world/GrassBlades.gd")
const VirtualJoystick = preload("res://scenes/ui/VirtualJoystick.gd")
const InfiniteWorldGen = preload("res://game_logic/world/InfiniteWorldGen.gd")
const ChunkRenderer   = preload("res://scenes/world/ChunkRenderer.gd")

@export var map_name: String = "main"
@export var target_door_id: String = ""
@export var infinite: bool = true

# Named-map path
var world_map: WorldMap

# Common
var _player: CharacterBody3D
var _grass: Node3D
var _enemy_nodes: Dictionary = {}   # id -> Node3D
var _chest_nodes: Dictionary = {}   # id -> Node3D
var _door_nodes: Dictionary = {}    # id -> Node3D
var _tile_meshes: Node3D
var _wall_meshes: Node3D
var _entity_root: Node3D

# Infinite-world path
var _chunk_data_cache: Dictionary = {}    # Vector2i -> ChunkData (RefCounted)
var _chunk_renderers: Dictionary = {}     # Vector2i -> ChunkRenderer
var _active_chest_data: Dictionary = {}  # chest_id -> Dictionary
var _last_player_chunk: Vector2i = Vector2i(-9999, -9999)
var _terrain_mat: ShaderMaterial

const LOAD_RADIUS:   int = 6
const UNLOAD_RADIUS: int = 7
const WORLD_SEED:    int = 42

@onready var _camera: Camera3D = $Camera3D
@onready var _hud: CanvasLayer = $HUD
@onready var _interact_label: Label = $HUD/InteractPrompt
@onready var _map_label: Label = $HUD/MapLabel

const WALL_FACE_H: float = 0.625

# Terrain height constants
const HILL_PEAK_H:    float = 1.5
const HILL_RAMP_R:    float = 6.0
const TERRAIN_VDENSITY: int = 4

func _ready() -> void:
	_tile_meshes = Node3D.new()
	_tile_meshes.name = "TileGrid"
	add_child(_tile_meshes)
	_wall_meshes = Node3D.new()
	_wall_meshes.name = "WallGrid"
	add_child(_wall_meshes)
	_entity_root = Node3D.new()
	_entity_root.name = "Entities"
	add_child(_entity_root)

	if infinite:
		_terrain_mat = _make_terrain_material()
		_build_grass_blades_node()
		_spawn_player_infinite()
		_update_chunks()
	else:
		world_map = WorldMap.new(map_name)
		_build_terrain()
		_build_walls()
		_build_grass_blades()
		_spawn_entities()
		_spawn_player()

	_update_hud()
	_interact_label.hide()

	var joystick := VirtualJoystick.new()
	_hud.add_child(joystick)

	var vh: float = get_viewport().get_visible_rect().size.y
	var menu_btn := Button.new()
	menu_btn.text = "Menu"
	menu_btn.custom_minimum_size = Vector2(vh * 0.12, vh * 0.05)
	menu_btn.position = Vector2(vh * 0.01, vh * 0.01)
	menu_btn.pressed.connect(func() -> void: SceneManager.go_to_menu())
	_hud.add_child(menu_btn)

func _update_hud() -> void:
	if infinite:
		_map_label.text = "World: Infinite"
	else:
		_map_label.text = "Map: %s" % map_name

# ── Infinite world: chunk streaming ────────────────────────────────────────

func _build_grass_blades_node() -> void:
	_grass = GrassBlades.new()
	_grass.name = "GrassBlades"
	add_child(_grass)

func _spawn_player_infinite() -> void:
	var px: float = 3.0 * IsoConst.TILE_SIZE
	var pz: float = 3.0 * IsoConst.TILE_SIZE
	if SaveManager.current_map == "infinite" and (SaveManager.player_x != 0.0 or SaveManager.player_z != 0.0):
		px = SaveManager.player_x
		pz = SaveManager.player_z
	_player = _create_player_node()
	_player.position = Vector3(px, 0.1, pz)
	_entity_root.add_child(_player)
	_camera.position = _player.position + Vector3(20, 20, 20)

# Returns the tile type at global tile coordinates (wtx, wtz).
# Used by ChunkRenderer during terrain height computation so hills blend
# seamlessly across chunk borders.
func get_tile_global(wtx: int, wtz: int) -> int:
	var cx: int = int(floor(float(wtx) / float(IsoConst.CHUNK_SIZE)))
	var cz: int = int(floor(float(wtz) / float(IsoConst.CHUNK_SIZE)))
	var key := Vector2i(cx, cz)
	if not _chunk_data_cache.has(key):
		_chunk_data_cache[key] = InfiniteWorldGen.generate_chunk_data_only(cx, cz, WORLD_SEED)
	var lx: int = wtx - cx * IsoConst.CHUNK_SIZE
	var lz: int = wtz - cz * IsoConst.CHUNK_SIZE
	var chunk: RefCounted = _chunk_data_cache[key]
	return chunk.get_tile(lx, lz)

func _update_chunks() -> void:
	if _player == null:
		return

	var chunk_world: float = float(IsoConst.CHUNK_SIZE) * IsoConst.TILE_SIZE
	var pcx: int = int(floor(_player.position.x / chunk_world))
	var pcz: int = int(floor(_player.position.z / chunk_world))
	var player_chunk := Vector2i(pcx, pcz)

	# 1. Generate data-only for border ring (LOAD_RADIUS + 1) so cross-chunk
	#    terrain height lookups never miss during chunk mesh builds.
	var border: int = LOAD_RADIUS + 1
	for dz in range(-border, border + 1):
		for dx in range(-border, border + 1):
			var key := Vector2i(pcx + dx, pcz + dz)
			if not _chunk_data_cache.has(key):
				_chunk_data_cache[key] = InfiniteWorldGen.generate_chunk_data_only(key.x, key.y, WORLD_SEED)

	# 2. Build/render chunks within LOAD_RADIUS
	for dz in range(-LOAD_RADIUS, LOAD_RADIUS + 1):
		for dx in range(-LOAD_RADIUS, LOAD_RADIUS + 1):
			var key := Vector2i(pcx + dx, pcz + dz)
			if _chunk_renderers.has(key):
				continue
			# Ensure full data (with entities) exists for this chunk
			if not _chunk_data_cache.has(key) or not _chunk_data_cache[key].is_generated:
				_chunk_data_cache[key] = InfiniteWorldGen.generate_chunk(key.x, key.y, WORLD_SEED)
			# Register any chests in this chunk into the active set
			var chunk: RefCounted = _chunk_data_cache[key]
			for c_data in chunk.chests:
				var cid: String = str(c_data.get("id", ""))
				_active_chest_data[cid] = c_data

			var renderer: ChunkRenderer = ChunkRenderer.new()
			renderer.name = "Chunk_%d_%d" % [key.x, key.y]
			add_child(renderer)
			renderer.build(chunk, key, self, _terrain_mat)
			_chunk_renderers[key] = renderer

	# 3. Unload chunks beyond UNLOAD_RADIUS
	var keys_to_remove: Array[Vector2i] = []
	for raw_key in _chunk_renderers:
		var typed_key: Vector2i = raw_key
		if abs(typed_key.x - pcx) > UNLOAD_RADIUS or abs(typed_key.y - pcz) > UNLOAD_RADIUS:
			keys_to_remove.append(typed_key)

	for key in keys_to_remove:
		var renderer: ChunkRenderer = _chunk_renderers[key]
		renderer.teardown()
		_chunk_renderers.erase(key)
		var grass_node: GrassBlades = _grass as GrassBlades
		if grass_node:
			grass_node.remove_chunk(key)
		# Remove chests belonging to this chunk from the active set
		var chunk: RefCounted = _chunk_data_cache[key]
		for c_data in chunk.chests:
			var cid: String = str(c_data.get("id", ""))
			_active_chest_data.erase(cid)
			_chest_nodes.erase(cid)

	_last_player_chunk = player_chunk

# Called by ChunkRenderer after spawning an enemy
func register_enemy(eid: String, node: Node3D) -> void:
	_enemy_nodes[eid] = node

# Called by ChunkRenderer after spawning a chest
func register_chest(cid: String, node: Node3D, c_data: Dictionary) -> void:
	_chest_nodes[cid] = node
	_active_chest_data[cid] = c_data

# Find nearest active chest within range
func _find_nearby_chest_infinite(px: float, pz: float, range_dist: float) -> Dictionary:
	for raw_id in _active_chest_data:
		var cid: String = raw_id
		var d: Dictionary = _active_chest_data[cid]
		if d.get("opened", false):
			continue
		var dx: float = float(d.get("x", 0.0)) - px
		var dz: float = float(d.get("z", 0.0)) - pz
		if sqrt(dx * dx + dz * dz) <= range_dist:
			return d
	return {}

# ── Named-map (bounded) path ───────────────────────────────────────────────

func _build_grass_blades() -> void:
	_grass = GrassBlades.new()
	_grass.name = "GrassBlades"
	add_child(_grass)
	_grass.build(world_map)

func _build_terrain() -> void:
	var nvx: int = WorldMap.MAP_WIDTH  * TERRAIN_VDENSITY + 1
	var nvz: int = WorldMap.MAP_HEIGHT * TERRAIN_VDENSITY + 1
	var step: float = IsoConst.TILE_SIZE / float(TERRAIN_VDENSITY)

	var hfield := _compute_terrain_heights(nvx, nvz, step)
	_build_terrain_mesh(hfield, nvx, nvz, step)
	_build_terrain_collision(hfield, nvx, nvz, step)

func _compute_terrain_heights(nvx: int, nvz: int, step: float) -> PackedFloat32Array:
	var field := PackedFloat32Array()
	field.resize(nvx * nvz)

	var tile_range: int = int(ceil(HILL_RAMP_R / IsoConst.TILE_SIZE)) + 1

	for iz in range(nvz):
		for ix in range(nvx):
			var wx: float = ix * step
			var wz: float = iz * step
			var vtx: int = int(wx / IsoConst.TILE_SIZE)
			var vtz: int = int(wz / IsoConst.TILE_SIZE)

			var h: float = 0.0
			for dtz in range(-tile_range, tile_range + 1):
				for dtx in range(-tile_range, tile_range + 1):
					var ttx: int = vtx + dtx
					var ttz: int = vtz + dtz
					if world_map.get_tile(ttx, ttz) != WorldMap.TILE_HILL:
						continue
					var near_x: float = clamp(wx, float(ttx) * IsoConst.TILE_SIZE, float(ttx + 1) * IsoConst.TILE_SIZE)
					var near_z: float = clamp(wz, float(ttz) * IsoConst.TILE_SIZE, float(ttz + 1) * IsoConst.TILE_SIZE)
					var dist: float = sqrt((wx - near_x) * (wx - near_x) + (wz - near_z) * (wz - near_z))
					if dist < HILL_RAMP_R:
						var t: float = 1.0 - dist / HILL_RAMP_R
						t = t * t * (3.0 - 2.0 * t)
						var contrib: float = HILL_PEAK_H * t
						if contrib > h:
							h = contrib
			field[iz * nvx + ix] = h
	return field

func _build_terrain_mesh(hfield: PackedFloat32Array, nvx: int, nvz: int, step: float) -> void:
	var total_verts: int = nvx * nvz
	var total_quads: int = (nvx - 1) * (nvz - 1)

	var verts   := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs     := PackedVector2Array()
	var colors  := PackedColorArray()
	var indices := PackedInt32Array()

	verts.resize(total_verts)
	normals.resize(total_verts)
	uvs.resize(total_verts)
	colors.resize(total_verts)
	indices.resize(total_quads * 6)

	for iz in range(nvz):
		for ix in range(nvx):
			var i: int = iz * nvx + ix
			var x: float = ix * step
			var z: float = iz * step
			var h: float = hfield[i]
			verts[i] = Vector3(x, h, z)
			uvs[i]   = Vector2(x, z)
			var blend: float = clamp(h / HILL_PEAK_H, 0.0, 1.0)
			colors[i] = Color(blend, blend, blend, 1.0)

	for iz in range(nvz):
		for ix in range(nvx):
			var i: int = iz * nvx + ix
			var ix_l: int = max(ix - 1, 0)
			var ix_r: int = min(ix + 1, nvx - 1)
			var iz_d: int = max(iz - 1, 0)
			var iz_u: int = min(iz + 1, nvz - 1)
			var hL: float = hfield[iz   * nvx + ix_l]
			var hR: float = hfield[iz   * nvx + ix_r]
			var hD: float = hfield[iz_d * nvx + ix  ]
			var hU: float = hfield[iz_u * nvx + ix  ]
			var dx: float = (hR - hL) / (2.0 * step)
			var dz: float = (hU - hD) / (2.0 * step)
			normals[i] = Vector3(-dx, 1.0, -dz).normalized()

	var idx: int = 0
	for iz in range(nvz - 1):
		for ix in range(nvx - 1):
			var a: int = iz * nvx + ix
			var b: int = iz * nvx + (ix + 1)
			var c: int = (iz + 1) * nvx + ix
			var d: int = (iz + 1) * nvx + (ix + 1)
			indices[idx]     = a; indices[idx + 1] = c; indices[idx + 2] = b
			indices[idx + 3] = b; indices[idx + 4] = c; indices[idx + 5] = d
			idx += 6

	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_COLOR]  = colors
	arrays[Mesh.ARRAY_INDEX]  = indices

	var terrain_mesh := ArrayMesh.new()
	terrain_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)

	var mi := MeshInstance3D.new()
	mi.mesh = terrain_mesh
	mi.material_override = _make_terrain_material()
	_tile_meshes.add_child(mi)

func _make_terrain_material() -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = load("res://assets/shaders/terrain.gdshader") as Shader
	mat.set_shader_parameter("grass_texture", TextureGen.grass())
	mat.set_shader_parameter("hill_texture",  TextureGen.hill_top())
	mat.set_shader_parameter("uv_scale", 0.5)
	return mat

func _build_terrain_collision(_hfield: PackedFloat32Array, _nvx: int, _nvz: int, _step: float) -> void:
	# Use a simple flat BoxShape3D floor — reliable across all Godot 4 builds.
	var map_world_x: float = WorldMap.MAP_WIDTH  * IsoConst.TILE_SIZE
	var map_world_z: float = WorldMap.MAP_HEIGHT * IsoConst.TILE_SIZE
	var box := BoxShape3D.new()
	box.size = Vector3(map_world_x, 0.1, map_world_z)
	var col := CollisionShape3D.new()
	col.shape = box
	var body := StaticBody3D.new()
	body.name = "TerrainCollision"
	body.position = Vector3(map_world_x * 0.5, -0.05, map_world_z * 0.5)
	body.add_child(col)
	add_child(body)

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
		var save_map: String = "infinite" if infinite else map_name
		SaveManager.update_position(save_map, _player.position.x, _player.position.z)

func _spawn_player() -> void:
	var px: float
	var pz: float

	if not target_door_id.is_empty():
		var door := world_map.find_door_by_id(target_door_id)
		if not door.is_empty():
			px = door["x"]
			pz = door["z"]
		else:
			px = _get_default_px()
			pz = _get_default_pz()
	elif SaveManager.current_map == map_name and (SaveManager.player_x != 0.0 or SaveManager.player_z != 0.0):
		px = SaveManager.player_x
		pz = SaveManager.player_z
	else:
		px = _get_default_px()
		pz = _get_default_pz()

	_player = _create_player_node()
	_player.position = Vector3(px, 0.1, pz)
	_entity_root.add_child(_player)
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
	for e_data in world_map.enemies:
		var eid: String = str(e_data.get("id", ""))
		if SaveManager.is_enemy_defeated(eid):
			continue
		_spawn_enemy(e_data)
	for c_data in world_map.chests:
		var cid: String = str(c_data.get("id", ""))
		if SaveManager.is_chest_opened(cid):
			c_data["opened"] = true
		_spawn_chest(c_data)
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

# ── Per-frame update ───────────────────────────────────────────────────────

func _process(delta: float) -> void:
	if _player == null:
		return
	_camera.position = _player.position + Vector3(20, 20, 20)
	if _grass:
		_grass.update_player(_player.position, delta, _player.is_on_floor())

	if infinite:
		var chunk_world: float = float(IsoConst.CHUNK_SIZE) * IsoConst.TILE_SIZE
		var pcx: int = int(floor(_player.position.x / chunk_world))
		var pcz: int = int(floor(_player.position.z / chunk_world))
		if Vector2i(pcx, pcz) != _last_player_chunk:
			_update_chunks()
		SaveManager.update_position("infinite", _player.position.x, _player.position.z)
	else:
		SaveManager.update_position(map_name, _player.position.x, _player.position.z)

	_check_interactions()

func _check_interactions() -> void:
	var px: float = _player.position.x
	var pz: float = _player.position.z

	if infinite:
		var chest := _find_nearby_chest_infinite(px, pz, IsoConst.INTERACT_RANGE)
		if not chest.is_empty():
			_interact_label.show()
		else:
			_interact_label.hide()
	else:
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
	var px: float = _player.position.x
	var pz: float = _player.position.z

	if infinite:
		var chest := _find_nearby_chest_infinite(px, pz, IsoConst.INTERACT_RANGE)
		if not chest.is_empty() and not chest.get("opened", false):
			chest["opened"] = true
			var cid: String = str(chest.get("id", ""))
			SaveManager.mark_chest_opened(cid)
			var node := _chest_nodes.get(cid) as Node3D
			if node and node.has_method("mark_opened"):
				node.mark_opened()
			GameBus.chest_opened.emit(chest.get("card_ids", []))
		return

	# Named-map path
	var door := world_map.find_nearby_door(px, pz, IsoConst.INTERACT_RANGE)
	if not door.is_empty():
		var target_map: String = door.get("target_map", "")
		var tdoor: String = door.get("target_door_id", "")
		if target_map.is_empty():
			SceneManager.exit_map()
		else:
			SceneManager.enter_map(target_map, tdoor)
		return

	var chest := world_map.find_nearby_chest(px, pz, IsoConst.INTERACT_RANGE)
	if not chest.is_empty() and not chest.get("opened", false):
		chest["opened"] = true
		var cid: String = str(chest.get("id", ""))
		SaveManager.mark_chest_opened(cid)
		var node := _chest_nodes.get(chest["id"]) as Node3D
		if node and node.has_method("mark_opened"):
			node.mark_opened()
		GameBus.chest_opened.emit(chest.get("card_ids", []))
