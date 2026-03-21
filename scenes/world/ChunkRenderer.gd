extends Node3D

const TextureGen = preload("res://game_logic/TextureGen.gd")
const GrassBlades = preload("res://scenes/world/GrassBlades.gd")

const TERRAIN_VDENSITY: int = 2
const WALL_FACE_H:      float = 0.625
const PLATEAU_H:        float = 1.5   # hill plateau height above ground
const CURVE_R:          float = 3.0   # smoothstep transition radius (world units)

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

	_build_terrain(world_scene)
	_build_walls()
	_build_grass(world_scene)
	_spawn_entities(world_scene)

func teardown() -> void:
	queue_free()

# ── Terrain ────────────────────────────────────────────────────────────────
# Each vertex height is driven by distance to the nearest HILL tile.
# h = PLATEAU_H fully inside a hill patch, 0 on flat grass, smoothstep between.
# TERRAIN_VDENSITY=2 with TILE_SIZE=2 gives step=1.0, so HeightMapShape3D needs
# no scaling — vertices are already 1 world unit apart.

func _build_terrain(world_scene: Node3D) -> void:
	const CHUNK_SIZE: int = 16
	var nvx: int = CHUNK_SIZE * TERRAIN_VDENSITY + 1   # 33
	var nvz: int = CHUNK_SIZE * TERRAIN_VDENSITY + 1   # 33
	var step: float = IsoConst.TILE_SIZE / float(TERRAIN_VDENSITY)  # 1.0

	# Build height field
	var hfield := PackedFloat32Array()
	hfield.resize(nvx * nvz)
	var chunk_origin: Vector3 = _chunk_data.origin_world()
	var tile_check: int = int(ceil(CURVE_R / IsoConst.TILE_SIZE)) + 1  # 3

	for iz in range(nvz):
		for ix in range(nvx):
			var gx: float = chunk_origin.x + ix * step
			var gz: float = chunk_origin.z + iz * step
			var vtx: int = int(gx / IsoConst.TILE_SIZE)
			var vtz: int = int(gz / IsoConst.TILE_SIZE)
			var min_dist: float = CURVE_R  # beyond transition = h stays 0
			for dtz in range(-tile_check, tile_check + 1):
				for dtx in range(-tile_check, tile_check + 1):
					var ttx: int = vtx + dtx
					var ttz: int = vtz + dtz
					if world_scene.get_tile_global(ttx, ttz) != IsoConst.TILE_HILL:
						continue
					# Nearest point on this hill tile to the vertex
					var near_x: float = clamp(gx, float(ttx) * IsoConst.TILE_SIZE, float(ttx + 1) * IsoConst.TILE_SIZE)
					var near_z: float = clamp(gz, float(ttz) * IsoConst.TILE_SIZE, float(ttz + 1) * IsoConst.TILE_SIZE)
					var dist: float = sqrt((gx - near_x) * (gx - near_x) + (gz - near_z) * (gz - near_z))
					if dist < min_dist:
						min_dist = dist
			var t: float = 1.0 - min_dist / CURVE_R
			t = t * t * (3.0 - 2.0 * t)  # smoothstep
			hfield[iz * nvx + ix] = PLATEAU_H * t

	# Build terrain mesh from height field
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
			var h: float = hfield[i]
			verts[i] = Vector3(x, h, z)
			uvs[i]   = Vector2(x, z)
			var blend: float = clamp(h / PLATEAU_H, 0.0, 1.0)
			colors[i] = Color(blend, blend, blend, 1.0)

	# Normals via finite differences
	for iz in range(nvz):
		for ix in range(nvx):
			var i: int = iz * nvx + ix
			var hL: float = hfield[iz * nvx + max(ix - 1, 0)]
			var hR: float = hfield[iz * nvx + min(ix + 1, nvx - 1)]
			var hD: float = hfield[max(iz - 1, 0) * nvx + ix]
			var hU: float = hfield[min(iz + 1, nvz - 1) * nvx + ix]
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
	mi.material_override = _terrain_mat
	add_child(mi)

	# HeightMapShape3D — step=1.0, no scale needed, body centered over the chunk
	var col_shape := HeightMapShape3D.new()
	col_shape.map_width = nvx
	col_shape.map_depth = nvz
	col_shape.map_data  = hfield
	var col_node := CollisionShape3D.new()
	col_node.shape = col_shape
	var body := StaticBody3D.new()
	body.name = "TerrainCollision"
	body.collision_layer = 2   # terrain layer
	body.collision_mask  = 0   # terrain doesn't need to detect others
	body.position = Vector3(float(nvx - 1) * step * 0.5, 0.0, float(nvz - 1) * step * 0.5)
	body.add_child(col_node)
	add_child(body)

	# HeightMapShape3D already covers the terrain — no fallback floor needed.

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
				sb.collision_layer = 4   # wall layer
				sb.collision_mask  = 0   # walls don't need to detect others
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
