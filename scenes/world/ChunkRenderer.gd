extends Node3D

const GrassBlades   = preload("res://scenes/world/GrassBlades.gd")
const TerrainMath   = preload("res://game_logic/TerrainMath.gd")
const BiomeDef      = preload("res://game_logic/world/BiomeDef.gd")

# Preload entity scenes once, not per-spawn
const _EnemyScene        = preload("res://scenes/world/entities/EnemyNPC.tscn")
const _ChestScene        = preload("res://scenes/world/entities/Chest.tscn")
const _DoorScene         = preload("res://scenes/world/entities/Door.tscn")
const _TownspersonScene  = preload("res://scenes/world/entities/TownspersonNPC.tscn")
const _MerchantScene     = preload("res://scenes/world/entities/MerchantNPC.tscn")
const _StoryScrollScene  = preload("res://scenes/world/entities/StoryScroll.tscn")
const InfiniteWorldGen   = preload("res://game_logic/world/InfiniteWorldGen.gd")

const TERRAIN_VDENSITY: int = 2
const PLATEAU_H:        float = 1.5   # fallback hill height for tiles with no stored height
const CURVE_R:          float = 3.5   # hill smoothstep radius (world units)
const WALL_CURVE_R:     float = 0.4   # wall rise radius — sub-vertex-step so walls are near-vertical

# Tile neighbourhood radius used when building the tile_grid snapshot.
# Must match what WorldScene._snapshot_tile_grid_for() uses.
const TILE_CHECK: int = 3  # ceil(CURVE_R / TILE_SIZE) + 1 = ceil(3.5/2)+1 = 3

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
		height_grid: PackedInt32Array,
		grid_min_x: int, grid_min_z: int, grid_w: int) -> Dictionary:

	const CHUNK_SIZE: int = 16
	var nvx: int = CHUNK_SIZE * TERRAIN_VDENSITY + 1   # 33
	var nvz: int = CHUNK_SIZE * TERRAIN_VDENSITY + 1   # 33
	var step: float = IsoConst.TILE_SIZE / float(TERRAIN_VDENSITY)  # 1.0

	var chunk_origin: Vector3 = chunk_data.origin_world()

	# Build a tile lookup that reads from the pre-snapshotted packed grid
	var grid_tile_lookup := func(ttx: int, ttz: int) -> int:
		var li: int = (ttz - grid_min_z) * grid_w + (ttx - grid_min_x)
		if li < 0 or li >= tile_grid.size():
			return IsoConst.TILE_WALL
		return tile_grid[li]

	# Build a height lookup that reads from the pre-snapshotted packed grid
	var grid_height_lookup := func(ttx: int, ttz: int) -> int:
		var li: int = (ttz - grid_min_z) * grid_w + (ttx - grid_min_x)
		if li < 0 or li >= height_grid.size():
			return 1
		return height_grid[li]

	var hfield: PackedFloat32Array = TerrainMath.compute_height_field(
			grid_tile_lookup, grid_height_lookup,
			chunk_origin.x, chunk_origin.z,
			nvx, nvz, step,
			CURVE_R, PLATEAU_H, WALL_CURVE_R)

	var terrain_res: Dictionary = TerrainMath.build_terrain_mesh(
			hfield, grid_tile_lookup,
			chunk_origin.x, chunk_origin.z,
			nvx, nvz, step, PLATEAU_H)

	var wall_face_mesh: ArrayMesh = TerrainMath.build_wall_face_mesh(
			grid_tile_lookup, grid_height_lookup,
			chunk_origin.x, chunk_origin.z,
			CHUNK_SIZE, CHUNK_SIZE)

	return {
		"mesh":           terrain_res["mesh"],
		"hmap":           terrain_res["hmap"],
		"chunk_world":    float(CHUNK_SIZE) * IsoConst.TILE_SIZE,
		"wall_face_mesh": wall_face_mesh,
	}

# ── Main entry point (main thread only) ───────────────────────────────────
# Phase 1: visual mesh + entities only — no physics bodies — call from _commit_chunk_results.
func build_visual(chunk_data: RefCounted, chunk_key: Vector2i, world_scene: Node3D,
		terrain_mat: ShaderMaterial, terrain_res: Dictionary) -> void:
	_chunk_data          = chunk_data
	_chunk_key           = chunk_key
	_terrain_hmap        = terrain_res["hmap"]
	_terrain_chunk_world = terrain_res["chunk_world"]
	position = chunk_data.origin_world()

	# Duplicate the shared template so each chunk has independent shader parameters.
	var biome: int = chunk_data.biome_id
	var mat: ShaderMaterial = terrain_mat.duplicate()
	var gt: Color = BiomeDef.GRASS_TINT[biome]
	var ht: Color = BiomeDef.HILL_TINT[biome]
	var wt: Color = BiomeDef.WALL_TINT[biome]
	mat.set_shader_parameter("grass_tint", Vector3(gt.r, gt.g, gt.b))
	mat.set_shader_parameter("hill_tint",  Vector3(ht.r, ht.g, ht.b))
	mat.set_shader_parameter("wall_tint",  Vector3(wt.r, wt.g, wt.b))
	_terrain_mat = mat

	_apply_terrain_visual(terrain_res)
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
	var wall_face_mesh: ArrayMesh = res.get("wall_face_mesh") as ArrayMesh
	if wall_face_mesh != null and wall_face_mesh.get_surface_count() > 0:
		var wall_mi := MeshInstance3D.new()
		wall_mi.mesh = wall_face_mesh
		wall_mi.material_override = _terrain_mat
		add_child(wall_mi)

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
					var top_y: float = float(run_h) * IsoConst.WALL_FACE_H
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
		if SceneManager.save_manager.is_enemy_defeated(eid):
			continue
		var node: Node3D = TerrainMath.spawn_entity(_EnemyScene, e_data, 0.5, entity_root, world_scene)
		_set_visibility_range(node)
		if world_scene.has_method("register_enemy"):
			world_scene.register_enemy(e_data["id"], node)

	for c_data in _chunk_data.chests:
		var cid: String = str(c_data.get("id", ""))
		if SceneManager.save_manager.is_chest_opened(cid):
			c_data["opened"] = true
		var node: Node3D = TerrainMath.spawn_entity(_ChestScene, c_data, 0.25, entity_root, world_scene)
		_set_visibility_range(node)
		if world_scene.has_method("register_chest"):
			world_scene.register_chest(c_data["id"], node, c_data)

	for d_data in _chunk_data.doors:
		var node: Node3D = TerrainMath.spawn_entity(_DoorScene, d_data, 0.75, entity_root, world_scene)
		_set_visibility_range(node)
		if world_scene.has_method("register_door"):
			world_scene.register_door(d_data["id"], node, d_data)

	for n_data in _chunk_data.npcs:
		var scene_to_use: PackedScene = _MerchantScene if str(n_data.get("npc_type", "")) == "merchant" else _TownspersonScene
		var node: Node3D = scene_to_use.instantiate()
		var ny: float = world_scene.get_terrain_height(float(n_data["x"]), float(n_data["z"])) + 0.5
		node.position = Vector3(n_data["x"], ny, n_data["z"])
		if node.has_method("init_from_data"):
			node.init_from_data(n_data)
		entity_root.add_child(node)
		_set_visibility_range(node)
		if world_scene.has_method("register_npc"):
			world_scene.register_npc(n_data["id"], node, n_data)
		print("NPC spawned: ", n_data.get("id", "?"), " (", n_data.get("npc_type", "townsperson"), ") at world (", n_data["x"], ", ", n_data["z"], ")")

	# ── Infinite-world scroll (seed-deterministic, 1 per ~200 chunks) ─────────
	var cx: int = _chunk_key.x
	var cz: int = _chunk_key.y
	var world_seed: int = 42
	if world_scene.get("WORLD_SEED") != null:
		world_seed = int(world_scene.get("WORLD_SEED"))
	var scroll_id: String = InfiniteWorldGen.get_chunk_scroll_id(cx, cz, world_seed)
	if scroll_id != "" and not SceneManager.save_manager.is_scroll_collected(scroll_id):
		var h: int = (cx * 73856093) ^ (cz * 19349663) ^ world_seed
		h = h & 0x7FFFFFFF
		var lx: int = (h >> 8) % IsoConst.CHUNK_SIZE
		var lz: int = (h >> 16) % IsoConst.CHUNK_SIZE
		if _chunk_data.get_tile(lx, lz) == IsoConst.TILE_GRASS:
			var origin: Vector3 = _chunk_data.origin_world()
			var wx: float = origin.x + float(lx) * IsoConst.TILE_SIZE + IsoConst.TILE_SIZE * 0.5
			var wz: float = origin.z + float(lz) * IsoConst.TILE_SIZE + IsoConst.TILE_SIZE * 0.5
			var wy: float = world_scene.get_terrain_height(wx, wz) + 0.1
			var scroll_node: Node3D = _StoryScrollScene.instantiate() as Node3D
			entity_root.add_child(scroll_node)
			scroll_node.position = Vector3(wx, wy, wz)
			var player: Node3D = null
			if world_scene.has_method("get_player"):
				player = world_scene.get_player() as Node3D
			if scroll_node.has_method("setup"):
				scroll_node.setup(scroll_id, player)
			if is_instance_valid(scroll_node) and world_scene.has_method("register_scroll"):
				world_scene.register_scroll(scroll_node)

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
