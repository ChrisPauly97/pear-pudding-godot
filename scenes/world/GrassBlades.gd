extends Node3D

const _GrassShader   = preload("res://assets/shaders/grass_blade.gdshader")
const _ClusterShader = preload("res://assets/shaders/grass_cluster.gdshader")
const WorldMap       = preload("res://game_logic/world/WorldMap.gd")

var _mat: ShaderMaterial
var _blade_mesh: ArrayMesh  # cached — identical for every chunk

var _cluster_mat:  ShaderMaterial
var _cluster_mesh: ArrayMesh  # unit quad, billboard-rotated per instance

var _prev_pos:      Vector3 = Vector3(-9999, 0, -9999)
var _last_move_dir: Vector2 = Vector2.ZERO

# Sliding trample window: 64x64 pixel image, player-centred, shifts when
# the player moves more than TRAMPLE_SHIFT_TILES tiles from the window centre.
const TRAMPLE_RES         := 64   # pixels (tiles)
const TRAMPLE_SHIFT_TILES := 16   # shift window after this many tiles of drift
const TRAMPLE_RADIUS      := 0    # pixel radius of player stamp (0 = single tile footprint)
const TRAMPLE_DECAY       := 0.02 # per-second decay rate
const TRAMPLE_FLOOR       := 0.3  # trampled grass never recovers past this
const TRAMPLE_RAMP        := 1.5  # per-second ramp-up rate

var _trample_img:      Image
var _trample_tex:      ImageTexture
var _trample_buf:      PackedFloat32Array  # CPU-side float buffer (avoids get/set_pixel)
var _trample_bytes:    PackedByteArray     # reusable byte buffer — avoids alloc per flush
var _trample_origin_x: float = 0.0  # world-space X of pixel (0,0) in trample map
var _trample_origin_z: float = 0.0  # world-space Z of pixel (0,0) in trample map
var _trample_timer:    float = 0.0  # throttle trample updates
const TRAMPLE_UPDATE_INTERVAL: float = 0.2  # ~5 Hz — was 15 Hz, barely visible difference

# Mobile-budget densities: real blade geometry is the single biggest GPU cost
# in grass biomes (each blade = 7 shaded verts), so keep counts low and let the
# 4-vert billboard clusters carry apparent density instead.
const BLADES_PER_TILE      := 16   # short grass tiles
const BLADES_TALL_PER_TILE := 40   # tall patch tiles
const CLUSTERS_PER_TILE    := 6    # billboard cluster quads per tile
const BLADE_WIDTH      := 0.20
const BLADE_HEIGHT     := 0.40
const SEGMENTS         := 3  # quads along the blade height

# Draw distance for grass MMIs. The orthogonal camera (size 15, offset
# (20,20,20)) never sees ground further than ~45 units away, so anything past
# ~55 (margin included) is pure vertex cost for zero visible blades.
const VISIBILITY_END: float = 55.0

# Render layer for all grass MMIs (layer 2 as a bitmask). The main camera's
# default cull_mask includes it; the minimap camera excludes it — at map scale
# blade instances are noise and GPU cost over the terrain's own grass texture.
const RENDER_LAYER: int = 1 << 1

# Tall grass patches: tiles grouped into cells of TALL_PATCH_CELL world units;
# a hash of the cell position determines if it grows tall grass (~18% of cells).
const TALL_PATCH_CELL:    float = 6.0   # world units per patch cell (≈3 tiles)
const TALL_PATCH_DENSITY: float = 0.12  # fraction of cells that become tall patches

# Integer hash mapped to [0,1) — used for deterministic patch classification.
static func _hash_pos(px: float, pz: float) -> float:
	var ix: int = int(px)
	var iz: int = int(pz)
	var h: int = (ix * 374761393) ^ (iz * 668265263)
	h = (h ^ (h >> 13)) * 1274126177
	return float(abs(h) % 100000) / 100000.0


# Per-chunk MultiMeshInstance3D nodes — keyed by Vector2i(cx, cz)
var _chunk_mmis:   Dictionary = {}
var _cluster_mmis: Dictionary = {}

static var _registered_global_params: Dictionary = {}

static func _ensure_global_param(name: String, type: RenderingServer.GlobalShaderParameterType, default_value: Variant) -> void:
	if not _registered_global_params.has(name):
		RenderingServer.global_shader_parameter_add(name, type, default_value)
		_registered_global_params[name] = true

func _init_material() -> void:
	if _mat:
		return
	_mat = ShaderMaterial.new()
	_mat.shader = _GrassShader
	_blade_mesh = _make_blade_mesh()

	_cluster_mat = ShaderMaterial.new()
	_cluster_mat.shader = _ClusterShader
	_cluster_mesh = _make_cluster_mesh()

	# Register global shader parameters shared across all grass chunks.
	# One set-call from update_player() reaches every chunk without per-chunk overhead.
	_ensure_global_param("player_pos",       RenderingServer.GLOBAL_VAR_TYPE_VEC3,    Vector3(-9999, 0, -9999))
	_ensure_global_param("player_move_dir",  RenderingServer.GLOBAL_VAR_TYPE_VEC2,    Vector2.ZERO)
	# Day/night brightness for the unshaded grass shaders — written by DayNightCycle.
	_ensure_global_param("grass_day_tint",   RenderingServer.GLOBAL_VAR_TYPE_VEC3,    Vector3.ONE)
	_ensure_global_param("trample_origin_x", RenderingServer.GLOBAL_VAR_TYPE_FLOAT,   0.0)
	_ensure_global_param("trample_origin_z", RenderingServer.GLOBAL_VAR_TYPE_FLOAT,   0.0)
	_ensure_global_param("trample_map",      RenderingServer.GLOBAL_VAR_TYPE_SAMPLER2D, null)

	# Sliding trample map — initialise centred at world origin
	_trample_buf = PackedFloat32Array()
	_trample_buf.resize(TRAMPLE_RES * TRAMPLE_RES)
	_trample_buf.fill(0.0)
	_trample_bytes = PackedByteArray()
	_trample_bytes.resize(TRAMPLE_RES * TRAMPLE_RES)
	_trample_bytes.fill(0)
	_trample_img = Image.create(TRAMPLE_RES, TRAMPLE_RES, false, Image.FORMAT_L8)
	_trample_img.fill(Color(0, 0, 0))
	_trample_tex = ImageTexture.create_from_image(_trample_img)
	_trample_origin_x = -(TRAMPLE_RES * IsoConst.TILE_SIZE * 0.5)
	_trample_origin_z = -(TRAMPLE_RES * IsoConst.TILE_SIZE * 0.5)

	RenderingServer.global_shader_parameter_set("trample_map",      _trample_tex)
	RenderingServer.global_shader_parameter_set("trample_origin_x", _trample_origin_x)
	RenderingServer.global_shader_parameter_set("trample_origin_z", _trample_origin_z)
	var window_world: float = TRAMPLE_RES * IsoConst.TILE_SIZE
	_mat.set_shader_parameter("trample_map_size", window_world)

# ── Static helpers: pure math, safe on worker threads ─────────────────────

# Compute grass tile centres from chunk data — no scene tree access.
static func compute_centres(chunk_data: RefCounted, chunk_origin: Vector3) -> Array[Vector2]:
	const TILE_GRASS_ID: int = 0  # IsoConst.TILE_GRASS — literal avoids autoload in static
	const TILE_WALL_ID:  int = 1  # IsoConst.TILE_WALL
	var ts: float = IsoConst.TILE_SIZE
	var centres: Array[Vector2] = []
	for lz in range(IsoConst.CHUNK_SIZE):
		for lx in range(IsoConst.CHUNK_SIZE):
			if chunk_data.get_tile(lx, lz) != TILE_GRASS_ID:
				continue
			var adj_wall := false
			for nb: Vector2i in [Vector2i(lx+1, lz), Vector2i(lx-1, lz), Vector2i(lx, lz+1), Vector2i(lx, lz-1)]:
				if chunk_data.get_tile(nb.x, nb.y) == TILE_WALL_ID:
					adj_wall = true
					break
			if adj_wall:
				continue
			centres.append(Vector2(
				chunk_origin.x + float(lx) * ts + ts * 0.5,
				chunk_origin.z + float(lz) * ts + ts * 0.5
			))
	return centres

# Build blade and cluster PackedFloat32Array buffers — no scene tree or GPU calls.
# Returns {} if centres is empty, otherwise returns the data needed by commit_grass_buffers.
static func prepare_buffers(centres: Array[Vector2], chunk_key: Vector2i) -> Dictionary:
	if centres.is_empty():
		return {}

	var half: float = IsoConst.TILE_SIZE * 0.45
	var blade_y: float = 0.01

	var rng := RandomNumberGenerator.new()
	rng.seed = 99887 ^ (chunk_key.x * 73856093) ^ (chunk_key.y * 19349663)

	# Pre-classify tiles
	var tall_flags: Array[bool] = []
	tall_flags.resize(centres.size())
	var total: int = 0
	for ci in range(centres.size()):
		var centre: Vector2 = centres[ci]
		var patch_x: float = snapped(centre.x, TALL_PATCH_CELL)
		var patch_z: float = snapped(centre.y, TALL_PATCH_CELL)
		var is_tall: bool = _hash_pos(patch_x, patch_z) < TALL_PATCH_DENSITY
		tall_flags[ci] = is_tall
		total += BLADES_TALL_PER_TILE if is_tall else BLADES_PER_TILE

	var blade_buf := PackedFloat32Array()
	blade_buf.resize(total * 12)
	var i: int = 0
	for ci in range(centres.size()):
		var centre: Vector2 = centres[ci]
		var is_tall: bool = tall_flags[ci]
		var blade_count: int = BLADES_TALL_PER_TILE if is_tall else BLADES_PER_TILE
		for _b in range(blade_count):
			var px: float = centre.x + rng.randf_range(-half, half)
			var pz: float = centre.y + rng.randf_range(-half, half)
			var rot: float = rng.randf_range(0.0, PI)
			var sy: float
			var sx: float
			if is_tall:
				sy = rng.randf_range(2.2, 3.8)
				sx = rng.randf_range(0.30, 0.50)
			else:
				sy = rng.randf_range(0.35, 0.85)
				sx = rng.randf_range(0.30, 0.55)
			var cr: float = cos(rot) * sx
			var sr: float = sin(rot) * sx
			var off: int  = i * 12
			blade_buf[off]    =  cr;  blade_buf[off+1]  = 0.0; blade_buf[off+2]  =  sr;  blade_buf[off+3]  = px
			blade_buf[off+4]  = 0.0;  blade_buf[off+5]  =  sy; blade_buf[off+6]  = 0.0;  blade_buf[off+7]  = blade_y
			blade_buf[off+8]  = -sr;  blade_buf[off+9]  = 0.0; blade_buf[off+10] =  cr;  blade_buf[off+11] = pz
			i += 1

	# Cluster buffers — separate seeded RNG so blade count changes don't shift clusters
	var crng := RandomNumberGenerator.new()
	crng.seed = (chunk_key.x * 92821739) ^ (chunk_key.y * 31415927) ^ 0x5EED1234
	var ctotal: int = centres.size() * CLUSTERS_PER_TILE
	var cluster_buf := PackedFloat32Array()
	cluster_buf.resize(ctotal * 12)
	var idx: int = 0
	for ci in range(centres.size()):
		var centre: Vector2 = centres[ci]
		var patch_x: float = snapped(centre.x, TALL_PATCH_CELL)
		var patch_z: float = snapped(centre.y, TALL_PATCH_CELL)
		var is_tall: bool = _hash_pos(patch_x, patch_z) < TALL_PATCH_DENSITY
		for _c in range(CLUSTERS_PER_TILE):
			var px: float = centre.x + crng.randf_range(-half, half)
			var pz: float = centre.y + crng.randf_range(-half, half)
			var sx: float
			var sy: float
			if is_tall:
				sx = crng.randf_range(0.45, 0.65)
				sy = crng.randf_range(0.50, 0.85)
			else:
				sx = crng.randf_range(0.45, 0.65)
				sy = crng.randf_range(0.24, 0.38)
			var off: int = idx * 12
			cluster_buf[off]    = sx;  cluster_buf[off+1]  = 0.0; cluster_buf[off+2]  = 0.0; cluster_buf[off+3]  = px
			cluster_buf[off+4]  = 0.0; cluster_buf[off+5]  = sy;  cluster_buf[off+6]  = 0.0; cluster_buf[off+7]  = 0.01
			cluster_buf[off+8]  = 0.0; cluster_buf[off+9]  = 0.0; cluster_buf[off+10] = 1.0; cluster_buf[off+11] = pz
			idx += 1

	return {
		"blade_buf":     blade_buf,
		"blade_count":   total,
		"cluster_buf":   cluster_buf,
		"cluster_count": ctotal,
	}

# Main-thread commit: create MultiMesh + MMI from pre-built buffers.
func commit_grass_buffers(grass_data: Dictionary, chunk_key: Vector2i) -> void:
	if grass_data.is_empty() or _chunk_mmis.has(chunk_key):
		return
	_init_material()
	var chunk_world: float = IsoConst.CHUNK_SIZE * IsoConst.TILE_SIZE
	var cx: int = chunk_key.x
	var cz: int = chunk_key.y

	var blade_count: int = grass_data["blade_count"]
	var mm := MultiMesh.new()
	mm.mesh = _blade_mesh
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.instance_count = blade_count
	mm.custom_aabb = AABB(
		Vector3(cx * chunk_world, -0.5, cz * chunk_world),
		Vector3(chunk_world, BLADE_HEIGHT + 2.0, chunk_world)
	)
	mm.buffer = grass_data["blade_buf"]
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = _mat
	mmi.visibility_range_end = VISIBILITY_END
	mmi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_DISABLED
	# Thousands of 2px-wide blades re-rendered into the shadow map cost a full
	# extra geometry pass for a shadow that reads as noise at 0.2 opacity.
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mmi.layers = RENDER_LAYER
	add_child(mmi)
	_chunk_mmis[chunk_key] = mmi

	var cluster_count: int = grass_data["cluster_count"]
	var cmm := MultiMesh.new()
	cmm.mesh = _cluster_mesh
	cmm.transform_format = MultiMesh.TRANSFORM_3D
	cmm.instance_count = cluster_count
	cmm.custom_aabb = AABB(
		Vector3(cx * chunk_world, -0.5, cz * chunk_world),
		Vector3(chunk_world, 1.5, chunk_world)
	)
	cmm.buffer = grass_data["cluster_buf"]
	var cmmi := MultiMeshInstance3D.new()
	cmmi.multimesh = cmm
	cmmi.material_override = _cluster_mat
	cmmi.visibility_range_end = VISIBILITY_END
	cmmi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_DISABLED
	# Billboard quads cast misshapen shadows — disable to avoid diamond artifacts.
	cmmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	cmmi.layers = RENDER_LAYER
	add_child(cmmi)
	_cluster_mmis[chunk_key] = cmmi

# Streaming entry point — builds grass for one chunk of the infinite world
func build_chunk(centres: Array[Vector2], chunk_key: Vector2i) -> void:
	if _chunk_mmis.has(chunk_key):
		return
	_init_material()
	var rng := RandomNumberGenerator.new()
	rng.seed = 99887 ^ (chunk_key.x * 73856093) ^ (chunk_key.y * 19349663)
	_build_chunk_mmi(centres, chunk_key, rng)

func remove_chunk(chunk_key: Vector2i) -> void:
	if _chunk_mmis.has(chunk_key):
		var mmi: MultiMeshInstance3D = _chunk_mmis[chunk_key]
		mmi.queue_free()
		_chunk_mmis.erase(chunk_key)
	if _cluster_mmis.has(chunk_key):
		var mmi: MultiMeshInstance3D = _cluster_mmis[chunk_key]
		mmi.queue_free()
		_cluster_mmis.erase(chunk_key)

func _build_chunk_mmi(centres: Array[Vector2], chunk_key: Vector2i, rng: RandomNumberGenerator) -> void:
	if centres.is_empty():
		return

	var half: float = IsoConst.TILE_SIZE * 0.45
	var blade_y: float = 0.01

	# Pre-classify tiles so we know the exact blade count before allocating.
	var tall_flags: Array[bool] = []
	tall_flags.resize(centres.size())
	var total: int = 0
	for ci in range(centres.size()):
		var centre: Vector2 = centres[ci]
		var patch_x: float = snapped(centre.x, TALL_PATCH_CELL)
		var patch_z: float = snapped(centre.y, TALL_PATCH_CELL)
		var is_tall: bool = _hash_pos(patch_x, patch_z) < TALL_PATCH_DENSITY
		tall_flags[ci] = is_tall
		total += BLADES_TALL_PER_TILE if is_tall else BLADES_PER_TILE

	var mm := MultiMesh.new()
	mm.mesh = _blade_mesh
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.instance_count = total

	var buf := PackedFloat32Array()
	buf.resize(total * 12)
	var i: int = 0

	for ci in range(centres.size()):
		var centre: Vector2 = centres[ci]
		var is_tall: bool = tall_flags[ci]
		var blade_count: int = BLADES_TALL_PER_TILE if is_tall else BLADES_PER_TILE
		for _b in range(blade_count):
			var px: float = centre.x + rng.randf_range(-half, half)
			var pz: float = centre.y + rng.randf_range(-half, half)
			var rot: float = rng.randf_range(0.0, PI)
			var sy: float  # height scale
			var sx: float  # width scale (independent — keeps tall blades thin)
			if is_tall:
				sy = rng.randf_range(2.2, 3.8)   # ~0.88–1.52 world units tall
				sx = rng.randf_range(0.30, 0.50)  # wider than before — less hairlike, screen-safe
			else:
				sy = rng.randf_range(0.35, 0.85)  # short ground grass
				sx = rng.randf_range(0.30, 0.55)  # decoupled from height, stays >= ~2px wide
			var cr: float  = cos(rot) * sx
			var sr: float  = sin(rot) * sx
			var off: int   = i * 12
			buf[off]     =  cr;  buf[off+1]  = 0.0; buf[off+2]  =  sr;  buf[off+3]  = px
			buf[off+4]   = 0.0;  buf[off+5]  =  sy; buf[off+6]  = 0.0;  buf[off+7]  = blade_y
			buf[off+8]   = -sr;  buf[off+9]  = 0.0; buf[off+10] =  cr;  buf[off+11] = pz
			i += 1

	var chunk_world: float = IsoConst.CHUNK_SIZE * IsoConst.TILE_SIZE
	var cx: int = chunk_key.x
	var cz: int = chunk_key.y
	mm.custom_aabb = AABB(
		Vector3(cx * chunk_world, -0.5, cz * chunk_world),
		Vector3(chunk_world, BLADE_HEIGHT + 2.0, chunk_world)
	)
	mm.buffer = buf

	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = _mat
	mmi.visibility_range_end = VISIBILITY_END
	mmi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_DISABLED
	# Thousands of 2px-wide blades re-rendered into the shadow map cost a full
	# extra geometry pass for a shadow that reads as noise at 0.2 opacity.
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mmi.layers = RENDER_LAYER
	add_child(mmi)
	_chunk_mmis[chunk_key] = mmi

	# Billboard clusters — seeded independently so blade count changes don't
	# affect cluster placement.
	var crng := RandomNumberGenerator.new()
	crng.seed = (chunk_key.x * 92821739) ^ (chunk_key.y * 31415927) ^ 0x5EED1234
	_build_chunk_clusters(centres, chunk_key, crng)

func _build_chunk_clusters(centres: Array[Vector2], chunk_key: Vector2i, rng: RandomNumberGenerator) -> void:
	if centres.is_empty() or _cluster_mmis.has(chunk_key):
		return

	var total: int = centres.size() * CLUSTERS_PER_TILE
	var mm := MultiMesh.new()
	mm.mesh = _cluster_mesh
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.instance_count = total

	var buf := PackedFloat32Array()
	buf.resize(total * 12)
	var half: float = IsoConst.TILE_SIZE * 0.45
	var idx: int = 0

	for ci in range(centres.size()):
		var centre: Vector2 = centres[ci]
		var patch_x: float = snapped(centre.x, TALL_PATCH_CELL)
		var patch_z: float = snapped(centre.y, TALL_PATCH_CELL)
		var is_tall: bool = _hash_pos(patch_x, patch_z) < TALL_PATCH_DENSITY
		for _c in range(CLUSTERS_PER_TILE):
			var px: float = centre.x + rng.randf_range(-half, half)
			var pz: float = centre.y + rng.randf_range(-half, half)
			var sx: float
			var sy: float
			if is_tall:
				sx = rng.randf_range(0.45, 0.65)
				sy = rng.randf_range(0.50, 0.85)
			else:
				sx = rng.randf_range(0.45, 0.65)
				sy = rng.randf_range(0.24, 0.38)
			var off: int = idx * 12
			buf[off]    = sx;  buf[off+1]  = 0.0; buf[off+2]  = 0.0; buf[off+3]  = px
			buf[off+4]  = 0.0; buf[off+5]  = sy;  buf[off+6]  = 0.0; buf[off+7]  = 0.01
			buf[off+8]  = 0.0; buf[off+9]  = 0.0; buf[off+10] = 1.0; buf[off+11] = pz
			idx += 1

	var chunk_world: float = IsoConst.CHUNK_SIZE * IsoConst.TILE_SIZE
	var cx: int = chunk_key.x
	var cz: int = chunk_key.y
	mm.custom_aabb = AABB(
		Vector3(cx * chunk_world, -0.5, cz * chunk_world),
		Vector3(chunk_world, 1.5, chunk_world)
	)
	mm.buffer = buf

	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = _cluster_mat
	mmi.visibility_range_end = VISIBILITY_END
	mmi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_DISABLED
	# Billboard quads cast misshapen shadows — disable to avoid diamond artifacts.
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mmi.layers = RENDER_LAYER
	add_child(mmi)
	_cluster_mmis[chunk_key] = mmi

func _make_cluster_mesh() -> ArrayMesh:
	# Unit quad: X from -0.5 to 0.5, Y from 0 to 1, facing +Z.
	# billboard_fixed_y rotates it around Y to face the camera each frame.
	var verts := PackedVector3Array([
		Vector3(-0.5, 0.0, 0.0),
		Vector3( 0.5, 0.0, 0.0),
		Vector3( 0.5, 1.0, 0.0),
		Vector3(-0.5, 1.0, 0.0),
	])
	var uvs := PackedVector2Array([
		Vector2(0.0, 0.0), Vector2(1.0, 0.0),
		Vector2(1.0, 1.0), Vector2(0.0, 1.0),
	])
	var normals := PackedVector3Array([
		Vector3(0.0, 0.0, 1.0), Vector3(0.0, 0.0, 1.0),
		Vector3(0.0, 0.0, 1.0), Vector3(0.0, 0.0, 1.0),
	])
	var indices := PackedInt32Array([0, 1, 2, 0, 2, 3])
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_INDEX]  = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh

func set_wind_direction(dir: Vector2) -> void:
	if _mat:
		_mat.set_shader_parameter("wind_direction", dir)
	if _cluster_mat:
		_cluster_mat.set_shader_parameter("wind_direction", dir)

func update_player(pos: Vector3, delta: float, is_grounded: bool) -> void:
	if not _mat:
		return

	# Immediate blade push — single global call reaches all chunks at once
	RenderingServer.global_shader_parameter_set("player_pos",
		pos if is_grounded else Vector3(-9999.0, 0.0, -9999.0))

	# Movement direction — only upload when it changes
	var move_dir := Vector2.ZERO
	var dp_sq: float = Vector2(pos.x - _prev_pos.x, pos.z - _prev_pos.z).length_squared()
	if dp_sq > 0.0025:  # 0.05 units threshold
		move_dir = Vector2(pos.x - _prev_pos.x, pos.z - _prev_pos.z).normalized()
	_prev_pos = pos
	if move_dir != _last_move_dir:
		RenderingServer.global_shader_parameter_set("player_move_dir", move_dir)
		_last_move_dir = move_dir

	if is_grounded and _trample_img:
		_trample_timer += delta
		if _trample_timer >= TRAMPLE_UPDATE_INTERVAL:
			_maybe_shift_trample_window(pos)
			_update_trample_map(pos, _trample_timer)
			_trample_timer = 0.0

# Shift the trample window when the player drifts far from the window centre
func _maybe_shift_trample_window(pos: Vector3) -> void:
	var tile_size: float = IsoConst.TILE_SIZE
	var window_world: float = TRAMPLE_RES * tile_size
	var centre_x: float = _trample_origin_x + window_world * 0.5
	var centre_z: float = _trample_origin_z + window_world * 0.5
	var shift_world: float = TRAMPLE_SHIFT_TILES * tile_size

	if abs(pos.x - centre_x) < shift_world and abs(pos.z - centre_z) < shift_world:
		return

	var new_ox: float = pos.x - window_world * 0.5
	var new_oz: float = pos.z - window_world * 0.5
	var dx: int = int(round((_trample_origin_x - new_ox) / tile_size))
	var dz: int = int(round((_trample_origin_z - new_oz) / tile_size))

	# Shift the float buffer — copy overlapping region into a new buffer
	var new_buf := PackedFloat32Array()
	new_buf.resize(TRAMPLE_RES * TRAMPLE_RES)
	new_buf.fill(0.0)
	var src_x: int = max(0, -dx)
	var src_z: int = max(0, -dz)
	var dst_x: int = max(0, dx)
	var dst_z: int = max(0, dz)
	var copy_w: int = TRAMPLE_RES - abs(dx)
	var copy_h: int = TRAMPLE_RES - abs(dz)
	if copy_w > 0 and copy_h > 0:
		for z in range(copy_h):
			for x in range(copy_w):
				new_buf[(dst_z + z) * TRAMPLE_RES + dst_x + x] = _trample_buf[(src_z + z) * TRAMPLE_RES + src_x + x]

	_trample_buf = new_buf
	_trample_origin_x = new_ox
	_trample_origin_z = new_oz
	# Rebuild byte buffer from float buffer after shift
	for i in range(_trample_buf.size()):
		_trample_bytes[i] = int(clampf(_trample_buf[i], 0.0, 1.0) * 255.0)
	_flush_trample_to_gpu()
	RenderingServer.global_shader_parameter_set("trample_origin_x", _trample_origin_x)
	RenderingServer.global_shader_parameter_set("trample_origin_z", _trample_origin_z)

func _update_trample_map(pos: Vector3, delta: float) -> void:
	var tile_size: float = IsoConst.TILE_SIZE
	var px: int = int((pos.x - _trample_origin_x) / tile_size)
	var pz: int = int((pos.z - _trample_origin_z) / tile_size)

	var decay_r: int = TRAMPLE_RADIUS + 3
	var x0: int = max(0, px - decay_r)
	var x1: int = min(TRAMPLE_RES - 1, px + decay_r)
	var z0: int = max(0, pz - decay_r)
	var z1: int = min(TRAMPLE_RES - 1, pz + decay_r)

	var decay_amount: float = TRAMPLE_DECAY * delta

	# Decay + stamp on the float buffer — no Color allocations
	for z in range(z0, z1 + 1):
		var row: int = z * TRAMPLE_RES
		for x in range(x0, x1 + 1):
			var v: float = _trample_buf[row + x]
			if v > 0.0:
				var nv: float = maxf(TRAMPLE_FLOOR, v - decay_amount)
				_trample_buf[row + x] = nv
				_trample_bytes[row + x] = int(clampf(nv, 0.0, 1.0) * 255.0)

	var ramp: float = TRAMPLE_RAMP * delta
	for z in range(max(0, pz - TRAMPLE_RADIUS), min(TRAMPLE_RES, pz + TRAMPLE_RADIUS + 1)):
		var row: int = z * TRAMPLE_RES
		for x in range(max(0, px - TRAMPLE_RADIUS), min(TRAMPLE_RES, px + TRAMPLE_RADIUS + 1)):
			var ddx: float = float(x - px)
			var ddz: float = float(z - pz)
			var dist_sq: float = ddx * ddx + ddz * ddz
			if dist_sq <= float(TRAMPLE_RADIUS * TRAMPLE_RADIUS):
				var dist: float = sqrt(dist_sq)
				var target: float = 1.0 - dist / (TRAMPLE_RADIUS + 1.0)
				var cur: float = _trample_buf[row + x]
				var nv: float = minf(target, cur + ramp)
				_trample_buf[row + x] = nv
				_trample_bytes[row + x] = int(clampf(nv, 0.0, 1.0) * 255.0)

	_flush_trample_to_gpu()

# Upload only the dirty region of the trample map to the GPU.
# _trample_bytes is kept in sync during _update_trample_map so no
# separate float→byte conversion loop is needed.
func _flush_trample_to_gpu() -> void:
	_trample_img.set_data(TRAMPLE_RES, TRAMPLE_RES, false, Image.FORMAT_L8, _trample_bytes)
	_trample_tex.update(_trample_img)

func _make_blade_mesh() -> ArrayMesh:
	var verts   := PackedVector3Array()
	var uvs     := PackedVector2Array()
	var normals := PackedVector3Array()
	var indices := PackedInt32Array()

	var width_profile: Array[float] = [1.0, 0.62, 0.24]

	for row in range(SEGMENTS):
		var t := float(row) / float(SEGMENTS)
		var y := t * BLADE_HEIGHT
		var w: float = BLADE_WIDTH * 0.5 * width_profile[row]
		verts.append(Vector3(-w, y, 0.0))
		verts.append(Vector3( w, y, 0.0))
		uvs.append(Vector2(0.0, t))
		uvs.append(Vector2(1.0, t))
		normals.append(Vector3(0.0, 0.0, 1.0))
		normals.append(Vector3(0.0, 0.0, 1.0))

	verts.append(Vector3(0.0, BLADE_HEIGHT, 0.0))
	uvs.append(Vector2(0.5, 1.0))
	normals.append(Vector3(0.0, 0.0, 1.0))

	for row in range(SEGMENTS - 1):
		var b := row * 2
		indices.append_array([b, b+1, b+2,  b+1, b+3, b+2])

	var last := (SEGMENTS - 1) * 2
	var tip  := SEGMENTS * 2
	indices.append_array([last, last+1, tip])

	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX]  = verts
	arrays[Mesh.ARRAY_TEX_UV]  = uvs
	arrays[Mesh.ARRAY_NORMAL]  = normals
	arrays[Mesh.ARRAY_INDEX]   = indices

	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh
