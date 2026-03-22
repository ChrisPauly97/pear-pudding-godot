extends Node3D

const _TexWallLeft:  Texture2D = preload("res://assets/textures/wall_side_left.png")
const _TexWallRight: Texture2D = preload("res://assets/textures/wall_side_right.png")
const _TexWallTop:   Texture2D = preload("res://assets/textures/wall_top.png")
const GrassBlades = preload("res://scenes/world/GrassBlades.gd")

# Preload entity scenes once, not per-spawn
const _EnemyScene = preload("res://scenes/world/entities/EnemyNPC.tscn")
const _ChestScene = preload("res://scenes/world/entities/Chest.tscn")

const TERRAIN_VDENSITY: int = 2
const WALL_LEVEL_H:     float = 1.0   # world-unit height per wall level
const PLATEAU_H:        float = 1.5   # hill plateau height above ground
const CURVE_R:          float = 3.0   # smoothstep transition radius (world units)

# Tile neighbourhood radius used when building the tile_grid snapshot.
# Must match what WorldScene._snapshot_tile_grid_for() uses.
const TILE_CHECK: int = 3  # ceil(CURVE_R / TILE_SIZE) + 1

# Shared across all chunks — created once on first use
# left = south (+Z) face, right = east (+X) face — the only two sides visible
# to the isometric camera which always looks from the (+X,+Y,+Z) direction.
static var _wall_left_mat:  StandardMaterial3D
static var _wall_right_mat: StandardMaterial3D
static var _wall_top_mat:   StandardMaterial3D

var _chunk_data: RefCounted   # ChunkData
var _chunk_key:  Vector2i
var _terrain_mat: ShaderMaterial
var _terrain_hmap: HeightMapShape3D   # stored for deferred physics
var _terrain_chunk_world: float       # stored for deferred physics
var _physics_built: bool = false      # guard against double-build

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
	var inv_curve_r: float = 1.0 / CURVE_R

	# Build height field — uses squared distances throughout the inner loop;
	# a single sqrt per vertex replaces the previous sqrt-per-neighbour.
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
			# Only one sqrt per vertex (was previously inside inner loop via smoothstep)
			if min_dist_sq >= curve_r_sq:
				hfield[iz * nvx + ix] = 0.0
			else:
				var t: float = 1.0 - sqrt(min_dist_sq) * inv_curve_r
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

	# Also build wall mesh arrays on this worker thread (avoids main-thread ArrayMesh work)
	var wall_mesh: ArrayMesh = _prepare_wall_mesh(chunk_data)

	return {
		"mesh":        terrain_mesh,
		"hmap":        hmap,
		"chunk_world": float(CHUNK_SIZE) * IsoConst.TILE_SIZE,
		"wall_mesh":   wall_mesh,
	}

# Build the wall ArrayMesh on a worker thread. Returns null if no walls.
static func _prepare_wall_mesh(chunk_data: RefCounted) -> ArrayMesh:
	const CHUNK_SIZE: int = 16
	var lv := PackedVector3Array()
	var ln := PackedVector3Array()
	var lu := PackedVector2Array()
	var li := PackedInt32Array()
	var rv := PackedVector3Array()
	var rn := PackedVector3Array()
	var ru := PackedVector2Array()
	var ri := PackedInt32Array()
	var tv := PackedVector3Array()
	var tn := PackedVector3Array()
	var tu := PackedVector2Array()
	var ti := PackedInt32Array()

	for lz in range(CHUNK_SIZE):
		for lx in range(CHUNK_SIZE):
			if chunk_data.get_tile(lx, lz) != IsoConst.TILE_WALL:
				continue
			var h: int = max(1, chunk_data.get_height(lx, lz))
			var fh: float = float(h)
			var top_y: float = fh * WALL_LEVEL_H
			var x0: float = float(lx) * IsoConst.TILE_SIZE
			var x1: float = x0 + IsoConst.TILE_SIZE
			var z0: float = float(lz) * IsoConst.TILE_SIZE
			var z1: float = z0 + IsoConst.TILE_SIZE
			var tbase: int = tv.size()
			tv.append_array([
				Vector3(x0, top_y, z0), Vector3(x1, top_y, z0),
				Vector3(x1, top_y, z1), Vector3(x0, top_y, z1)
			])
			tn.append_array([Vector3.UP, Vector3.UP, Vector3.UP, Vector3.UP])
			tu.append_array([Vector2(0.0, 0.0), Vector2(1.0, 0.0), Vector2(1.0, 1.0), Vector2(0.0, 1.0)])
			ti.append_array([tbase, tbase + 1, tbase + 2, tbase, tbase + 2, tbase + 3])
			var nb_h_s: int = 0
			if chunk_data.get_tile(lx, lz + 1) == IsoConst.TILE_WALL:
				nb_h_s = max(1, chunk_data.get_height(lx, lz + 1))
			if nb_h_s < h:
				var bot_s: float = float(nb_h_s) * WALL_LEVEL_H
				_add_wall_side(lv, ln, lu, li,
					Vector3(x0, bot_s, z1), Vector3(x1, bot_s, z1),
					Vector3(x1, top_y, z1), Vector3(x0, top_y, z1),
					Vector3(0.0, 0.0, 1.0), float(h - nb_h_s))
			var nb_h_e: int = 0
			if chunk_data.get_tile(lx + 1, lz) == IsoConst.TILE_WALL:
				nb_h_e = max(1, chunk_data.get_height(lx + 1, lz))
			if nb_h_e < h:
				var bot_e: float = float(nb_h_e) * WALL_LEVEL_H
				_add_wall_side(rv, rn, ru, ri,
					Vector3(x1, bot_e, z1), Vector3(x1, bot_e, z0),
					Vector3(x1, top_y, z0), Vector3(x1, top_y, z1),
					Vector3(1.0, 0.0, 0.0), float(h - nb_h_e))

	if lv.is_empty() and rv.is_empty() and tv.is_empty():
		return null

	var mesh := ArrayMesh.new()
	# Track which surfaces are present so the main thread assigns correct materials
	var surface_types: Array[int] = []  # 0=left, 1=right, 2=top
	if not lv.is_empty():
		var arr: Array = []
		arr.resize(Mesh.ARRAY_MAX)
		arr[Mesh.ARRAY_VERTEX] = lv
		arr[Mesh.ARRAY_NORMAL] = ln
		arr[Mesh.ARRAY_TEX_UV] = lu
		arr[Mesh.ARRAY_INDEX]  = li
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
		surface_types.append(0)
	if not rv.is_empty():
		var arr: Array = []
		arr.resize(Mesh.ARRAY_MAX)
		arr[Mesh.ARRAY_VERTEX] = rv
		arr[Mesh.ARRAY_NORMAL] = rn
		arr[Mesh.ARRAY_TEX_UV] = ru
		arr[Mesh.ARRAY_INDEX]  = ri
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
		surface_types.append(1)
	if not tv.is_empty():
		var arr: Array = []
		arr.resize(Mesh.ARRAY_MAX)
		arr[Mesh.ARRAY_VERTEX] = tv
		arr[Mesh.ARRAY_NORMAL] = tn
		arr[Mesh.ARRAY_TEX_UV] = tu
		arr[Mesh.ARRAY_INDEX]  = ti
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
		surface_types.append(2)
	mesh.set_meta("surface_types", surface_types)
	return mesh

# ── Main entry point (main thread only) ───────────────────────────────────
# Phase 1: visual mesh + entities only — no physics bodies — call from _commit_chunk_results.
func build_visual(chunk_data: RefCounted, chunk_key: Vector2i, world_scene: Node3D,
		terrain_mat: ShaderMaterial, terrain_res: Dictionary) -> void:
	_chunk_data          = chunk_data
	_chunk_key           = chunk_key
	_terrain_mat         = terrain_mat
	_terrain_hmap        = terrain_res["hmap"]
	_terrain_chunk_world = terrain_res["chunk_world"]
	position = chunk_data.origin_world()

	_apply_terrain_visual(terrain_res)
	_apply_wall_visual(terrain_res.get("wall_mesh"))
	_build_grass(world_scene)
	_spawn_entities(world_scene)

# Phase 2: physics bodies only — deferred one frame after build_visual.
func build_physics() -> void:
	if _physics_built:
		return
	_physics_built = true
	_apply_terrain_physics()
	_build_walls_physics()

# Convenience wrapper for synchronous builds (startup path only).
func build(chunk_data: RefCounted, chunk_key: Vector2i, world_scene: Node3D,
		terrain_mat: ShaderMaterial, terrain_res: Dictionary) -> void:
	build_visual(chunk_data, chunk_key, world_scene, terrain_mat, terrain_res)
	build_physics()

func teardown() -> void:
	queue_free()

# ── Terrain node creation (main thread) ───────────────────────────────────
func _apply_terrain_visual(res: Dictionary) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = res["mesh"]
	mi.material_override = _terrain_mat
	add_child(mi)

func _apply_terrain_physics() -> void:
	var col_node := CollisionShape3D.new()
	col_node.shape = _terrain_hmap
	var body := StaticBody3D.new()
	body.name = "TerrainCollision"
	body.collision_layer = 2
	body.collision_mask  = 0
	body.position = Vector3(_terrain_chunk_world * 0.5, 0.0, _terrain_chunk_world * 0.5)
	body.add_child(col_node)
	add_child(body)

# ── Walls ──────────────────────────────────────────────────────────────────

static func _ensure_wall_resources() -> void:
	if _wall_left_mat == null:
		_wall_left_mat = StandardMaterial3D.new()
		_wall_left_mat.albedo_texture = _TexWallLeft
		_wall_left_mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		_wall_left_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	if _wall_right_mat == null:
		_wall_right_mat = StandardMaterial3D.new()
		_wall_right_mat.albedo_texture = _TexWallRight
		_wall_right_mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		_wall_right_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	if _wall_top_mat == null:
		_wall_top_mat = StandardMaterial3D.new()
		_wall_top_mat.albedo_texture = _TexWallTop
		_wall_top_mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		_wall_top_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED

# Build one quad (2 triangles) for a wall side face.
# Vertices in order: bl (bottom-left), br (bottom-right), tr (top-right), tl (top-left)
# viewed from outside the wall.  The normal must be pre-validated as outward-facing.
# UV: u 0→1 horizontal, v h→0 vertical so the texture tiles h times from bottom to top.
static func _add_wall_side(
		verts: PackedVector3Array, normals: PackedVector3Array,
		uvs: PackedVector2Array, indices: PackedInt32Array,
		bl: Vector3, br: Vector3, tr: Vector3, tl: Vector3,
		normal: Vector3, h: float) -> void:
	var i: int = verts.size()
	verts.append_array([bl, br, tr, tl])
	normals.append_array([normal, normal, normal, normal])
	uvs.append_array([Vector2(0.0, h), Vector2(1.0, h), Vector2(1.0, 0.0), Vector2(0.0, 0.0)])
	indices.append_array([i, i + 1, i + 2, i, i + 2, i + 3])

# Attach the pre-built wall mesh (built on worker thread in _prepare_wall_mesh).
# Main thread only creates a MeshInstance3D and assigns materials — no array work.
func _apply_wall_visual(wall_mesh: ArrayMesh) -> void:
	if wall_mesh == null:
		return
	_ensure_wall_resources()
	var mi := MeshInstance3D.new()
	mi.mesh = wall_mesh
	var wall_mats: Array[StandardMaterial3D] = [_wall_left_mat, _wall_right_mat, _wall_top_mat]
	var surface_types: Array = wall_mesh.get_meta("surface_types", [])
	for surf in range(surface_types.size()):
		var st: int = surface_types[surf]
		mi.set_surface_override_material(surf, wall_mats[st])
	add_child(mi)

func _build_walls_physics() -> void:
	# Greedy row merge: instead of one BoxShape3D per wall tile, merge consecutive
	# wall tiles in the same row with the same height into a single wider box.
	# Typical reduction: 50 individual shapes → 10-15 merged shapes per chunk.
	const CHUNK_SIZE: int = 16
	var wall_body := StaticBody3D.new()
	wall_body.name = "WallCollision"
	wall_body.collision_layer = 4
	wall_body.collision_mask  = 0

	for lz in range(CHUNK_SIZE):
		var run_start: int = -1
		var run_h: int = 0
		for lx in range(CHUNK_SIZE + 1):  # +1 to flush final run
			var is_wall: bool = lx < CHUNK_SIZE and _chunk_data.get_tile(lx, lz) == IsoConst.TILE_WALL
			var h: int = max(1, _chunk_data.get_height(lx, lz)) if is_wall else 0
			if is_wall and (run_start < 0 or h == run_h):
				if run_start < 0:
					run_start = lx
					run_h = h
			else:
				# Flush current run
				if run_start >= 0:
					var run_len: int = lx - run_start
					var top_y: float = float(run_h) * WALL_LEVEL_H
					var x0: float = float(run_start) * IsoConst.TILE_SIZE
					var width: float = float(run_len) * IsoConst.TILE_SIZE
					var z0: float = float(lz) * IsoConst.TILE_SIZE
					var col := CollisionShape3D.new()
					var box := BoxShape3D.new()
					box.size = Vector3(width, top_y, IsoConst.TILE_SIZE)
					col.shape = box
					col.position = Vector3(x0 + width * 0.5, top_y * 0.5, z0 + IsoConst.TILE_SIZE * 0.5)
					wall_body.add_child(col)
				# Start new run if current tile is a wall
				if is_wall:
					run_start = lx
					run_h = h
				else:
					run_start = -1

	if wall_body.get_child_count() > 0:
		add_child(wall_body)

# ── Grass ──────────────────────────────────────────────────────────────────

func _build_grass(world_scene: Node3D) -> void:
	const CHUNK_SIZE: int = 16
	var grass: GrassBlades = world_scene.get_node_or_null("GrassBlades") as GrassBlades
	if not grass:
		return

	var chunk_origin: Vector3 = _chunk_data.origin_world()
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
	# Check direct children first (most entity scenes have MeshInstance3D as immediate child)
	for child in node.get_children():
		var mi: MeshInstance3D = child as MeshInstance3D
		if mi:
			mi.visibility_range_end = ENTITY_VISIBILITY_END
			mi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_DISABLED
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
			return
	# Fallback: check grandchildren (one level deeper only)
	for child in node.get_children():
		for grandchild in child.get_children():
			var mi: MeshInstance3D = grandchild as MeshInstance3D
			if mi:
				mi.visibility_range_end = ENTITY_VISIBILITY_END
				mi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_DISABLED
				mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
				return

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
