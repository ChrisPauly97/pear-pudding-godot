class_name WorldMap
extends RefCounted

const EnemyRegistry = preload("res://autoloads/EnemyRegistry.gd")
const ChunkData = preload("res://game_logic/world/ChunkData.gd")

# Aliases for IsoConst tile types — avoids breaking existing references
const TILE_GRASS: int = IsoConst.TILE_GRASS
const TILE_WALL: int = IsoConst.TILE_WALL
const TILE_HILL: int = IsoConst.TILE_HILL
const MAP_WIDTH: int = 100
const MAP_HEIGHT: int = 100
const TILE_SIZE: float = IsoConst.TILE_SIZE

var map_name: String
var tiles: Array[Array] = []     # [y][x] of int
var heights: Array[Array] = []   # [y][x] of int
var enemies: Array[Dictionary] = []   # Array of WorldEntityData dicts
var chests: Array[Dictionary] = []    # Array of WorldEntityData dicts
var doors: Array[Dictionary] = []     # Array of door dicts
var npcs: Array[Dictionary] = []      # Array of npc dicts
var player_spawn_x: int = -1
var player_spawn_z: int = -1

func _init(p_name: String = "main") -> void:
	map_name = p_name
	_alloc_grids()

	# Try loading from user:// first, then res://
	var user_path := "user://maps/%s.txt" % map_name
	var res_path := "res://assets/maps/%s.txt" % map_name

	if FileAccess.file_exists(user_path):
		load_from_file(user_path)
	elif FileAccess.file_exists(res_path):
		load_from_file(res_path)
	else:
		_build_default_map()

func _alloc_grids() -> void:
	tiles = []
	heights = []
	for _y in range(MAP_HEIGHT):
		var tr: Array[int] = []
		var hr: Array[int] = []
		for _x in range(MAP_WIDTH):
			tr.append(TILE_GRASS)
			hr.append(0)
		tiles.append(tr)
		heights.append(hr)

func get_tile(tx: int, tz: int) -> int:
	if tx < 0 or tx >= MAP_WIDTH or tz < 0 or tz >= MAP_HEIGHT:
		return TILE_WALL
	return tiles[tz][tx]

func get_height(tx: int, tz: int) -> int:
	if tx < 0 or tx >= MAP_WIDTH or tz < 0 or tz >= MAP_HEIGHT:
		return 1
	return heights[tz][tx]

func set_tile(tx: int, tz: int, value: int) -> void:
	if tx >= 0 and tx < MAP_WIDTH and tz >= 0 and tz < MAP_HEIGHT:
		tiles[tz][tx] = value

func set_height(tx: int, tz: int, h: int) -> void:
	if tx >= 0 and tx < MAP_WIDTH and tz >= 0 and tz < MAP_HEIGHT:
		heights[tz][tx] = h

func is_wall_at_world(wx: float, wz: float) -> bool:
	var tx := int(wx / TILE_SIZE)
	var tz := int(wz / TILE_SIZE)
	return get_tile(tx, tz) == TILE_WALL

func get_wall_height_at_world(wx: float, wz: float) -> int:
	var tx := int(wx / TILE_SIZE)
	var tz := int(wz / TILE_SIZE)
	if get_tile(tx, tz) == TILE_WALL:
		return get_height(tx, tz)
	return 0

func get_hill_height_at_world(wx: float, wz: float) -> int:
	var tx := int(wx / TILE_SIZE)
	var tz := int(wz / TILE_SIZE)
	if get_tile(tx, tz) == TILE_HILL:
		return get_height(tx, tz)
	return 0

func has_player_spawn() -> bool:
	return player_spawn_x >= 0 and player_spawn_z >= 0

func find_nearby_enemy(px: float, pz: float, range_dist: float) -> Dictionary:
	var range_sq: float = range_dist * range_dist
	for e in enemies:
		if e.get("alive", true):
			var dx: float = e["x"] - px
			var dz: float = e["z"] - pz
			if dx * dx + dz * dz <= range_sq:
				return e
	return {}

func find_nearby_chest(px: float, pz: float, range_dist: float) -> Dictionary:
	var range_sq: float = range_dist * range_dist
	for c in chests:
		if not c.get("opened", false):
			var dx: float = c["x"] - px
			var dz: float = c["z"] - pz
			if dx * dx + dz * dz <= range_sq:
				return c
	return {}

func find_nearby_door(px: float, pz: float, range_dist: float) -> Dictionary:
	var range_sq: float = range_dist * range_dist
	for d in doors:
		var dx: float = d["x"] - px
		var dz: float = d["z"] - pz
		if dx * dx + dz * dz <= range_sq:
			return d
	return {}

func find_nearby_npc(px: float, pz: float, range_dist: float) -> Dictionary:
	var range_sq: float = range_dist * range_dist
	for n in npcs:
		var dx: float = n["x"] - px
		var dz: float = n["z"] - pz
		if dx * dx + dz * dz <= range_sq:
			return n
	return {}

func find_door_by_id(door_id: String) -> Dictionary:
	for d in doors:
		if d.get("id", "") == door_id:
			return d
	return {}

func all_enemies_defeated() -> bool:
	for e in enemies:
		if e.get("alive", true):
			return false
	return true

# ── Save / Load ──────────────────────────────────────────────────────────────

func save_to_file(path: String) -> void:
	# Ensure directory exists
	var dir_path := path.get_base_dir()
	DirAccess.make_dir_recursive_absolute(dir_path)

	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		push_error("Cannot write map file: %s" % path)
		return

	f.store_line("%d %d" % [MAP_WIDTH, MAP_HEIGHT])
	for tz in range(MAP_HEIGHT):
		var row := ""
		for tx in range(MAP_WIDTH):
			row += str(tiles[tz][tx])
		f.store_line(row)

	f.store_line("HEIGHTS")
	for tz in range(MAP_HEIGHT):
		for tx in range(MAP_WIDTH):
			if tiles[tz][tx] != TILE_GRASS:
				f.store_line("%d,%d,%d" % [tx, tz, heights[tz][tx]])

	if has_player_spawn():
		f.store_line("SPAWN %d %d" % [player_spawn_x, player_spawn_z])

	for e in enemies:
		f.store_line("ENEMY %d %d" % [int(e["x"]), int(e["z"])])

	for c in chests:
		var card_str := ",".join(c.get("card_ids", []))
		f.store_line("CHEST %d %d %s" % [int(c["x"]), int(c["z"]), card_str])

	for d in doors:
		var target: String = d.get("target_map", "")
		if target.is_empty():
			target = "__exit__"
		var tdoor: String = d.get("target_door_id", "")
		if tdoor.is_empty():
			f.store_line("DOOR %d %d %s" % [int(d["x"]), int(d["z"]), target])
		else:
			f.store_line("DOOR %d %d %s %s" % [int(d["x"]), int(d["z"]), target, tdoor])

	f.close()

func load_from_file(path: String) -> void:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		push_error("Cannot read map file: %s" % path)
		_build_default_map()
		return

	_alloc_grids()
	enemies.clear()
	chests.clear()
	doors.clear()
	npcs.clear()
	player_spawn_x = -1
	player_spawn_z = -1

	# Skip first line (dimensions)
	var _header = f.get_line()

	# Read tile rows
	for tz in range(MAP_HEIGHT):
		var line := f.get_line().strip_edges()
		for tx in range(min(line.length(), MAP_WIDTH)):
			tiles[tz][tx] = int(line[tx])

	# Parse remainder
	var in_heights := false
	var uid_counter := 0
	while not f.eof_reached():
		var line := f.get_line().strip_edges()
		if line.is_empty():
			continue

		if line == "HEIGHTS":
			in_heights = true
			continue

		if line.begins_with("SPAWN "):
			var parts := line.split(" ")
			if parts.size() >= 3:
				player_spawn_x = int(parts[1])
				player_spawn_z = int(parts[2])

		elif line.begins_with("ENEMY "):
			var parts := line.split(" ")
			if parts.size() >= 3:
				uid_counter += 1
				# Optional 4th token is the enemy type (e.g. "undead_horde")
				var etype: String = parts[3] if parts.size() >= 4 else "undead_basic"
				enemies.append({
					"id": "enemy_%d" % uid_counter,
					"x": float(parts[1]),
					"z": float(parts[2]),
					"alive": true,
					"tracking": true,
					"enemy_type": etype,
					"enemy_deck": EnemyRegistry.get_deck(etype),
				})

		elif line.begins_with("CHEST "):
			var parts := line.split(" ")
			if parts.size() >= 4:
				uid_counter += 1
				var card_ids_arr: Array[String] = []
				for cid in parts[3].split(","):
					card_ids_arr.append(cid.strip_edges())
				chests.append({
					"id": "chest_%d" % uid_counter,
					"x": float(parts[1]),
					"z": float(parts[2]),
					"card_ids": card_ids_arr,
					"opened": false
				})

		elif line.begins_with("NPC "):
			var parts := line.split(" ", false, 3)
			if parts.size() >= 3:
				uid_counter += 1
				var dialogue: String = parts[3] if parts.size() >= 4 else "..."
				npcs.append({
					"id": "npc_%d" % uid_counter,
					"x": float(parts[1]),
					"z": float(parts[2]),
					"dialogue": dialogue,
				})

		elif line.begins_with("DOOR "):
			var parts := line.split(" ")
			if parts.size() >= 4:
				uid_counter += 1
				var target: String = parts[3]
				if target == "__exit__":
					target = ""
				var tdoor: String = parts[4] if parts.size() >= 5 else ""
				doors.append({
					"id": "door_%d" % uid_counter,
					"x": float(parts[1]),
					"z": float(parts[2]),
					"target_map": target,
					"target_door_id": tdoor
				})

		elif in_heights:
			var parts := line.split(",")
			if parts.size() == 3:
				var tx := int(parts[0])
				var tz := int(parts[1])
				var h := int(parts[2])
				if tx >= 0 and tx < MAP_WIDTH and tz >= 0 and tz < MAP_HEIGHT:
					heights[tz][tx] = h

	f.close()

func get_chunk_data(cx: int, cz: int) -> RefCounted:
	const CHUNK_SIZE: int = 16
	var cd: ChunkData = ChunkData.new(cx, cz)
	var tx0: int = cx * CHUNK_SIZE
	var tz0: int = cz * CHUNK_SIZE
	for lz in range(CHUNK_SIZE):
		for lx in range(CHUNK_SIZE):
			cd.set_tile(lx, lz, get_tile(tx0 + lx, tz0 + lz))
			cd.set_height(lx, lz, get_height(tx0 + lx, tz0 + lz))
	var wx0: float = float(tx0) * TILE_SIZE
	var wz0: float = float(tz0) * TILE_SIZE
	var wx1: float = wx0 + float(CHUNK_SIZE) * TILE_SIZE
	var wz1: float = wz0 + float(CHUNK_SIZE) * TILE_SIZE
	for e in enemies:
		if e["x"] >= wx0 and e["x"] < wx1 and e["z"] >= wz0 and e["z"] < wz1:
			cd.enemies.append(e)
	for c in chests:
		if c["x"] >= wx0 and c["x"] < wx1 and c["z"] >= wz0 and c["z"] < wz1:
			cd.chests.append(c)
	for d in doors:
		if d["x"] >= wx0 and d["x"] < wx1 and d["z"] >= wz0 and d["z"] < wz1:
			cd.doors.append(d)
	for n in npcs:
		if n["x"] >= wx0 and n["x"] < wx1 and n["z"] >= wz0 and n["z"] < wz1:
			cd.npcs.append(n)
	cd.is_generated = true
	cd.has_entities = true
	return cd

static func list_map_names() -> Array[String]:
	var result: Array[String] = []
	var seen: Dictionary = {}

	# Check res://assets/maps/
	var da := DirAccess.open("res://assets/maps/")
	if da:
		da.list_dir_begin()
		var fname := da.get_next()
		while fname != "":
			if fname.ends_with(".txt"):
				var n := fname.get_basename()
				if not seen.has(n):
					result.append(n)
					seen[n] = true
			fname = da.get_next()

	# Check user://maps/
	var da2 := DirAccess.open("user://maps/")
	if da2:
		da2.list_dir_begin()
		var fname2 := da2.get_next()
		while fname2 != "":
			if fname2.ends_with(".txt"):
				var n := fname2.get_basename()
				if not seen.has(n):
					result.append(n)
					seen[n] = true
			fname2 = da2.get_next()

	return result

# ── Default map builder ───────────────────────────────────────────────────────

func _build_default_map() -> void:
	_alloc_grids()

	# Border walls
	for tx in range(MAP_WIDTH):
		tiles[0][tx] = TILE_WALL; heights[0][tx] = 1
		tiles[MAP_HEIGHT-1][tx] = TILE_WALL; heights[MAP_HEIGHT-1][tx] = 1
	for tz in range(MAP_HEIGHT):
		tiles[tz][0] = TILE_WALL; heights[tz][0] = 1
		tiles[tz][MAP_WIDTH-1] = TILE_WALL; heights[tz][MAP_WIDTH-1] = 1

	# Interior walls (mirroring Java buildMap)
	for tx in range(10, 35):
		tiles[30][tx] = TILE_WALL
		heights[30][tx] = 2 if (tx % 3 == 0) else 1
	for tx in range(45, 70):
		tiles[50][tx] = TILE_WALL; heights[50][tx] = 2
	for tx in range(10, 35):
		tiles[70][tx] = TILE_WALL; heights[70][tx] = 1
	for tz in range(20, 40):
		tiles[tz][55] = TILE_WALL
		heights[tz][55] = 2 if (tz % 4 == 0) else 1
	for tz in range(60, 85):
		tiles[tz][25] = TILE_WALL; heights[tz][25] = 1

	_generate_entities()

func _generate_entities() -> void:
	enemies.clear()
	chests.clear()

	var rng := RandomNumberGenerator.new()
	rng.seed = 12345

	var card_ids: Array[String] = ["ghost", "skeleton", "zombie", "ghoul"]
	var max_depth := MAP_WIDTH + MAP_HEIGHT - 2
	var enemy_count := 0
	var step: int = max(1, (max_depth - 20) / 8)

	var depth := 10
	while depth < max_depth and enemy_count < 8:
		var tx := rng.randi_range(1, min(MAP_WIDTH - 2, depth))
		var tz := depth - tx
		if tz >= 1 and tz < MAP_HEIGHT - 1 and tiles[tz][tx] == TILE_GRASS:
			var wx := float(tx) * TILE_SIZE + TILE_SIZE * 0.5
			var wz := float(tz) * TILE_SIZE + TILE_SIZE * 0.5
			var etype: String = EnemyRegistry.type_for_depth(depth, max_depth)
			enemies.append({
				"id": "enemy_%d" % enemy_count,
				"x": wx, "z": wz,
				"alive": true, "tracking": true,
				"enemy_type": etype,
				"enemy_deck": EnemyRegistry.get_deck(etype),
			})
			enemy_count += 1
		depth += step

	var chest_depths: Array[int] = [max_depth/4, max_depth/2, (max_depth*3)/4, max_depth - 10]
	var chest_count := 0
	for target_depth: int in chest_depths:
		if chest_count >= 4:
			break
		var d: int = target_depth + rng.randi_range(-5, 5)
		d = clamp(d, 5, max_depth - 5)
		var tx := rng.randi_range(1, min(MAP_WIDTH - 2, d))
		var tz: int = d - tx
		if tz >= 1 and tz < MAP_HEIGHT - 1 and tiles[tz][tx] == TILE_GRASS:
			var wx := float(tx) * TILE_SIZE + TILE_SIZE * 0.5
			var wz := float(tz) * TILE_SIZE + TILE_SIZE * 0.5
			var cid: String = card_ids[chest_count % card_ids.size()]
			chests.append({
				"id": "chest_%d" % chest_count,
				"x": wx, "z": wz,
				"card_ids": [cid],
				"opened": false
			})
			chest_count += 1
