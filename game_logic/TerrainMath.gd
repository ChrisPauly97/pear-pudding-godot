class_name TerrainMath
extends RefCounted

# Shared terrain height, mesh, and wall-mesh building used by both the
# named-map path (WorldScene) and the infinite-chunk path (ChunkRenderer).
# Eliminates the three duplicate smoothstep implementations and the two
# duplicate mesh-builder copies.

# Maximum wall height in world units (walls are clamped to this)
const WALL_MAX_H: float = 10.0

# ── Height computation ────────────────────────────────────────────────────

## Compute terrain height at world position (wx, wz) using smoothstep blend.
## tile_lookup: Callable(ttx: int, ttz: int) -> int  — returns tile type
## height_lookup: Callable(ttx: int, ttz: int) -> int — returns tile height level
## curve_r: hill smoothstep transition radius (world units)
## peak_h: fallback hill height when height_lookup returns 0 (named-map compat)
## wall_curve_r: wall smoothstep radius; defaults to curve_r when <= 0
static func get_height_at(wx: float, wz: float,
		tile_lookup: Callable, height_lookup: Callable,
		curve_r: float, peak_h: float, wall_curve_r: float = -1.0) -> float:
	var _wall_r: float = wall_curve_r if wall_curve_r > 0.0 else curve_r
	var tile_check: int = int(ceil(maxf(curve_r, _wall_r) / IsoConst.TILE_SIZE)) + 1
	var vtx: int = int(wx / IsoConst.TILE_SIZE)
	var vtz: int = int(wz / IsoConst.TILE_SIZE)
	var hill_r_sq: float = curve_r * curve_r
	var wall_r_sq: float = _wall_r * _wall_r
	var min_dist_sq_hill: float = hill_r_sq
	var min_dist_sq_wall: float = wall_r_sq
	var nearest_hill_peak: float = peak_h
	var nearest_wall_peak: float = 0.0
	for dtz in range(-tile_check, tile_check + 1):
		for dtx in range(-tile_check, tile_check + 1):
			var ttx: int = vtx + dtx
			var ttz: int = vtz + dtz
			var tile_type: int = tile_lookup.call(ttx, ttz)
			if tile_type != IsoConst.TILE_HILL and tile_type != IsoConst.TILE_WALL:
				continue
			var near_x: float = clamp(wx, float(ttx) * IsoConst.TILE_SIZE, float(ttx + 1) * IsoConst.TILE_SIZE)
			var near_z: float = clamp(wz, float(ttz) * IsoConst.TILE_SIZE, float(ttz + 1) * IsoConst.TILE_SIZE)
			var ddx: float = wx - near_x
			var ddz: float = wz - near_z
			var dist_sq: float = ddx * ddx + ddz * ddz
			if tile_type == IsoConst.TILE_HILL:
				if dist_sq < min_dist_sq_hill:
					min_dist_sq_hill = dist_sq
					var hh: int = height_lookup.call(ttx, ttz)
					nearest_hill_peak = float(hh) * IsoConst.HILL_FACE_H if hh > 0 else peak_h
			else:  # TILE_WALL
				if dist_sq < min_dist_sq_wall:
					min_dist_sq_wall = dist_sq
					var wh: int = height_lookup.call(ttx, ttz)
					nearest_wall_peak = minf(float(maxi(1, wh)) * IsoConst.WALL_FACE_H, WALL_MAX_H)

	var h: float = 0.0
	if min_dist_sq_hill < hill_r_sq:
		var t: float = 1.0 - sqrt(min_dist_sq_hill) / curve_r
		t = t * t * (3.0 - 2.0 * t)
		h = nearest_hill_peak * t
	if min_dist_sq_wall < wall_r_sq:
		var tw: float = 1.0 - sqrt(min_dist_sq_wall) / _wall_r
		tw = tw * tw * (3.0 - 2.0 * tw)
		var wh: float = nearest_wall_peak * tw
		if wh > h:
			h = wh
	return h

## Compute a packed height field for a grid of vertices.
## tile_lookup: Callable(ttx: int, ttz: int) -> int — returns tile type
## height_lookup: Callable(ttx: int, ttz: int) -> int — returns tile height level
## origin_x, origin_z: world-space origin of the grid
## nvx, nvz: vertex count in each axis
## step: world units between vertices
## curve_r: hill smoothstep radius; peak_h: fallback hill height when stored height is 0
## wall_curve_r: wall smoothstep radius; defaults to curve_r when <= 0
static func compute_height_field(
		tile_lookup: Callable,
		height_lookup: Callable,
		origin_x: float, origin_z: float,
		nvx: int, nvz: int, step: float,
		curve_r: float, peak_h: float, wall_curve_r: float = -1.0) -> PackedFloat32Array:
	var _wall_r: float = wall_curve_r if wall_curve_r > 0.0 else curve_r
	var tile_check: int = int(ceil(maxf(curve_r, _wall_r) / IsoConst.TILE_SIZE)) + 1
	var hill_r_sq: float = curve_r * curve_r
	var wall_r_sq: float = _wall_r * _wall_r
	var inv_hill_r: float = 1.0 / curve_r
	var inv_wall_r: float = 1.0 / _wall_r

	var hfield := PackedFloat32Array()
	hfield.resize(nvx * nvz)
	for iz in range(nvz):
		for ix in range(nvx):
			var gx: float = origin_x + ix * step
			var gz: float = origin_z + iz * step
			var vtx: int = int(gx / IsoConst.TILE_SIZE)
			var vtz: int = int(gz / IsoConst.TILE_SIZE)
			var min_dist_sq_hill: float = hill_r_sq
			var min_dist_sq_wall: float = wall_r_sq
			var nearest_hill_peak: float = peak_h
			var nearest_wall_peak: float = 0.0
			for dtz in range(-tile_check, tile_check + 1):
				for dtx in range(-tile_check, tile_check + 1):
					var ttx: int = vtx + dtx
					var ttz: int = vtz + dtz
					var tile_type: int = tile_lookup.call(ttx, ttz)
					if tile_type != IsoConst.TILE_HILL and tile_type != IsoConst.TILE_WALL:
						continue
					var near_x: float = clamp(gx, float(ttx) * IsoConst.TILE_SIZE, float(ttx + 1) * IsoConst.TILE_SIZE)
					var near_z: float = clamp(gz, float(ttz) * IsoConst.TILE_SIZE, float(ttz + 1) * IsoConst.TILE_SIZE)
					var ddx: float = gx - near_x
					var ddz: float = gz - near_z
					var dist_sq: float = ddx * ddx + ddz * ddz
					if tile_type == IsoConst.TILE_HILL:
						if dist_sq < min_dist_sq_hill:
							min_dist_sq_hill = dist_sq
							var hh: int = height_lookup.call(ttx, ttz)
							nearest_hill_peak = float(hh) * IsoConst.HILL_FACE_H if hh > 0 else peak_h
					else:  # TILE_WALL
						if dist_sq < min_dist_sq_wall:
							min_dist_sq_wall = dist_sq
							var wh: int = height_lookup.call(ttx, ttz)
							nearest_wall_peak = minf(float(maxi(1, wh)) * IsoConst.WALL_FACE_H, WALL_MAX_H)

			var h: float = 0.0
			if min_dist_sq_hill < hill_r_sq:
				var t: float = 1.0 - sqrt(min_dist_sq_hill) * inv_hill_r
				t = t * t * (3.0 - 2.0 * t)
				h = nearest_hill_peak * t
			if min_dist_sq_wall < wall_r_sq:
				var tw: float = 1.0 - sqrt(min_dist_sq_wall) * inv_wall_r
				tw = tw * tw * (3.0 - 2.0 * tw)
				var wh: float = nearest_wall_peak * tw
				if wh > h:
					h = wh
			hfield[iz * nvx + ix] = h
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
			# Outward-facing horizontal normal for the skirt panel:
			# iz=0 is the near edge (faces -Z), iz=nvz-1 is the far edge (faces +Z)
			skirt_normals[si] = Vector3(0.0, 0.0, -1.0) if iz_edge == 0 else Vector3(0.0, 0.0, 1.0)
			skirt_uvs[si]     = uvs[surf_i]
			skirt_colors[si]  = colors[surf_i]
			_edge_ids.append(surf_i)
			_edge_ids.append(si)
			si += 1
	for iz in range(1, nvz - 1):
		for ix_edge in [0, nvx - 1]:
			var surf_i: int = iz * nvx + ix_edge
			skirt_verts[si]   = Vector3(verts[surf_i].x, SKIRT_Y, verts[surf_i].z)
			# ix=0 is the left edge (faces -X), ix=nvx-1 is the right edge (faces +X)
			skirt_normals[si] = Vector3(-1.0, 0.0, 0.0) if ix_edge == 0 else Vector3(1.0, 0.0, 0.0)
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

# ── Wall face mesh building ───────────────────────────────────────────────

## Build explicit vertical quad geometry for every exposed wall-to-non-wall
## tile boundary within the chunk.  The resulting ArrayMesh should be rendered
## with the terrain ShaderMaterial; the baked horizontal normals (slope = 1.0)
## cause the shader to select wall_side_texture instead of grass.
##
## tile_lookup:     Callable(ttx: int, ttz: int) -> int   — global tile coords
## height_lookup:   Callable(ttx: int, ttz: int) -> int   — global tile coords
## origin_x, origin_z: world-space origin of the chunk
## chunk_tiles_x, chunk_tiles_z: tile count per axis (normally 16)
static func build_wall_face_mesh(
		tile_lookup: Callable,
		height_lookup: Callable,
		origin_x: float, origin_z: float,
		chunk_tiles_x: int, chunk_tiles_z: int) -> ArrayMesh:
	var verts   := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs     := PackedVector2Array()
	var colors  := PackedColorArray()
	var indices := PackedInt32Array()

	var tile_min_x: int = int(round(origin_x / IsoConst.TILE_SIZE))
	var tile_min_z: int = int(round(origin_z / IsoConst.TILE_SIZE))
	# wall colour: v_blend=0 (unused), v_wall=1 (is_wall flag), alpha=1
	var wall_col := Color(0.0, 1.0, 0.0, 1.0)

	for local_tz in range(chunk_tiles_z):
		for local_tx in range(chunk_tiles_x):
			var tx: int = tile_min_x + local_tx
			var tz: int = tile_min_z + local_tz
			if tile_lookup.call(tx, tz) != IsoConst.TILE_WALL:
				continue
			var wh: int = height_lookup.call(tx, tz)
			var top_y: float = minf(float(maxi(1, wh)) * IsoConst.WALL_FACE_H, WALL_MAX_H)

			# Local positions relative to chunk origin
			var lx0: float = float(local_tx) * IsoConst.TILE_SIZE
			var lx1: float = float(local_tx + 1) * IsoConst.TILE_SIZE
			var lz0: float = float(local_tz) * IsoConst.TILE_SIZE
			var lz1: float = float(local_tz + 1) * IsoConst.TILE_SIZE

			# -X face (left): exposed when the tile to the left is not a wall
			if tile_lookup.call(tx - 1, tz) != IsoConst.TILE_WALL:
				var bi: int = verts.size()
				verts.append(Vector3(lx0, 0.0,   lz0))
				verts.append(Vector3(lx0, 0.0,   lz1))
				verts.append(Vector3(lx0, top_y, lz0))
				verts.append(Vector3(lx0, top_y, lz1))
				normals.append(Vector3(-1.0, 0.0, 0.0))
				normals.append(Vector3(-1.0, 0.0, 0.0))
				normals.append(Vector3(-1.0, 0.0, 0.0))
				normals.append(Vector3(-1.0, 0.0, 0.0))
				uvs.append(Vector2(lx0, lz0)); uvs.append(Vector2(lx0, lz1))
				uvs.append(Vector2(lx0, lz0)); uvs.append(Vector2(lx0, lz1))
				colors.append(wall_col); colors.append(wall_col)
				colors.append(wall_col); colors.append(wall_col)
				indices.append(bi);     indices.append(bi + 2); indices.append(bi + 1)
				indices.append(bi + 1); indices.append(bi + 2); indices.append(bi + 3)

			# +X face (right)
			if tile_lookup.call(tx + 1, tz) != IsoConst.TILE_WALL:
				var bi: int = verts.size()
				verts.append(Vector3(lx1, 0.0,   lz1))
				verts.append(Vector3(lx1, 0.0,   lz0))
				verts.append(Vector3(lx1, top_y, lz1))
				verts.append(Vector3(lx1, top_y, lz0))
				normals.append(Vector3(1.0, 0.0, 0.0))
				normals.append(Vector3(1.0, 0.0, 0.0))
				normals.append(Vector3(1.0, 0.0, 0.0))
				normals.append(Vector3(1.0, 0.0, 0.0))
				uvs.append(Vector2(lx1, lz1)); uvs.append(Vector2(lx1, lz0))
				uvs.append(Vector2(lx1, lz1)); uvs.append(Vector2(lx1, lz0))
				colors.append(wall_col); colors.append(wall_col)
				colors.append(wall_col); colors.append(wall_col)
				indices.append(bi);     indices.append(bi + 2); indices.append(bi + 1)
				indices.append(bi + 1); indices.append(bi + 2); indices.append(bi + 3)

			# -Z face (near)
			if tile_lookup.call(tx, tz - 1) != IsoConst.TILE_WALL:
				var bi: int = verts.size()
				verts.append(Vector3(lx1, 0.0,   lz0))
				verts.append(Vector3(lx0, 0.0,   lz0))
				verts.append(Vector3(lx1, top_y, lz0))
				verts.append(Vector3(lx0, top_y, lz0))
				normals.append(Vector3(0.0, 0.0, -1.0))
				normals.append(Vector3(0.0, 0.0, -1.0))
				normals.append(Vector3(0.0, 0.0, -1.0))
				normals.append(Vector3(0.0, 0.0, -1.0))
				uvs.append(Vector2(lx1, lz0)); uvs.append(Vector2(lx0, lz0))
				uvs.append(Vector2(lx1, lz0)); uvs.append(Vector2(lx0, lz0))
				colors.append(wall_col); colors.append(wall_col)
				colors.append(wall_col); colors.append(wall_col)
				indices.append(bi);     indices.append(bi + 2); indices.append(bi + 1)
				indices.append(bi + 1); indices.append(bi + 2); indices.append(bi + 3)

			# +Z face (far)
			if tile_lookup.call(tx, tz + 1) != IsoConst.TILE_WALL:
				var bi: int = verts.size()
				verts.append(Vector3(lx0, 0.0,   lz1))
				verts.append(Vector3(lx1, 0.0,   lz1))
				verts.append(Vector3(lx0, top_y, lz1))
				verts.append(Vector3(lx1, top_y, lz1))
				normals.append(Vector3(0.0, 0.0, 1.0))
				normals.append(Vector3(0.0, 0.0, 1.0))
				normals.append(Vector3(0.0, 0.0, 1.0))
				normals.append(Vector3(0.0, 0.0, 1.0))
				uvs.append(Vector2(lx0, lz1)); uvs.append(Vector2(lx1, lz1))
				uvs.append(Vector2(lx0, lz1)); uvs.append(Vector2(lx1, lz1))
				colors.append(wall_col); colors.append(wall_col)
				colors.append(wall_col); colors.append(wall_col)
				indices.append(bi);     indices.append(bi + 2); indices.append(bi + 1)
				indices.append(bi + 1); indices.append(bi + 2); indices.append(bi + 3)

	if verts.is_empty():
		return ArrayMesh.new()

	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_COLOR]  = colors
	arrays[Mesh.ARRAY_INDEX]  = indices
	var wall_mesh := ArrayMesh.new()
	wall_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return wall_mesh

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
