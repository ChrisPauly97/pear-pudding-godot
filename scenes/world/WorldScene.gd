extends Node3D

const WorldMap        = preload("res://game_logic/world/WorldMap.gd")
const TextureGen      = preload("res://game_logic/TextureGen.gd")
const GrassBlades     = preload("res://scenes/world/GrassBlades.gd")
const VirtualJoystick = preload("res://scenes/ui/VirtualJoystick.gd")
const InfiniteWorldGen = preload("res://game_logic/world/InfiniteWorldGen.gd")
const ChunkRenderer   = preload("res://scenes/world/ChunkRenderer.gd")
const _TerrainShader: Shader = preload("res://assets/shaders/terrain.gdshader")

# Preload entity scenes — avoids filesystem hits during spawning
const _PlayerScene = preload("res://scenes/world/entities/Player.tscn")
const _EnemyScene  = preload("res://scenes/world/entities/EnemyNPC.tscn")
const _ChestScene  = preload("res://scenes/world/entities/Chest.tscn")
const _DoorScene   = preload("res://scenes/world/entities/Door.tscn")

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
var _chunk_build_queue: Array[Vector2i] = []
var _last_save_pos: Vector2 = Vector2(-9999, -9999)
var _interact_timer: float = 0.0

const LOAD_RADIUS:      int = 6
const UNLOAD_RADIUS:    int = 7
const WORLD_SEED:       int = 42
const CHUNKS_PER_FRAME: int = 3
const INTERACT_INTERVAL: float = 0.15  # check interactions at ~7 Hz, not 60

@onready var _camera: Camera3D = $Camera3D
@onready var _hud: CanvasLayer = $HUD
@onready var _interact_label: Label = $HUD/InteractPrompt
@onready var _map_label: Label = $HUD/MapLabel

const WALL_FACE_H: float = 0.625

# Terrain height constants
const HILL_PEAK_H:    float = 1.5
const HILL_RAMP_R:    float = 6.0
const TERRAIN_VDENSITY: int = 2

func _setup_environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	# Match the terrain shader's grass colour under ambient+sun lighting
	env.background_color = Color(0.35, 0.53, 0.21)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_DISABLED
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)

func _ready() -> void:
	_setup_environment()
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
		_terrain_mat = _make_terrain_material(WORLD_SEED)
		_build_grass_blades_node()
		_spawn_player_infinite()
		_update_chunks()
		# Build all initial chunks synchronously so the world is ready
		# before the first frame — avoids runtime lag spikes on startup.
		while not _chunk_build_queue.is_empty():
			var key: Vector2i = _chunk_build_queue.pop_front()
			_build_chunk_at(key)
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
	_player.position = Vector3(px, get_terrain_height(px, pz) + 0.5, pz)
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

# Compute terrain height at a world position using the same smoothstep
# algorithm as the mesh builder.  Used for entity placement and physics.
func get_terrain_height(wx: float, wz: float) -> float:
	var curve_r: float = HILL_RAMP_R if not infinite else 3.0
	var peak_h: float = HILL_PEAK_H
	var tile_check: int = int(ceil(curve_r / IsoConst.TILE_SIZE)) + 1
	var vtx: int = int(wx / IsoConst.TILE_SIZE)
	var vtz: int = int(wz / IsoConst.TILE_SIZE)
	var curve_r_sq: float = curve_r * curve_r
	var min_dist_sq: float = curve_r_sq
	for dtz in range(-tile_check, tile_check + 1):
		for dtx in range(-tile_check, tile_check + 1):
			var ttx: int = vtx + dtx
			var ttz: int = vtz + dtz
			var tile_type: int
			if infinite:
				tile_type = get_tile_global(ttx, ttz)
			else:
				tile_type = world_map.get_tile(ttx, ttz)
			if tile_type != IsoConst.TILE_HILL:
				continue
			var near_x: float = clamp(wx, float(ttx) * IsoConst.TILE_SIZE, float(ttx + 1) * IsoConst.TILE_SIZE)
			var near_z: float = clamp(wz, float(ttz) * IsoConst.TILE_SIZE, float(ttz + 1) * IsoConst.TILE_SIZE)
			var ddx: float = wx - near_x
			var ddz: float = wz - near_z
			var dist_sq: float = ddx * ddx + ddz * ddz
			if dist_sq < min_dist_sq:
				min_dist_sq = dist_sq
	var t: float = 1.0 - sqrt(min_dist_sq) / curve_r
	t = t * t * (3.0 - 2.0 * t)
	return peak_h * t

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

	# 2. Queue new chunks — built gradually in _process to avoid frame spikes
	for dz in range(-LOAD_RADIUS, LOAD_RADIUS + 1):
		for dx in range(-LOAD_RADIUS, LOAD_RADIUS + 1):
			var key := Vector2i(pcx + dx, pcz + dz)
			if _chunk_renderers.has(key) or _chunk_build_queue.has(key):
				continue
			_chunk_build_queue.append(key)

	# Sort queue so nearest chunks are built first
	_chunk_build_queue.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		var da: int = (a.x - pcx) * (a.x - pcx) + (a.y - pcz) * (a.y - pcz)
		var db: int = (b.x - pcx) * (b.x - pcx) + (b.y - pcz) * (b.y - pcz)
		return da < db
	)

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

func _build_chunk_at(key: Vector2i) -> void:
	if _chunk_renderers.has(key):
		return
	# Drop stale queue entries outside the load radius
	var pcx: int = _last_player_chunk.x
	var pcz: int = _last_player_chunk.y
	if abs(key.x - pcx) > LOAD_RADIUS or abs(key.y - pcz) > LOAD_RADIUS:
		return
	if not _chunk_data_cache.has(key) or not _chunk_data_cache[key].has_entities:
		_chunk_data_cache[key] = InfiniteWorldGen.generate_chunk(key.x, key.y, WORLD_SEED)
	var chunk: RefCounted = _chunk_data_cache[key]
	for c_data in chunk.chests:
		var cid: String = str(c_data.get("id", ""))
		_active_chest_data[cid] = c_data
	var renderer: ChunkRenderer = ChunkRenderer.new()
	renderer.name = "Chunk_%d_%d" % [key.x, key.y]
	add_child(renderer)
	renderer.build(chunk, key, self, _terrain_mat)
	_chunk_renderers[key] = renderer

# Called by ChunkRenderer after spawning an enemy
func register_enemy(eid: String, node: Node3D) -> void:
	_enemy_nodes[eid] = node

# Called by ChunkRenderer after spawning a chest
func register_chest(cid: String, node: Node3D, c_data: Dictionary) -> void:
	_chest_nodes[cid] = node
	_active_chest_data[cid] = c_data

# Find nearest active chest within range
func _find_nearby_chest_infinite(px: float, pz: float, range_dist: float) -> Dictionary:
	var range_sq: float = range_dist * range_dist
	for d: Dictionary in _active_chest_data.values():
		if d.get("opened", false):
			continue
		var dx: float = float(d.get("x", 0.0)) - px
		var dz: float = float(d.get("z", 0.0)) - pz
		if dx * dx + dz * dz <= range_sq:
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
			# Encode wall flag in COLOR.g so the terrain shader shows stone floor
			var tx: int = int(x / IsoConst.TILE_SIZE)
			var tz: int = int(z / IsoConst.TILE_SIZE)
			var is_wall: float = 1.0 if world_map.get_tile(tx, tz) == WorldMap.TILE_WALL else 0.0
			colors[i] = Color(blend, is_wall, 0.0, 1.0)

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

	# ── Edge skirts: drop border vertices below ground to hide underside ──
	const SKIRT_Y: float = -0.5
	var skirt_count: int = (nvx + nvz) * 2
	var skirt_verts   := PackedVector3Array()
	var skirt_normals := PackedVector3Array()
	var skirt_uvs     := PackedVector2Array()
	var skirt_colors  := PackedColorArray()
	var skirt_indices := PackedInt32Array()
	skirt_verts.resize(skirt_count)
	skirt_normals.resize(skirt_count)
	skirt_uvs.resize(skirt_count)
	skirt_colors.resize(skirt_count)
	var skirt_seg: int = (nvx - 1) * 2 + (nvz - 1) * 2
	skirt_indices.resize(skirt_seg * 6)

	var si: int = 0
	var _edge_ids: Array[int] = []
	for ixx in range(nvx):
		for iz_edge in [0, nvz - 1]:
			var surf_i: int = iz_edge * nvx + ixx
			skirt_verts[si]   = Vector3(verts[surf_i].x, SKIRT_Y, verts[surf_i].z)
			skirt_normals[si] = normals[surf_i]
			skirt_uvs[si]     = uvs[surf_i]
			skirt_colors[si]  = colors[surf_i]
			_edge_ids.append(surf_i)
			_edge_ids.append(si)
			si += 1
	for izz in range(1, nvz - 1):
		for ix_edge in [0, nvx - 1]:
			var surf_i: int = izz * nvx + ix_edge
			skirt_verts[si]   = Vector3(verts[surf_i].x, SKIRT_Y, verts[surf_i].z)
			skirt_normals[si] = normals[surf_i]
			skirt_uvs[si]     = uvs[surf_i]
			skirt_colors[si]  = colors[surf_i]
			_edge_ids.append(surf_i)
			_edge_ids.append(si)
			si += 1

	var skirt_map: Dictionary = {}
	for ei in range(0, _edge_ids.size(), 2):
		skirt_map[_edge_ids[ei]] = _edge_ids[ei + 1]

	var sidx: int = 0
	for ixx in range(nvx - 1):
		var a: int = ixx; var b: int = ixx + 1
		var sa: int = total_verts + int(skirt_map[a])
		var sb: int = total_verts + int(skirt_map[b])
		skirt_indices[sidx] = a;  skirt_indices[sidx+1] = sa; skirt_indices[sidx+2] = b
		skirt_indices[sidx+3] = b; skirt_indices[sidx+4] = sa; skirt_indices[sidx+5] = sb
		sidx += 6
	for ixx in range(nvx - 1):
		var a: int = (nvz - 1) * nvx + ixx; var b: int = (nvz - 1) * nvx + ixx + 1
		var sa: int = total_verts + int(skirt_map[a])
		var sb: int = total_verts + int(skirt_map[b])
		skirt_indices[sidx] = a;  skirt_indices[sidx+1] = b;  skirt_indices[sidx+2] = sa
		skirt_indices[sidx+3] = b; skirt_indices[sidx+4] = sb; skirt_indices[sidx+5] = sa
		sidx += 6
	for izz in range(nvz - 1):
		var a: int = izz * nvx; var b: int = (izz + 1) * nvx
		var sa: int = total_verts + int(skirt_map[a])
		var sb: int = total_verts + int(skirt_map[b])
		skirt_indices[sidx] = a;  skirt_indices[sidx+1] = b;  skirt_indices[sidx+2] = sa
		skirt_indices[sidx+3] = b; skirt_indices[sidx+4] = sb; skirt_indices[sidx+5] = sa
		sidx += 6
	for izz in range(nvz - 1):
		var a: int = izz * nvx + nvx - 1; var b: int = (izz + 1) * nvx + nvx - 1
		var sa: int = total_verts + int(skirt_map[a])
		var sb: int = total_verts + int(skirt_map[b])
		skirt_indices[sidx] = a;  skirt_indices[sidx+1] = sa; skirt_indices[sidx+2] = b
		skirt_indices[sidx+3] = b; skirt_indices[sidx+4] = sa; skirt_indices[sidx+5] = sb
		sidx += 6

	verts.append_array(skirt_verts)
	normals.append_array(skirt_normals)
	uvs.append_array(skirt_uvs)
	colors.append_array(skirt_colors)
	indices.append_array(skirt_indices)

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

func _make_terrain_material(seed: int = 0) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = _TerrainShader
	mat.set_shader_parameter("grass_texture",     TextureGen.grass(seed))
	mat.set_shader_parameter("hill_side_texture", TextureGen.hill_side(seed + 1))
	mat.set_shader_parameter("hill_texture",      TextureGen.hill_top(seed + 2))
	mat.set_shader_parameter("wall_top_texture",  TextureGen.wall_top())
	mat.set_shader_parameter("uv_scale", 0.5)
	return mat

func _build_terrain_collision(hfield: PackedFloat32Array, nvx: int, nvz: int, _step: float) -> void:
	var hmap := HeightMapShape3D.new()
	hmap.map_width = nvx
	hmap.map_depth = nvz
	hmap.map_data  = hfield
	var col := CollisionShape3D.new()
	col.shape = hmap
	var body := StaticBody3D.new()
	body.name = "TerrainCollision"
	body.collision_layer = 2   # terrain layer
	body.collision_mask  = 0   # terrain doesn't need to detect others
	# HeightMapShape3D is centered on its own origin
	var map_world_x: float = WorldMap.MAP_WIDTH  * IsoConst.TILE_SIZE
	var map_world_z: float = WorldMap.MAP_HEIGHT * IsoConst.TILE_SIZE
	body.position = Vector3(map_world_x * 0.5, 0.0, map_world_z * 0.5)
	body.add_child(col)
	add_child(body)

func _build_walls() -> void:
	var wall_mat := StandardMaterial3D.new()
	wall_mat.albedo_texture = TextureGen.wall_side(true)

	# Collect all wall block positions
	var positions: Array[Vector3] = []
	for tz in range(WorldMap.MAP_HEIGHT):
		for tx in range(WorldMap.MAP_WIDTH):
			var tile := world_map.get_tile(tx, tz)
			if tile == WorldMap.TILE_WALL:
				var h := world_map.get_height(tx, tz)
				for level in range(h):
					positions.append(Vector3(
						tx * IsoConst.TILE_SIZE + IsoConst.TILE_SIZE * 0.5,
						level * WALL_FACE_H + WALL_FACE_H * 0.5,
						tz * IsoConst.TILE_SIZE + IsoConst.TILE_SIZE * 0.5
					))

	if positions.is_empty():
		return

	# Render all walls with a single MultiMeshInstance3D
	var box_mesh := BoxMesh.new()
	box_mesh.size = Vector3(IsoConst.TILE_SIZE, WALL_FACE_H, IsoConst.TILE_SIZE)

	var mm := MultiMesh.new()
	mm.mesh = box_mesh
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.instance_count = positions.size()

	for i in positions.size():
		mm.set_instance_transform(i, Transform3D(Basis.IDENTITY, positions[i]))

	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = wall_mat
	_wall_meshes.add_child(mmi)

	# Single merged collision body for all walls
	var wall_body := StaticBody3D.new()
	wall_body.name = "WallCollision"
	wall_body.collision_layer = 4
	wall_body.collision_mask  = 0

	for pos in positions:
		var col := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = box_mesh.size
		col.shape = shape
		col.position = pos
		wall_body.add_child(col)

	_wall_meshes.add_child(wall_body)

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
	_player.position = Vector3(px, get_terrain_height(px, pz) + 0.5, pz)
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
	return _PlayerScene.instantiate()

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
	var node: Node3D = _EnemyScene.instantiate()
	var ey: float = get_terrain_height(float(e_data["x"]), float(e_data["z"])) + 0.5
	node.position = Vector3(e_data["x"], ey, e_data["z"])
	if node.has_method("init_from_data"):
		node.init_from_data(e_data)
	if node.has_method("set_player") and _player:
		node.set_player(_player)
	_entity_root.add_child(node)
	_enemy_nodes[e_data["id"]] = node

func _spawn_chest(c_data: Dictionary) -> void:
	var node: Node3D = _ChestScene.instantiate()
	var cy: float = get_terrain_height(float(c_data["x"]), float(c_data["z"])) + 0.25
	node.position = Vector3(c_data["x"], cy, c_data["z"])
	if node.has_method("init_from_data"):
		node.init_from_data(c_data)
	_entity_root.add_child(node)
	_chest_nodes[c_data["id"]] = node

func _spawn_door(d_data: Dictionary) -> void:
	var node: Node3D = _DoorScene.instantiate()
	var dy: float = get_terrain_height(float(d_data["x"]), float(d_data["z"])) + 0.75
	node.position = Vector3(d_data["x"], dy, d_data["z"])
	if node.has_method("init_from_data"):
		node.init_from_data(d_data)
	_entity_root.add_child(node)
	_door_nodes[d_data["id"]] = node

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
		# Drain build queue at a fixed rate to avoid per-frame spikes
		for _i in range(CHUNKS_PER_FRAME):
			if _chunk_build_queue.is_empty():
				break
			var key: Vector2i = _chunk_build_queue.pop_front()
			_build_chunk_at(key)

	# Only update save position when player moves > 1 unit (not every frame)
	var cur_pos := Vector2(_player.position.x, _player.position.z)
	if cur_pos.distance_squared_to(_last_save_pos) > 1.0:
		_last_save_pos = cur_pos
		var save_map: String = "infinite" if infinite else map_name
		SaveManager.update_position(save_map, _player.position.x, _player.position.z)

	# Throttle interaction checks — no need to scan every frame
	_interact_timer += delta
	if _interact_timer >= INTERACT_INTERVAL:
		_interact_timer = 0.0
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

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("inventory"):
		GameBus.inventory_requested.emit()
		get_viewport().set_input_as_handled()

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
