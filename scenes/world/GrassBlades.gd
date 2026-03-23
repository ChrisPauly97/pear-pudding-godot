extends Node3D

const _GrassShader = preload("res://assets/shaders/grass_blade.gdshader")

var _mat: ShaderMaterial
var _blade_mesh: ArrayMesh  # cached — identical for every chunk

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
var _trample_dirty_x0: int = TRAMPLE_RES  # dirty rect tracking
var _trample_dirty_z0: int = TRAMPLE_RES
var _trample_dirty_x1: int = 0
var _trample_dirty_z1: int = 0
const TRAMPLE_UPDATE_INTERVAL: float = 0.2  # ~5 Hz — was 15 Hz, barely visible difference

const BLADES_PER_TILE := 20
const BLADE_WIDTH      := 0.26
const BLADE_HEIGHT     := 1.6
const SEGMENTS         := 4  # quads along the blade height

const CHUNK_SIZE := 16  # tiles per chunk side — one MultiMesh per chunk

# Per-chunk MultiMeshInstance3D nodes — keyed by Vector2i(cx, cz)
var _chunk_mmis: Dictionary = {}

func _init_material() -> void:
	if _mat:
		return
	_mat = ShaderMaterial.new()
	_mat.shader = _GrassShader
	_blade_mesh = _make_blade_mesh()

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

	_mat.set_shader_parameter("trample_map", _trample_tex)
	var window_world: float = TRAMPLE_RES * IsoConst.TILE_SIZE
	_mat.set_shader_parameter("trample_map_size", window_world)
	_mat.set_shader_parameter("trample_origin_x", _trample_origin_x)
	_mat.set_shader_parameter("trample_origin_z", _trample_origin_z)

# Legacy entry point — builds all grass from a WorldMap (named-map path)
func build(world_map) -> void:
	_init_material()
	var rng := RandomNumberGenerator.new()
	rng.seed = 99887

	# Collect grass tile centres grouped by chunk
	var chunks: Dictionary = {}

	for tz in range(world_map.MAP_HEIGHT):
		for tx in range(world_map.MAP_WIDTH):
			if world_map.get_tile(tx, tz) != world_map.TILE_GRASS:
				continue
			var next_to_wall := false
			for n in [Vector2i(tx+1,tz), Vector2i(tx-1,tz), Vector2i(tx,tz+1), Vector2i(tx,tz-1)]:
				if world_map.get_tile(n.x, n.y) == world_map.TILE_WALL:
					next_to_wall = true
					break
			if next_to_wall:
				continue
			var cx: int = tx / CHUNK_SIZE
			var cz: int = tz / CHUNK_SIZE
			var key := Vector2i(cx, cz)
			if not chunks.has(key):
				chunks[key] = []
			chunks[key].append(Vector2(
				tx * IsoConst.TILE_SIZE + IsoConst.TILE_SIZE * 0.5,
				tz * IsoConst.TILE_SIZE + IsoConst.TILE_SIZE * 0.5
			))

	for key in chunks:
		var typed_key: Vector2i = key
		var centres: Array = chunks[key]
		_build_chunk_mmi(centres, typed_key, rng)

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

func _build_chunk_mmi(centres: Array, chunk_key: Vector2i, rng: RandomNumberGenerator) -> void:
	var total: int = centres.size() * BLADES_PER_TILE
	if total == 0:
		return

	var half: float = IsoConst.TILE_SIZE * 0.45
	var blade_y: float = 0.01

	var mm := MultiMesh.new()
	mm.mesh = _blade_mesh
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.instance_count = total

	var buf := PackedFloat32Array()
	buf.resize(total * 12)
	var i: int = 0

	for centre in centres:
		for _b in range(BLADES_PER_TILE):
			var px: float = centre.x + rng.randf_range(-half, half)
			var pz: float = centre.y + rng.randf_range(-half, half)
			var rot: float = rng.randf_range(0.0, PI)
			var sc: float  = rng.randf_range(0.45, 1.75)
			var cr: float  = cos(rot) * sc
			var sr: float  = sin(rot) * sc
			var off: int   = i * 12
			buf[off]     =  cr;  buf[off+1]  = 0.0; buf[off+2]  =  sr;  buf[off+3]  = px
			buf[off+4]   = 0.0;  buf[off+5]  =  sc; buf[off+6]  = 0.0;  buf[off+7]  = blade_y
			buf[off+8]   = -sr;  buf[off+9]  = 0.0; buf[off+10] =  cr;  buf[off+11] = pz
			i += 1

	var chunk_world: float = CHUNK_SIZE * IsoConst.TILE_SIZE
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
	mmi.visibility_range_end = 70.0
	mmi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_DISABLED
	add_child(mmi)
	_chunk_mmis[chunk_key] = mmi

func update_player(pos: Vector3, delta: float, is_grounded: bool) -> void:
	if not _mat:
		return

	# Immediate blade push — just pass current position
	_mat.set_shader_parameter("player_pos", pos if is_grounded else Vector3(-9999.0, 0.0, -9999.0))

	# Movement direction — only upload when it changes
	var move_dir := Vector2.ZERO
	var dp_sq: float = Vector2(pos.x - _prev_pos.x, pos.z - _prev_pos.z).length_squared()
	if dp_sq > 0.0025:  # 0.05 units threshold
		move_dir = Vector2(pos.x - _prev_pos.x, pos.z - _prev_pos.z).normalized()
	_prev_pos = pos
	if move_dir != _last_move_dir:
		_mat.set_shader_parameter("player_move_dir", move_dir)
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
	# Mark entire buffer dirty for the full flush
	_trample_dirty_x0 = 0
	_trample_dirty_z0 = 0
	_trample_dirty_x1 = TRAMPLE_RES - 1
	_trample_dirty_z1 = TRAMPLE_RES - 1
	_flush_trample_to_gpu()
	_mat.set_shader_parameter("trample_origin_x", _trample_origin_x)
	_mat.set_shader_parameter("trample_origin_z", _trample_origin_z)

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

	# Track dirty rect — only the region we just touched
	_trample_dirty_x0 = mini(_trample_dirty_x0, x0)
	_trample_dirty_z0 = mini(_trample_dirty_z0, z0)
	_trample_dirty_x1 = maxi(_trample_dirty_x1, x1)
	_trample_dirty_z1 = maxi(_trample_dirty_z1, z1)

	_flush_trample_to_gpu()

# Upload only the dirty region of the trample map to the GPU.
# _trample_bytes is kept in sync during _update_trample_map so no
# separate float→byte conversion loop is needed.
func _flush_trample_to_gpu() -> void:
	if _trample_dirty_x0 > _trample_dirty_x1:
		return  # nothing dirty
	_trample_img.set_data(TRAMPLE_RES, TRAMPLE_RES, false, Image.FORMAT_L8, _trample_bytes)
	_trample_tex.update(_trample_img)
	# Reset dirty rect
	_trample_dirty_x0 = TRAMPLE_RES
	_trample_dirty_z0 = TRAMPLE_RES
	_trample_dirty_x1 = 0
	_trample_dirty_z1 = 0

func _make_blade_mesh() -> ArrayMesh:
	var verts   := PackedVector3Array()
	var uvs     := PackedVector2Array()
	var normals := PackedVector3Array()
	var indices := PackedInt32Array()

	var width_profile: Array[float] = [1.0, 0.72, 0.38, 0.10]

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

	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX]  = verts
	arrays[Mesh.ARRAY_TEX_UV]  = uvs
	arrays[Mesh.ARRAY_NORMAL]  = normals
	arrays[Mesh.ARRAY_INDEX]   = indices

	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh
