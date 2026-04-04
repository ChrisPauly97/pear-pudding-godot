class_name WorldMap
extends RefCounted

const EnemyRegistry = preload("res://autoloads/EnemyRegistry.gd")
const ChunkData = preload("res://game_logic/world/ChunkData.gd")
const _MapData   = preload("res://game_logic/world/resources/MapData.gd")
const _MapEnemy  = preload("res://game_logic/world/resources/MapEnemy.gd")
const _MapChest  = preload("res://game_logic/world/resources/MapChest.gd")
const _MapDoor   = preload("res://game_logic/world/resources/MapDoor.gd")
const _MapNpc    = preload("res://game_logic/world/resources/MapNpc.gd")
const _MapScroll = preload("res://game_logic/world/resources/MapScroll.gd")

# Aliases for IsoConst tile types — avoids breaking existing references
const TILE_GRASS: int = IsoConst.TILE_GRASS
const TILE_WALL: int = IsoConst.TILE_WALL
const TILE_HILL: int = IsoConst.TILE_HILL
const TILE_PATH: int = IsoConst.TILE_PATH
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
var scrolls: Array[Dictionary] = []   # Array of scroll dicts
var player_spawn_x: int = -1
var player_spawn_z: int = -1
var is_fallback: bool = false   # true when map file couldn't be loaded

## p_skip_load — if true, only allocates grids without loading from MapRegistry.
## Used internally by MapRegistry's legacy .txt fallback to avoid recursion.
func _init(p_name: String = "main", p_skip_load: bool = false) -> void:
	map_name = p_name
	_alloc_grids()

	if p_skip_load:
		return

	# Loading priority:
	#   1. MapRegistry — returns a preloaded .tres MapData resource (always works)
	#   2. Fallback — procedurally generated default map
	#
	# MapRegistry const-preloads the 6 bundled maps so they're included in the
	# Android PCK. It also runtime-loads user://maps/<name>.tres for editor/dungeon maps.
	var data: Resource = MapRegistry.get_map(map_name)
	if data != null:
		load_from_resource(data)
		print("[WorldMap] Loaded '%s' from MapRegistry — %d NPCs, %d enemies, %d chests, %d doors, %d scrolls" % [
			map_name, npcs.size(), enemies.size(), chests.size(), doors.size(), scrolls.size()])
		return

	push_warning("[WorldMap] Map '%s' not found in MapRegistry — using default map" % map_name)
	is_fallback = true
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

func find_nearby_scroll(px: float, pz: float, range_dist: float) -> Dictionary:
	var range_sq: float = range_dist * range_dist
	for s in scrolls:
		var dx: float = s["x"] - px
		var dz: float = s["z"] - pz
		if dx * dx + dz * dz <= range_sq:
			return s
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

## Save the current map state to user://maps/<p_map_name>.tres.
## The map_name parameter must be the bare name (no path, no extension).
func save_to_file(p_map_name: String) -> void:
	DirAccess.make_dir_recursive_absolute("user://maps")
	var data := to_map_data(p_map_name)
	var path := "user://maps/%s.tres" % p_map_name
	var err := ResourceSaver.save(data, path)
	if err != OK:
		push_error("[WorldMap] Failed to save map '%s' to %s (error %d)" % [p_map_name, path, err])
	else:
		print("[WorldMap] Saved '%s' to %s" % [p_map_name, path])

## Populate this WorldMap from a MapData resource.
## Converts flat PackedInt32Array grids to 2D arrays, and Resource entities to dicts.
func load_from_resource(data: Resource) -> void:
	var md := data as _MapData
	if md == null:
		push_error("[WorldMap] load_from_resource: expected MapData resource, got %s" % str(data))
		_build_default_map()
		return

	_alloc_grids()
	enemies.clear()
	chests.clear()
	doors.clear()
	npcs.clear()
	scrolls.clear()
	player_spawn_x = md.spawn_x
	player_spawn_z = md.spawn_z

	# Flat PackedInt32Array → 2D tile/height arrays
	for tz in range(MAP_HEIGHT):
		for tx in range(MAP_WIDTH):
			var idx: int = tz * MAP_WIDTH + tx
			if idx < md.tiles.size():
				tiles[tz][tx] = md.tiles[idx]
			if idx < md.heights.size():
				heights[tz][tx] = md.heights[idx]

	# Entity Resources → runtime dicts with world-space coordinates
	var uid_counter: int = 0
	for res in md.enemies:
		var e := res as _MapEnemy
		if e == null:
			continue
		uid_counter += 1
		enemies.append({
			"id": e.entity_id if e.entity_id != "" else "enemy_%d" % uid_counter,
			"x": float(e.tile_x) * TILE_SIZE,
			"z": float(e.tile_z) * TILE_SIZE,
			"alive": true,
			"tracking": true,
			"enemy_type": e.enemy_type,
			"enemy_deck": EnemyRegistry.get_deck(e.enemy_type),
		})

	for res in md.chests:
		var c := res as _MapChest
		if c == null:
			continue
		uid_counter += 1
		var card_ids_arr: Array[String] = []
		for cid in c.card_ids:
			card_ids_arr.append(cid)
		chests.append({
			"id": c.entity_id if c.entity_id != "" else "chest_%d" % uid_counter,
			"x": float(c.tile_x) * TILE_SIZE,
			"z": float(c.tile_z) * TILE_SIZE,
			"card_ids": card_ids_arr,
			"opened": false,
		})

	for res in md.doors:
		var d := res as _MapDoor
		if d == null:
			continue
		uid_counter += 1
		doors.append({
			"id": d.entity_id if d.entity_id != "" else "door_%d" % uid_counter,
			"x": float(d.tile_x) * TILE_SIZE,
			"z": float(d.tile_z) * TILE_SIZE,
			"target_map": d.target_map,
			"target_door_id": d.target_door_id,
			"flag_key": d.flag_key,
		})

	for res in md.npcs:
		var n := res as _MapNpc
		if n == null:
			continue
		uid_counter += 1
		npcs.append({
			"id": n.entity_id if n.entity_id != "" else "npc_%d" % uid_counter,
			"x": float(n.tile_x) * TILE_SIZE,
			"z": float(n.tile_z) * TILE_SIZE,
			"dialogue": n.dialogue,
			"npc_type": n.npc_type,
			"flag_key": n.flag_key,
			"after_dialogue": n.after_dialogue,
		})

	for res in md.scrolls:
		var s := res as _MapScroll
		if s == null:
			continue
		uid_counter += 1
		scrolls.append({
			"id": s.entity_id if s.entity_id != "" else "scroll_%d" % uid_counter,
			"x": float(s.tile_x) * TILE_SIZE,
			"z": float(s.tile_z) * TILE_SIZE,
			"scroll_id": s.scroll_id,
			"flag_key": s.flag_key,
		})

## Build a MapData resource from the current in-memory state.
## Used by save_to_file() and by MapRegistry's legacy .txt fallback.
func to_map_data(p_map_name: String = "") -> Resource:
	var md := _MapData.new()
	md.map_name = p_map_name if p_map_name != "" else map_name
	md.width = MAP_WIDTH
	md.height = MAP_HEIGHT
	md.spawn_x = player_spawn_x if player_spawn_x >= 0 else 5
	md.spawn_z = player_spawn_z if player_spawn_z >= 0 else 5

	# Pack 2D tile/height arrays into flat PackedInt32Arrays
	md.tiles = PackedInt32Array()
	md.heights = PackedInt32Array()
	for tz in range(MAP_HEIGHT):
		for tx in range(MAP_WIDTH):
			md.tiles.append(tiles[tz][tx])
			md.heights.append(heights[tz][tx])

	# Convert runtime dicts back to typed Resource entities
	for e_dict in enemies:
		var e := _MapEnemy.new()
		e.entity_id = str(e_dict.get("id", ""))
		e.tile_x = int(float(e_dict.get("x", 0.0)) / TILE_SIZE)
		e.tile_z = int(float(e_dict.get("z", 0.0)) / TILE_SIZE)
		e.enemy_type = str(e_dict.get("enemy_type", "undead_basic"))
		md.enemies.append(e)

	for c_dict in chests:
		var c := _MapChest.new()
		c.entity_id = str(c_dict.get("id", ""))
		c.tile_x = int(float(c_dict.get("x", 0.0)) / TILE_SIZE)
		c.tile_z = int(float(c_dict.get("z", 0.0)) / TILE_SIZE)
		var cids: Array = c_dict.get("card_ids", [])
		for cid in cids:
			c.card_ids.append(str(cid))
		md.chests.append(c)

	for d_dict in doors:
		var d := _MapDoor.new()
		d.entity_id = str(d_dict.get("id", ""))
		d.tile_x = int(float(d_dict.get("x", 0.0)) / TILE_SIZE)
		d.tile_z = int(float(d_dict.get("z", 0.0)) / TILE_SIZE)
		d.target_map = str(d_dict.get("target_map", ""))
		d.target_door_id = str(d_dict.get("target_door_id", ""))
		d.flag_key = str(d_dict.get("flag_key", ""))
		md.doors.append(d)

	for n_dict in npcs:
		var n := _MapNpc.new()
		n.entity_id = str(n_dict.get("id", ""))
		n.tile_x = int(float(n_dict.get("x", 0.0)) / TILE_SIZE)
		n.tile_z = int(float(n_dict.get("z", 0.0)) / TILE_SIZE)
		n.dialogue = str(n_dict.get("dialogue", "..."))
		n.npc_type = str(n_dict.get("npc_type", ""))
		n.flag_key = str(n_dict.get("flag_key", ""))
		n.after_dialogue = str(n_dict.get("after_dialogue", ""))
		md.npcs.append(n)

	for s_dict in scrolls:
		var s := _MapScroll.new()
		s.entity_id = str(s_dict.get("id", ""))
		s.tile_x = int(float(s_dict.get("x", 0.0)) / TILE_SIZE)
		s.tile_z = int(float(s_dict.get("z", 0.0)) / TILE_SIZE)
		s.scroll_id = str(s_dict.get("scroll_id", ""))
		s.flag_key = str(s_dict.get("flag_key", ""))
		md.scrolls.append(s)

	return md

func load_from_file(path: String) -> void:
	var content := FileAccess.get_file_as_string(path)
	if content.is_empty() and FileAccess.get_open_error() != OK:
		push_error("Cannot read map file: %s" % path)
		_build_default_map()
		return
	load_from_string(content)


func load_from_string(content: String) -> void:
	var lines: PackedStringArray = content.split("\n")
	if lines.is_empty():
		_build_default_map()
		return

	_alloc_grids()
	enemies.clear()
	chests.clear()
	doors.clear()
	npcs.clear()
	scrolls.clear()
	player_spawn_x = -1
	player_spawn_z = -1

	var line_idx: int = 1  # skip first line (dimensions)

	# Read tile rows
	for tz in range(MAP_HEIGHT):
		if line_idx >= lines.size():
			break
		var line := lines[line_idx].strip_edges()
		line_idx += 1
		for tx in range(min(line.length(), MAP_WIDTH)):
			tiles[tz][tx] = int(line[tx])

	# Parse remainder
	var in_heights := false
	var uid_counter := 0
	while line_idx < lines.size():
		var line := lines[line_idx].strip_edges()
		line_idx += 1
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
					"x": float(parts[1]) * TILE_SIZE,
					"z": float(parts[2]) * TILE_SIZE,
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
					"x": float(parts[1]) * TILE_SIZE,
					"z": float(parts[2]) * TILE_SIZE,
					"card_ids": card_ids_arr,
					"opened": false
				})

		elif line.begins_with("NPC "):
			var parts := line.split(" ", false, 3)
			if parts.size() >= 3:
				uid_counter += 1
				var raw: String = parts[3] if parts.size() >= 4 else "..."
				var flag_key: String = ""
				var after_dialogue: String = ""
				var dialogue: String = raw
				if raw.begins_with("FLAG:"):
					var space_idx: int = raw.find(" ")
					if space_idx > 0:
						flag_key = raw.substr(5, space_idx - 5)
						var rest: String = raw.substr(space_idx + 1)
						var sep_idx: int = rest.find(" || ")
						if sep_idx >= 0:
							dialogue = rest.substr(0, sep_idx)
							after_dialogue = rest.substr(sep_idx + 4)
						else:
							dialogue = rest
				npcs.append({
					"id": "npc_%d" % uid_counter,
					"x": float(parts[1]) * TILE_SIZE,
					"z": float(parts[2]) * TILE_SIZE,
					"dialogue": dialogue,
					"flag_key": flag_key,
					"after_dialogue": after_dialogue,
				})

		elif line.begins_with("MERCHANT "):
			var parts := line.split(" ")
			if parts.size() >= 3:
				uid_counter += 1
				npcs.append({
					"id": "merchant_%d" % uid_counter,
					"x": float(parts[1]) * TILE_SIZE,
					"z": float(parts[2]) * TILE_SIZE,
					"dialogue": "Welcome, traveller! Browse my wares.",
					"npc_type": "merchant",
				})

		elif line.begins_with("DOOR "):
			var parts := line.split(" ")
			if parts.size() >= 4:
				uid_counter += 1
				var target: String = parts[3]
				if target == "__exit__":
					target = ""
				var tdoor: String = ""
				var flag_key: String = ""
				if parts.size() >= 5:
					if parts[4].begins_with("FLAG:"):
						flag_key = parts[4].substr(5)
					else:
						tdoor = parts[4]
						if parts.size() >= 6 and parts[5].begins_with("FLAG:"):
							flag_key = parts[5].substr(5)
				doors.append({
					"id": "door_%d" % uid_counter,
					"x": float(parts[1]) * TILE_SIZE,
					"z": float(parts[2]) * TILE_SIZE,
					"target_map": target,
					"target_door_id": tdoor,
					"flag_key": flag_key
				})

		elif line.begins_with("SCROLL "):
			var parts := line.split(" ")
			if parts.size() >= 4:
				uid_counter += 1
				var scroll_id: String = parts[3]
				var flag_key: String = ""
				for p in parts:
					if p.begins_with("FLAG:"):
						flag_key = p.substr(5)
				scrolls.append({
					"id": "scroll_%d" % uid_counter,
					"scroll_id": scroll_id,
					"x": float(parts[1]) * TILE_SIZE,
					"z": float(parts[2]) * TILE_SIZE,
					"flag_key": flag_key,
				})

		elif in_heights:
			var parts := line.split(",")
			if parts.size() == 3:
				var tx := int(parts[0])
				var tz := int(parts[1])
				var h := int(parts[2])
				if tx >= 0 and tx < MAP_WIDTH and tz >= 0 and tz < MAP_HEIGHT:
					heights[tz][tx] = h

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
	return MapRegistry.list_map_names()

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
	npcs.clear()

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

	# Generate a few NPCs so fallback maps aren't empty of friendly characters
	var npc_dialogues: Array[String] = [
		"Be careful out there, traveller.",
		"I've been wandering these lands for a long time.",
		"The ruins hold many secrets.",
	]
	var npc_count := 0
	for dlg in npc_dialogues:
		var attempts := 0
		while attempts < 20:
			var tx := rng.randi_range(3, MAP_WIDTH - 4)
			var tz := rng.randi_range(3, MAP_HEIGHT - 4)
			if tiles[tz][tx] == TILE_GRASS:
				var wx := float(tx) * TILE_SIZE + TILE_SIZE * 0.5
				var wz := float(tz) * TILE_SIZE + TILE_SIZE * 0.5
				npcs.append({
					"id": "npc_%d" % npc_count,
					"x": wx, "z": wz,
					"dialogue": dlg,
				})
				npc_count += 1
				break
			attempts += 1
