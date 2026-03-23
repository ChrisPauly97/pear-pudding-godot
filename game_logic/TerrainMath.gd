class_name TerrainMath
extends RefCounted

# Shared terrain height, mesh, and wall-mesh building used by both the
# named-map path (WorldScene) and the infinite-chunk path (ChunkRenderer).
# Eliminates the three duplicate smoothstep implementations and the two
# duplicate mesh-builder copies.

# ── Height computation ────────────────────────────────────────────────────

## Compute terrain height at world position (wx, wz) using smoothstep blend.
## tile_lookup: Callable(ttx: int, ttz: int) -> int  — returns tile type
## height_lookup: Callable(ttx: int, ttz: int) -> int — returns wall height
## curve_r: smoothstep transition radius (world units)
## peak_h: plateau height above ground
static func get_height_at(wx: float, wz: float,
		tile_lookup: Callable, height_lookup: Callable,
		curve_r: float, peak_h: float) -> float:
	var tile_check: int = int(ceil(curve_r / IsoConst.TILE_SIZE)) + 1
	var vtx: int = int(wx / IsoConst.TILE_SIZE)
	var vtz: int = int(wz / IsoConst.TILE_SIZE)
	var curve_r_sq: float = curve_r * curve_r
	var min_dist_sq: float = curve_r_sq
	for dtz in range(-tile_check, tile_check + 1):
		for dtx in range(-tile_check, tile_check + 1):
			var ttx: int = vtx + dtx
			var ttz: int = vtz + dtz
			if tile_lookup.call(ttx, ttz) != IsoConst.TILE_HILL:
				continue
			var near_x: float = clamp(wx, float(ttx) * IsoConst.TILE_SIZE, float(ttx + 1) * IsoConst.TILE_SIZE)
			var near_z: float = clamp(wz, float(ttz) * IsoConst.TILE_SIZE, float(ttz + 1) * IsoConst.TILE_SIZE)
			var ddx: float = wx - near_x
			var ddz: float = wz - near_z
			var dist_sq: float = ddx * ddx + ddz * ddz
			if dist_sq < min_dist_sq:
				min_dist_sq = dist_sq
	if min_dist_sq >= curve_r_sq:
		return 0.0
	var t: float = 1.0 - sqrt(min_dist_sq) / curve_r
	t = t * t * (3.0 - 2.0 * t)
	var base_h: float = peak_h * t

	# If standing on a wall tile, add the wall block height
	var tile_at: int = tile_lookup.call(vtx, vtz)
	if tile_at == IsoConst.TILE_WALL:
		var wh: int = height_lookup.call(vtx, vtz)
		base_h += float(maxi(1, wh)) * IsoConst.WALL_FACE_H

	return base_h

## Compute a packed height field for a grid of vertices.
## tile_lookup: Callable(ttx: int, ttz: int) -> int — returns tile type
## origin_x, origin_z: world-space origin of the grid
## nvx, nvz: vertex count in each axis
## step: world units between vertices
## curve_r, peak_h: smoothstep parameters
static func compute_height_field(
		tile_lookup: Callable,
		origin_x: float, origin_z: float,
		nvx: int, nvz: int, step: float,
		curve_r: float, peak_h: float) -> PackedFloat32Array:
	var tile_check: int = int(ceil(curve_r / IsoConst.TILE_SIZE)) + 1
	var curve_r_sq: float = curve_r * curve_r
	var inv_curve_r: float = 1.0 / curve_r

	var hfield := PackedFloat32Array()
	hfield.resize(nvx * nvz)
	for iz in range(nvz):
		for ix in range(nvx):
			var gx: float = origin_x + ix * step
			var gz: float = origin_z + iz * step
			var vtx: int = int(gx / IsoConst.TILE_SIZE)
			var vtz: int = int(gz / IsoConst.TILE_SIZE)
			var min_dist_sq: float = curve_r_sq
			for dtz in range(-tile_check, tile_check + 1):
				for dtx in range(-tile_check, tile_check + 1):
					var ttx: int = vtx + dtx
					var ttz: int = vtz + dtz
					if tile_lookup.call(ttx, ttz) != IsoConst.TILE_HILL:
						continue
					var near_x: float = clamp(gx, float(ttx) * IsoConst.TILE_SIZE, float(ttx + 1) * IsoConst.TILE_SIZE)
					var near_z: float = clamp(gz, float(ttz) * IsoConst.TILE_SIZE, float(ttz + 1) * IsoConst.TILE_SIZE)
					var ddx: float = gx - near_x
					var ddz: float = gz - near_z
					var dist_sq: float = ddx * ddx + ddz * ddz
					if dist_sq < min_dist_sq:
						min_dist_sq = dist_sq
			if min_dist_sq >= curve_r_sq:
				hfield[iz * nvx + ix] = 0.0
			else:
				var t: float = 1.0 - sqrt(min_dist_sq) * inv_curve_r
				t = t * t * (3.0 - 2.0 * t)
				hfield[iz * nvx + ix] = peak_h * t
	return hfield

# ── Terrain mesh building ─────────────────────────────────────────────────

## Build terrain ArrayMesh + HeightMapShape3D from a height field.
## tile_lookup: Callable(ttx: int, ttz: int) -> int — for wall flag in vertex color
## origin_x, origin_z: world-space origin (0 for named maps, chunk origin for chunks)
## Returns { "mesh": ArrayMesh, "hmap": HeightMapShape3D }
static func build_terrain_mesh(
		hfield: PackedFloat32Array,
		tile_lookup: Callable,
		origin_x: float, origin_z: float,
		nvx: int, nvz: int, step: float,
		peak_h: float) -> Dictionary:
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
			var blend: float = clamp(h / peak_h, 0.0, 1.0)
			var tx: int = int((origin_x + x) / IsoConst.TILE_SIZE)
			var tz: int = int((origin_z + z) / IsoConst.TILE_SIZE)
			var is_wall: float = 1.0 if tile_lookup.call(tx, tz) == IsoConst.TILE_WALL else 0.0
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

	return { "mesh": terrain_mesh, "hmap": hmap }

# ── Wall mesh building ────────────────────────────────────────────────────

## Build a quad (2 triangles) for a wall side face.
static func add_wall_side(
		verts: PackedVector3Array, normals: PackedVector3Array,
		uvs: PackedVector2Array, indices: PackedInt32Array,
		bl: Vector3, br: Vector3, tr: Vector3, tl: Vector3,
		normal: Vector3, h: float) -> void:
	var i: int = verts.size()
	verts.append_array([bl, br, tr, tl])
	normals.append_array([normal, normal, normal, normal])
	uvs.append_array([Vector2(0.0, h), Vector2(1.0, h), Vector2(1.0, 0.0), Vector2(0.0, 0.0)])
	indices.append_array([i, i + 1, i + 2, i, i + 2, i + 3])

## Build wall ArrayMesh from tile data. Returns null if no walls.
## get_tile_fn: Callable(lx: int, lz: int) -> int
## get_height_fn: Callable(lx: int, lz: int) -> int
## grid_w, grid_h: tile grid dimensions to iterate
static func build_wall_mesh(
		get_tile_fn: Callable, get_height_fn: Callable,
		grid_w: int, grid_h: int) -> ArrayMesh:
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

	for lz in range(grid_h):
		for lx in range(grid_w):
			if get_tile_fn.call(lx, lz) != IsoConst.TILE_WALL:
				continue
			var h: int = max(1, get_height_fn.call(lx, lz))
			var fh: float = float(h)
			var top_y: float = fh * IsoConst.WALL_FACE_H
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
			if get_tile_fn.call(lx, lz + 1) == IsoConst.TILE_WALL:
				nb_h_s = max(1, get_height_fn.call(lx, lz + 1))
			if nb_h_s < h:
				var bot_s: float = float(nb_h_s) * IsoConst.WALL_FACE_H
				add_wall_side(lv, ln, lu, li,
					Vector3(x0, bot_s, z1), Vector3(x1, bot_s, z1),
					Vector3(x1, top_y, z1), Vector3(x0, top_y, z1),
					Vector3(0.0, 0.0, 1.0), float(h - nb_h_s))
			var nb_h_e: int = 0
			if get_tile_fn.call(lx + 1, lz) == IsoConst.TILE_WALL:
				nb_h_e = max(1, get_height_fn.call(lx + 1, lz))
			if nb_h_e < h:
				var bot_e: float = float(nb_h_e) * IsoConst.WALL_FACE_H
				add_wall_side(rv, rn, ru, ri,
					Vector3(x1, bot_e, z1), Vector3(x1, bot_e, z0),
					Vector3(x1, top_y, z0), Vector3(x1, top_y, z1),
					Vector3(1.0, 0.0, 0.0), float(h - nb_h_e))

	if lv.is_empty() and rv.is_empty() and tv.is_empty():
		return null

	var mesh := ArrayMesh.new()
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

# ── Shared wall materials ─────────────────────────────────────────────────

static var _wall_left_mat:  StandardMaterial3D
static var _wall_right_mat: StandardMaterial3D
static var _wall_top_mat:   StandardMaterial3D

static func ensure_wall_materials(
		tex_left: Texture2D, tex_right: Texture2D, tex_top: Texture2D) -> void:
	if _wall_left_mat == null:
		_wall_left_mat = StandardMaterial3D.new()
		_wall_left_mat.albedo_texture = tex_left
		_wall_left_mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		_wall_left_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	if _wall_right_mat == null:
		_wall_right_mat = StandardMaterial3D.new()
		_wall_right_mat.albedo_texture = tex_right
		_wall_right_mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		_wall_right_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	if _wall_top_mat == null:
		_wall_top_mat = StandardMaterial3D.new()
		_wall_top_mat.albedo_texture = tex_top
		_wall_top_mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		_wall_top_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED

static func get_wall_materials() -> Array[StandardMaterial3D]:
	return [_wall_left_mat, _wall_right_mat, _wall_top_mat]

# ── Entity spawning ───────────────────────────────────────────────────────

static func spawn_entity(scene: PackedScene, data: Dictionary, y_offset: float,
		entity_root: Node3D, world_scene: Node3D) -> Node3D:
	var node: Node3D = scene.instantiate()
	var ey: float = y_offset
	if world_scene.has_method("get_terrain_height"):
		ey += world_scene.get_terrain_height(float(data["x"]), float(data["z"]))
	node.position = Vector3(data["x"], ey, data["z"])
	if node.has_method("init_from_data"):
		node.init_from_data(data)
	entity_root.add_child(node)
	return node
