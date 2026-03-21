extends Node3D

const TextureGen = preload("res://game_logic/TextureGen.gd")
const GrassBlades = preload("res://scenes/world/GrassBlades.gd")

const TERRAIN_VDENSITY: int = 2
const WALL_FACE_H:      float = 0.625
const PLATEAU_H:        float = 1.0   # height of hill plateau boxes

var _chunk_data: RefCounted   # ChunkData
var _chunk_key:  Vector2i
var _terrain_mat: ShaderMaterial

# Build all 3D content for this chunk.
# world_scene is the parent WorldScene node — needed for cross-chunk tile lookups
# and to parent entities to the global entity root.
func build(chunk_data: RefCounted, chunk_key: Vector2i, world_scene: Node3D, terrain_mat: ShaderMaterial) -> void:
	_chunk_data  = chunk_data
	_chunk_key   = chunk_key
	_terrain_mat = terrain_mat

	position = chunk_data.origin_world()

	_build_terrain()
	_build_hills()
	_build_walls()
	_build_grass(world_scene)
	_spawn_entities(world_scene)

func teardown() -> void:
	queue_free()

# ── Terrain ────────────────────────────────────────────────────────────────
# Terrain is always flat at y=0. Hills are separate plateau boxes (see _build_hills).

func _build_terrain() -> void:
	const CHUNK_SIZE: int = 16
	var nvx: int = CHUNK_SIZE * TERRAIN_VDENSITY + 1
	var nvz: int = CHUNK_SIZE * TERRAIN_VDENSITY + 1
	var step: float = IsoConst.TILE_SIZE / float(TERRAIN_VDENSITY)
	var total_verts: int = nvx * nvz

	var verts   := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs     := PackedVector2Array()
	var colors  := PackedColorArray()
	var indices := PackedInt32Array()

	verts.resize(total_verts)
	normals.resize(total_verts)
	uvs.resize(total_verts)
	colors.resize(total_verts)
	indices.resize((nvx - 1) * (nvz - 1) * 6)

	for iz in range(nvz):
		for ix in range(nvx):
			var i: int = iz * nvx + ix
			var x: float = ix * step
			var z: float = iz * step
			verts[i]   = Vector3(x, 0.0, z)
			normals[i] = Vector3(0.0, 1.0, 0.0)
			uvs[i]     = Vector2(x, z)
			colors[i]  = Color(0.0, 0.0, 0.0, 1.0)  # blend=0 → pure grass texture

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
	mi.material_override = _terrain_mat
	add_child(mi)

	# Flat floor collision for the whole chunk
	var chunk_world: float = IsoConst.CHUNK_SIZE * IsoConst.TILE_SIZE
	var box := BoxShape3D.new()
	box.size = Vector3(chunk_world, 0.1, chunk_world)
	var col := CollisionShape3D.new()
	col.shape = box
	var body := StaticBody3D.new()
	body.name = "TerrainCollision"
	body.position = Vector3(chunk_world * 0.5, -0.05, chunk_world * 0.5)
	body.add_child(col)
	add_child(body)

# ── Hills (plateau boxes) ──────────────────────────────────────────────────

func _build_hills() -> void:
	const CHUNK_SIZE: int = 16
	var hill_mat := StandardMaterial3D.new()
	hill_mat.albedo_texture = TextureGen.hill_top()

	for lz in range(CHUNK_SIZE):
		for lx in range(CHUNK_SIZE):
			if _chunk_data.get_tile(lx, lz) != IsoConst.TILE_HILL:
				continue
			var sb := StaticBody3D.new()
			var mi := MeshInstance3D.new()
			var box := BoxMesh.new()
			box.size = Vector3(IsoConst.TILE_SIZE, PLATEAU_H, IsoConst.TILE_SIZE)
			mi.mesh = box
			mi.material_override = hill_mat
			var col := CollisionShape3D.new()
			col.shape = BoxShape3D.new()
			col.shape.size = box.size
			sb.add_child(mi)
			sb.add_child(col)
			sb.position = Vector3(
				float(lx) * IsoConst.TILE_SIZE + IsoConst.TILE_SIZE * 0.5,
				PLATEAU_H * 0.5,
				float(lz) * IsoConst.TILE_SIZE + IsoConst.TILE_SIZE * 0.5
			)
			add_child(sb)

# ── Walls ──────────────────────────────────────────────────────────────────

func _build_walls() -> void:
	const CHUNK_SIZE: int = 16
	var wall_mat := StandardMaterial3D.new()
	wall_mat.albedo_texture = TextureGen.wall_side(true)
	var chunk_origin: Vector3 = _chunk_data.origin_world()

	for lz in range(CHUNK_SIZE):
		for lx in range(CHUNK_SIZE):
			if _chunk_data.get_tile(lx, lz) != IsoConst.TILE_WALL:
				continue
			var h: int = _chunk_data.get_height(lx, lz)
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
				# Position is relative to this node's origin (which is set to chunk_origin)
				sb.position = Vector3(
					float(lx) * IsoConst.TILE_SIZE + IsoConst.TILE_SIZE * 0.5,
					float(level) * WALL_FACE_H + WALL_FACE_H * 0.5,
					float(lz) * IsoConst.TILE_SIZE + IsoConst.TILE_SIZE * 0.5
				)
				add_child(sb)

# ── Grass ──────────────────────────────────────────────────────────────────

func _build_grass(world_scene: Node3D) -> void:
	const CHUNK_SIZE: int = 16
	var grass: GrassBlades = world_scene.get_node_or_null("GrassBlades") as GrassBlades
	if not grass:
		return

	var centres: Array[Vector2] = []
	for lz in range(CHUNK_SIZE):
		for lx in range(CHUNK_SIZE):
			if _chunk_data.get_tile(lx, lz) != IsoConst.TILE_GRASS:
				continue
			var adj_wall := false
			for nb in [Vector2i(lx+1, lz), Vector2i(lx-1, lz), Vector2i(lx, lz+1), Vector2i(lx, lz-1)]:
				if _chunk_data.get_tile(nb.x, nb.y) == IsoConst.TILE_WALL:
					adj_wall = true
					break
			if adj_wall:
				continue
			var chunk_origin: Vector3 = _chunk_data.origin_world()
			centres.append(Vector2(
				chunk_origin.x + float(lx) * IsoConst.TILE_SIZE + IsoConst.TILE_SIZE * 0.5,
				chunk_origin.z + float(lz) * IsoConst.TILE_SIZE + IsoConst.TILE_SIZE * 0.5
			))

	grass.build_chunk(centres, _chunk_key)

# ── Entities ───────────────────────────────────────────────────────────────

func _spawn_entities(world_scene: Node3D) -> void:
	var entity_root: Node3D = world_scene.get_node_or_null("Entities") as Node3D
	if not entity_root:
		return

	for e_data in _chunk_data.enemies:
		var eid: String = str(e_data.get("id", ""))
		if SaveManager.is_enemy_defeated(eid):
			continue
		_spawn_enemy(e_data, entity_root, world_scene)

	for c_data in _chunk_data.chests:
		var cid: String = str(c_data.get("id", ""))
		if SaveManager.is_chest_opened(cid):
			c_data["opened"] = true
		_spawn_chest(c_data, entity_root, world_scene)

func _spawn_enemy(e_data: Dictionary, entity_root: Node3D, world_scene: Node3D) -> void:
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
	entity_root.add_child(node)
	if world_scene.has_method("register_enemy"):
		world_scene.register_enemy(e_data["id"], node)

func _spawn_chest(c_data: Dictionary, entity_root: Node3D, world_scene: Node3D) -> void:
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
	entity_root.add_child(node)
	if world_scene.has_method("register_chest"):
		world_scene.register_chest(c_data["id"], node, c_data)

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
