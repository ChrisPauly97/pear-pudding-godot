extends Node3D

const _TuftShader    = preload("res://assets/shaders/grass_tuft.gdshader")
const _TuftShaderLit = preload("res://assets/shaders/grass_tuft_lit.gdshader")
const _TuftAtlas     = preload("res://assets/textures/pixel_art/grass_tufts.png")
const WorldMap       = preload("res://game_logic/world/WorldMap.gd")
const _ChunkData     = preload("res://game_logic/world/ChunkData.gd")

# Sliding trample window: 64x64 pixel image, player-centred, shifts when
# the player moves more than TRAMPLE_SHIFT_TILES tiles from the window centre.
const TRAMPLE_RES         := 64   # pixels (tiles)
const TRAMPLE_SHIFT_TILES := 16   # shift window after this many tiles of drift
const TRAMPLE_RADIUS      := 0    # pixel radius of player stamp (0 = single tile footprint)
const TRAMPLE_DECAY       := 0.02 # per-second decay rate
const TRAMPLE_FLOOR       := 0.3  # trampled grass never recovers past this
const TRAMPLE_RAMP        := 1.5  # per-second ramp-up rate
const TRAMPLE_UPDATE_INTERVAL: float = 0.2  # ~5 Hz — was 15 Hz, barely visible difference

# Grass is billboard tuft sprites from grass_tufts.png (4 verts each), drawn at
# the character sprites' pixel size so the grass matches the rest of the art.
# This replaced 3-D blades (7 verts each, 16-40 per tile) plus spiky cluster
# quads: ~5x fewer vertices for a fuller, less jagged field.
# Ordinary grass is patchy, not a carpet: a hash per SHORT_PATCH_CELL picks
# 0..TUFTS_PER_TILE_MAX tufts for the tiles in it (mean ~1.25), so the meadow
# has bare stretches, sparse ones and a few fuller clumps.
const TUFTS_PER_TILE_MAX  := 4
const SHORT_PATCH_CELL: float = 4.0   # world units (2 tiles)
const TUFTS_TALL_PER_TILE := 6    # tall tufts on a tall-patch tile (plus 2 short)
const PIXEL: float = 0.05         # world units per texel — Player.PIXEL_SIZE
const TUFT_W: float  = 16.0 * PIXEL
const SHORT_H: float = 12.0 * PIXEL
const TALL_H: float  = 24.0 * PIXEL

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

static var _registered_global_params: Dictionary = {}

var _mat: ShaderMaterial
var _lit: bool = false
var _tuft_mesh: ArrayMesh  # unit quad, billboarded per instance in the shader

var _prev_pos:      Vector3 = Vector3(-9999, 0, -9999)
var _pushed_pos:    Vector3 = Vector3.INF  # last player_pos global written
var _last_move_dir: Vector2 = Vector2.ZERO

var _trample_img:      Image
var _trample_tex:      ImageTexture
var _trample_buf:      PackedFloat32Array  # CPU-side float buffer (avoids get/set_pixel)
var _trample_bytes:    PackedByteArray     # reusable byte buffer — avoids alloc per flush
var _trample_origin_x: float = 0.0  # world-space X of pixel (0,0) in trample map
var _trample_origin_z: float = 0.0  # world-space Z of pixel (0,0) in trample map
var _trample_timer:    float = 0.0  # throttle trample updates

# Per-chunk MultiMeshInstance3D nodes — keyed by Vector2i(cx, cz)
var _chunk_mmis: Dictionary = {}

# Integer hash mapped to [0,1) — used for deterministic patch classification.
static func _hash_pos(px: float, pz: float) -> float:
	var ix: int = int(px)
	var iz: int = int(pz)
	var h: int = (ix * 374761393) ^ (iz * 668265263)
	h = (h ^ (h >> 13)) * 1274126177
	return float(abs(h) % 100000) / 100000.0

static func _ensure_global_param(name: String, type: RenderingServer.GlobalShaderParameterType,
		default_value: Variant) -> void:
	if not _registered_global_params.has(name):
		RenderingServer.global_shader_parameter_add(name, type, default_value)
		_registered_global_params[name] = true

## GID-131 / TID-508: swap to the lit grass shaders (sun shadows, real light)
## or back to the cheap unshaded ones. GraphicsQuality `lit_world` (High).
func set_lit(on: bool) -> void:
	_lit = on
	if _mat != null:
		_mat.shader = _TuftShaderLit if on else _TuftShader

func is_lit() -> bool:
	return _lit


func _init_material() -> void:
	if _mat:
		return
	_mat = ShaderMaterial.new()
	_mat.shader = _TuftShaderLit if _lit else _TuftShader
	_mat.set_shader_parameter("tuft_atlas", _TuftAtlas)
	_tuft_mesh = _make_tuft_mesh()

	# Register global shader parameters shared across all grass chunks.
	# One set-call from update_player() reaches every chunk without per-chunk overhead.
	_ensure_global_param("player_pos",       RenderingServer.GLOBAL_VAR_TYPE_VEC3,    Vector3(-9999, 0, -9999))
	_ensure_global_param("player_move_dir",  RenderingServer.GLOBAL_VAR_TYPE_VEC2,    Vector2.ZERO)
	# Day/night brightness for the unshaded grass shaders — written by DayNightCycle.
	_ensure_global_param("grass_day_tint",   RenderingServer.GLOBAL_VAR_TYPE_VEC3,    Vector3.ONE)
	_ensure_global_param("grass_wind_scale", RenderingServer.GLOBAL_VAR_TYPE_FLOAT,   1.0)
	_ensure_global_param("grass_wind_lean",  RenderingServer.GLOBAL_VAR_TYPE_FLOAT,   0.0)
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
static func compute_centres(chunk_data: _ChunkData, chunk_origin: Vector3) -> Array[Vector2]:
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

# Short-tuft count for an ordinary grass tile: squared hash, so bare and
# sparse cells are common and full ones rare.
static func _short_tufts(centre: Vector2) -> int:
	var r: float = _hash_pos(snapped(centre.x + 1000.0, SHORT_PATCH_CELL),
			snapped(centre.y + 1000.0, SHORT_PATCH_CELL))
	return int(floorf(r * r * float(TUFTS_PER_TILE_MAX + 1)))

# Build the tuft PackedFloat32Array buffer — no scene tree or GPU calls.
# Returns {} if centres is empty, otherwise the data commit_grass_buffers needs.
static func prepare_buffers(centres: Array[Vector2], chunk_key: Vector2i) -> Dictionary:
	if centres.is_empty():
		return {}
	var ts: float = IsoConst.TILE_SIZE
	var rng := RandomNumberGenerator.new()
	rng.seed = 99887 ^ (chunk_key.x * 73856093) ^ (chunk_key.y * 19349663)

	var tall_flags: Array[bool] = []
	tall_flags.resize(centres.size())
	var total: int = 0
	for ci in range(centres.size()):
		var centre: Vector2 = centres[ci]
		var is_tall: bool = _hash_pos(snapped(centre.x, TALL_PATCH_CELL),
				snapped(centre.y, TALL_PATCH_CELL)) < TALL_PATCH_DENSITY
		tall_flags[ci] = is_tall
		total += TUFTS_TALL_PER_TILE + 2 if is_tall else _short_tufts(centre)

	if total == 0:
		return {}
	var buf := PackedFloat32Array()
	buf.resize(total * 12)
	var i: int = 0
	for ci in range(centres.size()):
		var centre: Vector2 = centres[ci]
		var is_tall: bool = tall_flags[ci]
		var n: int = TUFTS_TALL_PER_TILE + 2 if is_tall else _short_tufts(centre)
		# Stratified on a 3x3 grid (random start cell) so tufts cover the tile
		# evenly instead of clumping; jitter may spill a little past the edge.
		var start: int = rng.randi_range(0, 8)
		for k in range(n):
			var cell: int = (start + k * 4) % 9
			var px: float = centre.x + (float(cell % 3) - 1.0 + rng.randf_range(-0.5, 0.5)) * ts / 3.0
			var pz: float = centre.y + (floorf(float(cell) / 3.0) - 1.0 + rng.randf_range(-0.5, 0.5)) * ts / 3.0
			var h: float = TALL_H if is_tall and k >= 2 else SHORT_H
			var off: int = i * 12
			# Basis carries the tuft size (the shader billboards it); z unused.
			buf[off] = TUFT_W;  buf[off + 1] = 0.0; buf[off + 2]  = 0.0; buf[off + 3]  = px
			buf[off + 4] = 0.0; buf[off + 5] = h;   buf[off + 6]  = 0.0; buf[off + 7]  = 0.01
			buf[off + 8] = 0.0; buf[off + 9] = 0.0; buf[off + 10] = 1.0; buf[off + 11] = pz
			i += 1
	return {"tuft_buf": buf, "tuft_count": total}

# Main-thread commit: create MultiMesh + MMI from pre-built buffers.
func commit_grass_buffers(grass_data: Dictionary, chunk_key: Vector2i, recolor := Color(1, 1, 1, 0)) -> void:
	if grass_data.is_empty() or _chunk_mmis.has(chunk_key):
		return
	_init_material()
	var chunk_world: float = IsoConst.CHUNK_SIZE * IsoConst.TILE_SIZE
	var mm := MultiMesh.new()
	mm.mesh = _tuft_mesh
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.instance_count = int(grass_data["tuft_count"])
	mm.custom_aabb = AABB(
		Vector3(chunk_key.x * chunk_world - 1.0, -0.5, chunk_key.y * chunk_world - 1.0),
		Vector3(chunk_world + 2.0, TALL_H + 1.0, chunk_world + 2.0)
	)
	mm.buffer = grass_data["tuft_buf"]
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = _mat
	mmi.visibility_range_end = VISIBILITY_END
	mmi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_DISABLED
	# Billboard quads cast misshapen shadows, and a shadow pass over thousands
	# of tufts is a full extra geometry pass for noise at 0.2 opacity.
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mmi.layers = RENDER_LAYER
	mmi.set_instance_shader_parameter("grass_recolor", recolor)  # per-biome colour (GID-134)
	add_child(mmi)
	_chunk_mmis[chunk_key] = mmi

func remove_chunk(chunk_key: Vector2i) -> void:
	if _chunk_mmis.has(chunk_key):
		var mmi: MultiMeshInstance3D = _chunk_mmis[chunk_key]
		mmi.queue_free()
		_chunk_mmis.erase(chunk_key)

func _make_tuft_mesh() -> ArrayMesh:
	# Unit quad: X from -0.5 to 0.5, Y from 0 to 1. The shader rebuilds the
	# world position from the UVs, so only the UVs really matter.
	var verts := PackedVector3Array([
		Vector3(-0.5, 0.0, 0.0), Vector3(0.5, 0.0, 0.0),
		Vector3(0.5, 1.0, 0.0), Vector3(-0.5, 1.0, 0.0),
	])
	var uvs := PackedVector2Array([
		Vector2(0.0, 0.0), Vector2(1.0, 0.0),
		Vector2(1.0, 1.0), Vector2(0.0, 1.0),
	])
	var normals := PackedVector3Array([Vector3.BACK, Vector3.BACK, Vector3.BACK, Vector3.BACK])
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_INDEX] = PackedInt32Array([0, 1, 2, 0, 2, 3])
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh

func set_wind_direction(dir: Vector2) -> void:
	# Trees and plants lean the same way (prop_sway shader, TID-647).
	RenderingServer.global_shader_parameter_set("plant_wind_dir", dir)
	if _mat:
		_mat.set_shader_parameter("wind_direction", dir)

func update_player(pos: Vector3, delta: float, is_grounded: bool) -> void:
	if not _mat:
		return

	# Immediate blade push — single global call reaches all chunks at once;
	# skipped while the hero stands still (GID-164 / TID-678).
	var push: Vector3 = pos if is_grounded else Vector3(-9999.0, 0.0, -9999.0)
	if push != _pushed_pos:
		_pushed_pos = push
		RenderingServer.global_shader_parameter_set("player_pos", push)

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
	var changed: bool = false  # upload only when a texel moved (GID-164 / TID-678)

	# Decay + stamp on the float buffer — no Color allocations
	for z in range(z0, z1 + 1):
		var row: int = z * TRAMPLE_RES
		for x in range(x0, x1 + 1):
			var v: float = _trample_buf[row + x]
			if v > 0.0:
				var nv: float = maxf(TRAMPLE_FLOOR, v - decay_amount)
				_trample_buf[row + x] = nv
				var b: int = int(clampf(nv, 0.0, 1.0) * 255.0)
				if b != _trample_bytes[row + x]:
					_trample_bytes[row + x] = b
					changed = true

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
				var b2: int = int(clampf(nv, 0.0, 1.0) * 255.0)
				if b2 != _trample_bytes[row + x]:
					_trample_bytes[row + x] = b2
					changed = true

	if changed:
		_flush_trample_to_gpu()

# Upload only the dirty region of the trample map to the GPU.
# _trample_bytes is kept in sync during _update_trample_map so no
# separate float→byte conversion loop is needed.
func _flush_trample_to_gpu() -> void:
	_trample_img.set_data(TRAMPLE_RES, TRAMPLE_RES, false, Image.FORMAT_L8, _trample_bytes)
	_trample_tex.update(_trample_img)
