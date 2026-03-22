extends Node3D

const TextureGen = preload("res://game_logic/TextureGen.gd")
const GrassBlades = preload("res://scenes/world/GrassBlades.gd")

# Preload entity scenes once, not per-spawn
const _EnemyScene = preload("res://scenes/world/entities/EnemyNPC.tscn")
const _ChestScene = preload("res://scenes/world/entities/Chest.tscn")

const TERRAIN_VDENSITY: int = 2
const WALL_FACE_H:      float = 0.625
const PLATEAU_H:        float = 1.5   # hill plateau height above ground
const CURVE_R:          float = 3.0   # smoothstep transition radius (world units)

# Tile neighbourhood radius used when building the tile_grid snapshot.
# Must match what WorldScene._snapshot_tile_grid_for() uses.
const TILE_CHECK: int = 3  # ceil(CURVE_R / TILE_SIZE) + 1

# Shared across all chunks — created once on first use
static var _wall_mat: StandardMaterial3D
static var _wall_box_shape: BoxShape3D
static var _wall_box_mesh: BoxMesh

var _chunk_data: RefCounted   # ChunkData
var _chunk_key:  Vector2i
var _terrain_mat: ShaderMaterial

# ── Thread-safe terrain prep ───────────────────────────────────────────────
# Call this from a worker thread. Receives a pre-snapshotted tile_grid so it
# never touches the scene tree or WorldScene state.
# Returns a Dictionary consumed by build() to create the actual nodes.
static func prepare_terrain(
		chunk_data: RefCounted,
		tile_grid: PackedInt32Array,
		grid_min_x: int, grid_min_z: int, grid_w: int) -> Dictionary:

	const CHUNK_SIZE: int = 16
	var nvx: int = CHUNK_SIZE * TERRAIN_VDENSITY + 1   # 33
	var nvz: int = CHUNK_SIZE * TERRAIN_VDENSITY + 1   # 33
	var step: float = IsoConst.TILE_SIZE / float(TERRAIN_VDENSITY)  # 1.0

	var chunk_origin: Vector3 = chunk_data.origin_world()
	var curve_r_sq: float = CURVE_R * CURVE_R

	# Build height field
	var hfield := PackedFloat32Array()
	hfield.resize(nvx * nvz)
	for iz in range(nvz):
		for ix in range(nvx):
			var gx: float = chunk_origin.x + ix * step
			var gz: float = chunk_origin.z + iz * step
			var vtx: int = int(gx / IsoConst.TILE_SIZE)
			var vtz: int = int(gz / IsoConst.TILE_SIZE)
			var min_dist_sq: float = curve_r_sq
			for dtz in range(-TILE_CHECK, TILE_CHECK + 1):
				for dtx in range(-TILE_CHECK, TILE_CHECK + 1):
					var ttx: int = vtx + dtx
					var ttz: int = vtz + dtz
					var li: int = (ttz - grid_min_z) * grid_w + (ttx - grid_min_x)
					if li < 0 or li >= tile_grid.size() or tile_grid[li] != IsoConst.TILE_HILL:
						continue
					var near_x: float = clamp(gx, float(ttx) * IsoConst.TILE_SIZE, float(ttx + 1) * IsoConst.TILE_SIZE)
					var near_z: float = clamp(gz, float(ttz) * IsoConst.TILE_SIZE, float(ttz + 1) * IsoConst.TILE_SIZE)
					var ddx: float = gx - near_x
					var ddz: float = gz - near_z
					var dist_sq: float = ddx * ddx + ddz * ddz
					if dist_sq < min_dist_sq:
						min_dist_sq = dist_sq
			var t: float = 1.0 - sqrt(min_dist_sq) / CURVE_R
			t = t * t * (3.0 - 2.0 * t)
			hfield[iz * nvx + ix] = PLATEAU_H * t

	# Build terrain mesh arrays
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
			var tx: int = int((chunk_origin.x + x) / IsoConst.TILE_SIZE)
			var tz: int = int((chunk_origin.z + z) / IsoConst.TILE_SIZE)
			var li: int = (tz - grid_min_z) * grid_w + (tx - grid_min_x)
			var is_wall: float = 1.0 if (li >= 0 and li < tile_grid.size() and tile_grid[li] == IsoConst.TILE_WALL) else 0.0
			colors[i] = Color(blend, is_wall, 0.0, 1.0)

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

	# Edge skirts
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
	for ix in range(nvx):
		for iz_edge in [0, nvz - 1]:
			var surf_i: int = iz_edge * nvx + ix
			skirt_verts[si]   = Vector3(verts[surf_i].x, SKIRT_Y, verts[surf_i].z)
			skirt_normals[si] = normals[surf_i]
			skirt_uvs[si]     = uvs[surf_i]
			skirt_colors[si]  = colors[surf_i]
			_edge_ids.append(surf_i)
			_edge_ids.append(si)
			si += 1
	for iz in range(1, nvz - 1):
		for ix_edge in [0, nvx - 1]:
			var surf_i: int = iz * nvx + ix_edge
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
	for ix in range(nvx - 1):
		var a: int = ix;            var b: int = ix + 1
		var sa: int = total_verts + int(skirt_map[a])
		var sb: int = total_verts + int(skirt_map[b])
		skirt_indices[sidx] = a;  skirt_indices[sidx+1] = sa; skirt_indices[sidx+2] = b
		skirt_indices[sidx+3] = b; skirt_indices[sidx+4] = sa; skirt_indices[sidx+5] = sb
		sidx += 6
	for ix in range(nvx - 1):
		var a: int = (nvz - 1) * nvx + ix;  var b: int = (nvz - 1) * nvx + ix + 1
		var sa: int = total_verts + int(skirt_map[a])
		var sb: int = total_verts + int(skirt_map[b])
		skirt_indices[sidx] = a;  skirt_indices[sidx+1] = b;  skirt_indices[sidx+2] = sa
		skirt_indices[sidx+3] = b; skirt_indices[sidx+4] = sb; skirt_indices[sidx+5] = sa
		sidx += 6
	for iz in range(nvz - 1):
		var a: int = iz * nvx;           var b: int = (iz + 1) * nvx
		var sa: int = total_verts + int(skirt_map[a])
		var sb: int = total_verts + int(skirt_map[b])
		skirt_indices[sidx] = a;  skirt_indices[sidx+1] = b;  skirt_indices[sidx+2] = sa
		skirt_indices[sidx+3] = b; skirt_indices[sidx+4] = sb; skirt_indices[sidx+5] = sa
		sidx += 6
	for iz in range(nvz - 1):
		var a: int = iz * nvx + nvx - 1; var b: int = (iz + 1) * nvx + nvx - 1
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

	var hmap := HeightMapShape3D.new()
	hmap.map_width = nvx
	hmap.map_depth = nvz
	hmap.map_data  = hfield

	return {
		"mesh":        terrain_mesh,
		"hmap":        hmap,
		"chunk_world": float(CHUNK_SIZE) * IsoConst.TILE_SIZE,
	}

# ── Main entry point (main thread only) ───────────────────────────────────
# terrain_res: pre-built by prepare_terrain(), possibly on a worker thread.
func build(chunk_data: RefCounted, chunk_key: Vector2i, world_scene: Node3D,
		terrain_mat: ShaderMaterial, terrain_res: Dictionary) -> void:
	_chunk_data  = chunk_data
	_chunk_key   = chunk_key
	_terrain_mat = terrain_mat
	position = chunk_data.origin_world()

	_apply_terrain(terrain_res)
	_build_walls()
	_build_grass(world_scene)
	_spawn_entities(world_scene)

func teardown() -> void:
	queue_free()

# ── Terrain node creation (main thread) ───────────────────────────────────
func _apply_terrain(res: Dictionary) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = res["mesh"]
	mi.material_override = _terrain_mat
	add_child(mi)

	var col_node := CollisionShape3D.new()
	col_node.shape = res["hmap"]
	var body := StaticBody3D.new()
	body.name = "TerrainCollision"
	body.collision_layer = 2
	body.collision_mask  = 0
	body.position = Vector3(res["chunk_world"] * 0.5, 0.0, res["chunk_world"] * 0.5)
	body.add_child(col_node)
	add_child(body)

# ── Walls ──────────────────────────────────────────────────────────────────

static func _ensure_wall_resources() -> void:
	if _wall_mat == null:
		_wall_mat = StandardMaterial3D.new()
		_wall_mat.albedo_texture = TextureGen.wall_side(true)
	if _wall_box_mesh == null:
		_wall_box_mesh = BoxMesh.new()
		_wall_box_mesh.size = Vector3(IsoConst.TILE_SIZE, WALL_FACE_H, IsoConst.TILE_SIZE)
	if _wall_box_shape == null:
		_wall_box_shape = BoxShape3D.new()
		_wall_box_shape.size = Vector3(IsoConst.TILE_SIZE, WALL_FACE_H, IsoConst.TILE_SIZE)

func _build_walls() -> void:
	const CHUNK_SIZE: int = 16
	_ensure_wall_resources()

	var positions: Array[Vector3] = []
	for lz in range(CHUNK_SIZE):
		for lx in range(CHUNK_SIZE):
			if _chunk_data.get_tile(lx, lz) != IsoConst.TILE_WALL:
				continue
			var h: int = _chunk_data.get_height(lx, lz)
			for level in range(h):
				positions.append(Vector3(
					float(lx) * IsoConst.TILE_SIZE + IsoConst.TILE_SIZE * 0.5,
					float(level) * WALL_FACE_H + WALL_FACE_H * 0.5,
					float(lz) * IsoConst.TILE_SIZE + IsoConst.TILE_SIZE * 0.5
				))

	if positions.is_empty():
		return

	var mm := MultiMesh.new()
	mm.mesh = _wall_box_mesh
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.instance_count = positions.size()
	for i in positions.size():
		mm.set_instance_transform(i, Transform3D(Basis.IDENTITY, positions[i]))

	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = _wall_mat
	add_child(mmi)

	var wall_body := StaticBody3D.new()
	wall_body.name = "WallCollision"
	wall_body.collision_layer = 4
	wall_body.collision_mask  = 0
	for pos in positions:
		var col := CollisionShape3D.new()
		col.shape = _wall_box_shape
		col.position = pos
		wall_body.add_child(col)
	add_child(wall_body)

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

const ENTITY_VISIBILITY_END: float = 50.0

func _set_visibility_range(node: Node3D) -> void:
	var mi: MeshInstance3D = node.find_child("MeshInstance3D", true, false) as MeshInstance3D
	if mi:
		mi.visibility_range_end = ENTITY_VISIBILITY_END
		mi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_DISABLED
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

func _spawn_enemy(e_data: Dictionary, entity_root: Node3D, world_scene: Node3D) -> void:
	var node: Node3D = _EnemyScene.instantiate()
	var ey: float = 0.5
	if world_scene.has_method("get_terrain_height"):
		ey += world_scene.get_terrain_height(float(e_data["x"]), float(e_data["z"]))
	node.position = Vector3(e_data["x"], ey, e_data["z"])
	if node.has_method("init_from_data"):
		node.init_from_data(e_data)
	_set_visibility_range(node)
	entity_root.add_child(node)
	if world_scene.has_method("register_enemy"):
		world_scene.register_enemy(e_data["id"], node)

func _spawn_chest(c_data: Dictionary, entity_root: Node3D, world_scene: Node3D) -> void:
	var node: Node3D = _ChestScene.instantiate()
	var cy: float = 0.25
	if world_scene.has_method("get_terrain_height"):
		cy += world_scene.get_terrain_height(float(c_data["x"]), float(c_data["z"]))
	node.position = Vector3(c_data["x"], cy, c_data["z"])
	if node.has_method("init_from_data"):
		node.init_from_data(c_data)
	_set_visibility_range(node)
	entity_root.add_child(node)
	if world_scene.has_method("register_chest"):
		world_scene.register_chest(c_data["id"], node, c_data)
