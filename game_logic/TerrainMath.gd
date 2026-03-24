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
	var min_dist_sq_hill: float = curve_r_sq
	var min_dist_sq_wall: float = curve_r_sq
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
			else:  # TILE_WALL
				if dist_sq < min_dist_sq_wall:
					min_dist_sq_wall = dist_sq
					var wh: int = height_lookup.call(ttx, ttz)
					nearest_wall_peak = minf(float(maxi(1, wh)) * IsoConst.WALL_FACE_H, WALL_MAX_H)

	var h: float = 0.0
	if min_dist_sq_hill < curve_r_sq:
		var t: float = 1.0 - sqrt(min_dist_sq_hill) / curve_r
		t = t * t * (3.0 - 2.0 * t)
		h = peak_h * t
	if min_dist_sq_wall < curve_r_sq:
		var tw: float = 1.0 - sqrt(min_dist_sq_wall) / curve_r
		tw = tw * tw * (3.0 - 2.0 * tw)
		var wh: float = nearest_wall_peak * tw
		if wh > h:
			h = wh
	return h

## Compute a packed height field for a grid of vertices.
## tile_lookup: Callable(ttx: int, ttz: int) -> int — returns tile type
## height_lookup: Callable(ttx: int, ttz: int) -> int — returns wall height
## origin_x, origin_z: world-space origin of the grid
## nvx, nvz: vertex count in each axis
## step: world units between vertices
## curve_r, peak_h: smoothstep parameters
static func compute_height_field(
		tile_lookup: Callable,
		height_lookup: Callable,
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
			var min_dist_sq_hill: float = curve_r_sq
			var min_dist_sq_wall: float = curve_r_sq
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
					else:  # TILE_WALL
						if dist_sq < min_dist_sq_wall:
							min_dist_sq_wall = dist_sq
							var wh: int = height_lookup.call(ttx, ttz)
							nearest_wall_peak = minf(float(maxi(1, wh)) * IsoConst.WALL_FACE_H, WALL_MAX_H)

			var h: float = 0.0
			if min_dist_sq_hill < curve_r_sq:
				var t: float = 1.0 - sqrt(min_dist_sq_hill) * inv_curve_r
				t = t * t * (3.0 - 2.0 * t)
				h = peak_h * t
			if min_dist_sq_wall < curve_r_sq:
				var tw: float = 1.0 - sqrt(min_dist_sq_wall) * inv_curve_r
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
