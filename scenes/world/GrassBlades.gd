extends Node3D

var _mat: ShaderMaterial

const TRAIL_SIZE     := 8
const TRAIL_INTERVAL := 0.08   # seconds between trail snapshots
const SPRINGBACK     := 0.6    # higher = faster spring-back

var _trail:      Array[Vector3] = []
var _trail_ages: Array[float]   = []
var _snap_timer: float          = 0.0
var _prev_pos:   Vector3        = Vector3(-9999, 0, -9999)

# Persistent trample map — one pixel per tile, never fully resets
const TRAMPLE_RES     := 100   # pixels (matches MAP_WIDTH/HEIGHT)
const TRAMPLE_RADIUS  := 2     # pixel radius of player stamp
const TRAMPLE_DECAY   := 0.02  # per-second decay rate
const TRAMPLE_FLOOR   := 0.3   # trampled grass never recovers past this
var _trample_img:    Image
var _trample_tex:    ImageTexture

const BLADES_PER_TILE := 50
const BLADE_WIDTH      := 0.28
const BLADE_HEIGHT     := 1.1
const SEGMENTS         := 4  # quads along the blade height

const CHUNK_SIZE := 10  # tiles per chunk side — one MultiMesh per chunk

func _ready() -> void:
	var far := Vector3(-9999.0, 0.0, -9999.0)
	for i in TRAIL_SIZE:
		_trail.append(far)
		_trail_ages.append(999.0)

func build(world_map) -> void:
	_mat = ShaderMaterial.new()
	_mat.shader = load("res://assets/shaders/grass_blade.gdshader")

	var blade_mesh := _make_blade_mesh()
	var rng        := RandomNumberGenerator.new()
	rng.seed = 99887
	var half:    float = IsoConst.TILE_SIZE * 0.45
	var blade_y: float = 0.01

	# Collect grass tile centres grouped by chunk
	# chunk key = Vector2i(cx, cz)
	var chunks: Dictionary = {}

	for tz in range(world_map.MAP_HEIGHT):
		for tx in range(world_map.MAP_WIDTH):
			if world_map.get_tile(tx, tz) != world_map.TILE_GRASS:
				continue
			# Skip grass tiles directly adjacent to walls to avoid blades clipping through
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

	# Build one MultiMeshInstance3D per chunk
	for key in chunks:
		var centres: Array = chunks[key]
		var total: int = centres.size() * BLADES_PER_TILE

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

		# Custom AABB covers the chunk footprint + blade height + push headroom
		var cx: int = key.x
		var cz: int = key.y
		var chunk_world: float = CHUNK_SIZE * IsoConst.TILE_SIZE
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
			# Player has moved enough — shift trail and record new snapshot
			_snap_timer = 0.0
			_trail.pop_back()
			_trail_ages.pop_back()
			_trail.push_front(pos)
			_trail_ages.push_front(0.0)
		else:
			# Stationary (or barely moved) — pin current position at full weight
			_trail[0] = pos
			_trail_ages[0] = 0.0
	# Airborne: do nothing — trail ages naturally, grass springs back on its own

	# Compute decaying weights
	var weights: Array[float] = []
	for i in TRAIL_SIZE:
		weights.append(exp(-_trail_ages[i] * SPRINGBACK))

	# Movement direction from current vs previous grounded snapshot
	var move_dir := Vector2.ZERO
	var dp: float = _trail[0].distance_to(_prev_pos)
	if dp > 0.05:
		move_dir = Vector2(_trail[0].x - _prev_pos.x, _trail[0].z - _prev_pos.z).normalized()
	_prev_pos = _trail[0]

	_mat.set_shader_parameter("player_trail", _trail)
	_mat.set_shader_parameter("trail_weights", weights)
	_mat.set_shader_parameter("player_move_dir", move_dir)

func _make_blade_mesh() -> ArrayMesh:
	# Segmented blade: SEGMENTS quads tapering to a tip triangle.
	# 2 verts per row × SEGMENTS rows + 1 tip = SEGMENTS*2+1 vertices total.
	var verts   := PackedVector3Array()
	var uvs     := PackedVector2Array()
	var normals := PackedVector3Array()
	var indices := PackedInt32Array()

	# Width profile: leaf-like — holds width longer before tapering
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

	# Tip vertex
	verts.append(Vector3(0.0, BLADE_HEIGHT, 0.0))
	uvs.append(Vector2(0.5, 1.0))
	normals.append(Vector3(0.0, 0.0, 1.0))

	# Quads between consecutive rows
	for row in range(SEGMENTS - 1):
		var b := row * 2
		indices.append_array([b, b+1, b+2,  b+1, b+3, b+2])

	# Final triangle to tip
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
