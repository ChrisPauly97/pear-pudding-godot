extends Node3D

var _mat: ShaderMaterial

const TRAIL_SIZE     := 8
const TRAIL_INTERVAL := 0.08   # seconds between trail snapshots
const SPRINGBACK     := 0.6    # higher = faster spring-back

var _trail:      Array[Vector3] = []
var _trail_ages: Array[float]   = []
var _snap_timer: float          = 0.0
var _prev_pos:   Vector3        = Vector3(-9999, 0, -9999)

# Sliding trample window: 64x64 pixel image, player-centred, shifts when
# the player moves more than TRAMPLE_SHIFT_TILES tiles from the window centre.
const TRAMPLE_RES         := 64   # pixels (tiles)
const TRAMPLE_SHIFT_TILES := 16   # shift window after this many tiles of drift
const TRAMPLE_RADIUS      := 1    # pixel radius of player stamp
const TRAMPLE_DECAY       := 0.02 # per-second decay rate
const TRAMPLE_FLOOR       := 0.3  # trampled grass never recovers past this
const TRAMPLE_RAMP        := 1.5  # per-second ramp-up rate

var _trample_img:      Image
var _trample_tex:      ImageTexture
var _trample_origin_x: float = 0.0  # world-space X of pixel (0,0) in trample map
var _trample_origin_z: float = 0.0  # world-space Z of pixel (0,0) in trample map

const BLADES_PER_TILE := 50
const BLADE_WIDTH      := 0.28
const BLADE_HEIGHT     := 1.1
const SEGMENTS         := 4  # quads along the blade height

const CHUNK_SIZE := 16  # tiles per chunk side — one MultiMesh per chunk

# Per-chunk MultiMeshInstance3D nodes — keyed by Vector2i(cx, cz)
var _chunk_mmis: Dictionary = {}

func _ready() -> void:
	var far := Vector3(-9999.0, 0.0, -9999.0)
	for i in TRAIL_SIZE:
		_trail.append(far)
		_trail_ages.append(999.0)

func _init_material() -> void:
	if _mat:
		return
	_mat = ShaderMaterial.new()
	_mat.shader = load("res://assets/shaders/grass_blade.gdshader")

	# Sliding trample map — initialise centred at world origin
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
	var blade_mesh := _make_blade_mesh()
	var rng        := RandomNumberGenerator.new()
	rng.seed = 99887
	var half:    float = IsoConst.TILE_SIZE * 0.45

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
		_build_chunk_mmi(centres, typed_key, blade_mesh, rng)

# Streaming entry point — builds grass for one chunk of the infinite world
func build_chunk(centres: Array[Vector2], chunk_key: Vector2i) -> void:
	if _chunk_mmis.has(chunk_key):
		return
	_init_material()
	var blade_mesh := _make_blade_mesh()
	var rng := RandomNumberGenerator.new()
	rng.seed = 99887 ^ (chunk_key.x * 73856093) ^ (chunk_key.y * 19349663)
	var plain: Array = []
	for c in centres:
		plain.append(c)
	_build_chunk_mmi(plain, chunk_key, blade_mesh, rng)

func remove_chunk(chunk_key: Vector2i) -> void:
	if _chunk_mmis.has(chunk_key):
		var mmi: MultiMeshInstance3D = _chunk_mmis[chunk_key]
		mmi.queue_free()
		_chunk_mmis.erase(chunk_key)

func _build_chunk_mmi(centres: Array, chunk_key: Vector2i, blade_mesh: ArrayMesh, rng: RandomNumberGenerator) -> void:
	var total: int = centres.size() * BLADES_PER_TILE
	if total == 0:
		return

	var half: float = IsoConst.TILE_SIZE * 0.45
	var blade_y: float = 0.01

	var mm := MultiMesh.new()
	mm.mesh = blade_mesh
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
			var sc: float  = rng.randf_range(0.4, 1.6)
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
		Vector3(chunk_world, BLADE_HEIGHT + 1.5, chunk_world)
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

	# Age all trail entries
	for i in TRAIL_SIZE:
		_trail_ages[i] += delta

	if is_grounded:
		var moved: float = Vector2(pos.x - _trail[0].x, pos.z - _trail[0].z).length()
		_snap_timer += delta
		if _snap_timer >= TRAIL_INTERVAL and moved > 0.1:
			_snap_timer = 0.0
			_trail.pop_back()
			_trail_ages.pop_back()
			_trail.push_front(pos)
			_trail_ages.push_front(0.0)
		else:
			_trail[0] = pos
			_trail_ages[0] = 0.0

	# Compute decaying weights
	var weights: Array[float] = []
	for i in TRAIL_SIZE:
		weights.append(exp(-_trail_ages[i] * SPRINGBACK))

	# Movement direction
	var move_dir := Vector2.ZERO
	var dp: float = _trail[0].distance_to(_prev_pos)
	if dp > 0.05:
		move_dir = Vector2(_trail[0].x - _prev_pos.x, _trail[0].z - _prev_pos.z).normalized()
	_prev_pos = _trail[0]

	_mat.set_shader_parameter("player_trail", _trail)
	_mat.set_shader_parameter("trail_weights", weights)
	_mat.set_shader_parameter("player_move_dir", move_dir)

	if is_grounded and _trample_img:
		_maybe_shift_trample_window(pos)
		_update_trample_map(pos, delta)

# Shift the trample window when the player drifts far from the window centre
func _maybe_shift_trample_window(pos: Vector3) -> void:
	var tile_size: float = IsoConst.TILE_SIZE
	var window_world: float = TRAMPLE_RES * tile_size
	var centre_x: float = _trample_origin_x + window_world * 0.5
	var centre_z: float = _trample_origin_z + window_world * 0.5
	var shift_world: float = TRAMPLE_SHIFT_TILES * tile_size

	if abs(pos.x - centre_x) < shift_world and abs(pos.z - centre_z) < shift_world:
		return

	# Compute new origin (player near centre of new window)
	var new_ox: float = pos.x - window_world * 0.5
	var new_oz: float = pos.z - window_world * 0.5

	# Pixel-level offset of old origin relative to new origin
	var dx: int = int(round((_trample_origin_x - new_ox) / tile_size))
	var dz: int = int(round((_trample_origin_z - new_oz) / tile_size))

	var new_img := Image.create(TRAMPLE_RES, TRAMPLE_RES, false, Image.FORMAT_L8)
	new_img.fill(Color(0, 0, 0))

	# Copy the still-visible region of the old image into the new image
	for z in range(TRAMPLE_RES):
		for x in range(TRAMPLE_RES):
			var old_x: int = x - dx
			var old_z: int = z - dz
			if old_x >= 0 and old_x < TRAMPLE_RES and old_z >= 0 and old_z < TRAMPLE_RES:
				new_img.set_pixel(x, z, _trample_img.get_pixel(old_x, old_z))

	_trample_img = new_img
	_trample_origin_x = new_ox
	_trample_origin_z = new_oz
	_trample_tex.update(_trample_img)
	_mat.set_shader_parameter("trample_origin_x", _trample_origin_x)
	_mat.set_shader_parameter("trample_origin_z", _trample_origin_z)

func _update_trample_map(pos: Vector3, delta: float) -> void:
	var tile_size: float = IsoConst.TILE_SIZE
	# Player position in trample-image pixel space
	var px: int = int((pos.x - _trample_origin_x) / tile_size)
	var pz: int = int((pos.z - _trample_origin_z) / tile_size)

	var decay_r: int = TRAMPLE_RADIUS + 8
	var x0: int = max(0, px - decay_r)
	var x1: int = min(TRAMPLE_RES - 1, px + decay_r)
	var z0: int = max(0, pz - decay_r)
	var z1: int = min(TRAMPLE_RES - 1, pz + decay_r)

	var decay_amount: float = TRAMPLE_DECAY * delta

	for z in range(z0, z1 + 1):
		for x in range(x0, x1 + 1):
			var v: float = _trample_img.get_pixel(x, z).r
			if v > 0.0:
				var new_v: float = max(TRAMPLE_FLOOR, v - decay_amount)
				_trample_img.set_pixel(x, z, Color(new_v, new_v, new_v))

	var ramp: float = TRAMPLE_RAMP * delta
	for z in range(max(0, pz - TRAMPLE_RADIUS), min(TRAMPLE_RES, pz + TRAMPLE_RADIUS + 1)):
		for x in range(max(0, px - TRAMPLE_RADIUS), min(TRAMPLE_RES, px + TRAMPLE_RADIUS + 1)):
			var dist: float = Vector2(x - px, z - pz).length()
			if dist <= TRAMPLE_RADIUS:
				var target: float = 1.0 - dist / (TRAMPLE_RADIUS + 1.0)
				var cur: float = _trample_img.get_pixel(x, z).r
				var new_v: float = min(target, cur + ramp)
				_trample_img.set_pixel(x, z, Color(new_v, new_v, new_v))

	_trample_tex.update(_trample_img)

func _make_blade_mesh() -> ArrayMesh:
	var verts   := PackedVector3Array()
	var uvs     := PackedVector2Array()
	var normals := PackedVector3Array()
	var indices := PackedInt32Array()

	var width_profile: Array[float] = [1.0, 0.80, 0.45, 0.08]

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
