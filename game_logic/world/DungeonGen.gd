extends RefCounted

# Generates a finite dungeon WorldMap from a numeric seed.
#
# Layout: rooms are placed left-to-right in sequence, connected by corridors.
#   Room 0  = Start  : player spawn, no enemies
#   Rooms 1…N-2 = Middle : enemies, scaling difficulty
#   Room N-1 = End   : chest + exit door back to overworld
#
# Usage:
#   var map: WorldMap = DungeonGen.generate("dungeon_12345", 12345)

const _WorldMap = preload("res://game_logic/world/WorldMap.gd")
const _EnemyRegistry = preload("res://autoloads/EnemyRegistry.gd")

const DW: int = 80          # dungeon width  (tiles)
const DH: int = 60          # dungeon height (tiles)
const WALL_H: int = 4       # wall height
const TILE_SIZE: float = IsoConst.TILE_SIZE

const ROOM_COUNT: int = 5   # always 5 rooms: start + 3 middle + end
const MIN_ROOM_W: int = 10
const MAX_ROOM_W: int = 16
const MIN_ROOM_H: int = 10
const MAX_ROOM_H: int = 14
const CORRIDOR_HALF: int = 1  # corridor is (CORRIDOR_HALF*2+1) tiles wide = 3


static func generate(p_name: String, dungeon_seed: int) -> _WorldMap:
	var rng := RandomNumberGenerator.new()
	rng.seed = dungeon_seed

	var map: _WorldMap = _WorldMap.new(p_name, true)  # skip_load: avoids default-map fallback

	# Fill entire working area with walls
	for tz in range(DH):
		for tx in range(DW):
			map.set_tile(tx, tz, IsoConst.TILE_WALL)
			map.set_height(tx, tz, WALL_H)

	# Generate rooms placed left-to-right in sequence
	var rooms: Array[Rect2i] = _gen_sequential_rooms(rng)

	for room in rooms:
		_carve(map, room)

	for i in range(1, rooms.size()):
		_connect(map, rooms[i - 1], rooms[i])

	map.enemies.clear()
	map.chests.clear()
	map.doors.clear()
	map.npcs.clear()

	# --- Start room: player spawn ---
	var start: Rect2i = rooms[0]
	map.player_spawn_x = start.position.x + start.size.x / 2
	map.player_spawn_z = start.position.y + start.size.y / 2

	# --- Assign room types for middle rooms ---
	# Room 0 = start (safe spawn), Room 1 = always combat, Rooms 2..N-2 = random,
	# Room N-1 = combat (end room with chest + exit).
	# Distribution: 60% combat, 15% rest, 15% treasure, 10% event.
	var room_types: Array[String] = []
	room_types.resize(ROOM_COUNT)
	room_types[0] = "start"
	room_types[1] = "combat"
	for ri in range(2, ROOM_COUNT - 1):
		var roll: int = rng.randi() % 100
		if roll < 60:
			room_types[ri] = "combat"
		elif roll < 75:
			room_types[ri] = "rest"
		elif roll < 90:
			room_types[ri] = "treasure"
		else:
			room_types[ri] = "event"
	room_types[ROOM_COUNT - 1] = "combat"

	# --- Populate middle rooms based on type ---
	var dist: int = int(abs(float(dungeon_seed % 10000)) / 500.0)
	var enemy_uid: int = 0
	var npc_uid: int = 0
	var troom_uid: int = 0   # treasure room chest counter
	var combat_count: int = 0  # tracks how many combat rooms processed (for difficulty scaling)
	var card_pool: Array[String] = ["ghost", "skeleton", "zombie", "ghoul"]
	var offsets: Array[Vector2i] = [Vector2i(-2, -2), Vector2i(2, 2)]

	for i in range(1, rooms.size() - 1):
		var room: Rect2i = rooms[i]
		var rcx: int = room.position.x + room.size.x / 2
		var rcz: int = room.position.y + room.size.y / 2
		var rtype: String = room_types[i]

		match rtype:
			"combat":
				var room_dist: int = dist + combat_count
				var etype: String = _EnemyRegistry.type_for_chunk_dist(room_dist)
				var deck: Array[String] = _EnemyRegistry.get_deck(etype)
				var enemy_count: int = 1 if combat_count == 0 else 2
				for e in range(enemy_count):
					var ecx2: int = rcx + offsets[e].x
					var ecz2: int = rcz + offsets[e].y
					map.enemies.append({
						"id": "de_%d" % enemy_uid,
						"x": float(ecx2) * TILE_SIZE + TILE_SIZE * 0.5,
						"z": float(ecz2) * TILE_SIZE + TILE_SIZE * 0.5,
						"alive": true, "tracking": true,
						"enemy_type": etype,
						"enemy_deck": deck,
					})
					enemy_uid += 1
				combat_count += 1
			"rest":
				map.npcs.append({
					"id": "dnpc_rest_%d" % npc_uid,
					"x": float(rcx) * TILE_SIZE + TILE_SIZE * 0.5,
					"z": float(rcz) * TILE_SIZE + TILE_SIZE * 0.5,
					"dialogue": "A smouldering campfire fills this chamber with warmth. You could rest here.",
					"npc_type": "rest_site",
					"flag_key": "",
					"after_dialogue": p_name + "_room_" + str(i),
				})
				npc_uid += 1
			"treasure":
				# Guaranteed 2 cards; "dtr_" prefix signals enhanced weapon drop chance in WorldScene
				var card1: String = card_pool[rng.randi_range(0, card_pool.size() - 1)]
				var card2: String = card_pool[rng.randi_range(0, card_pool.size() - 1)]
				var troom_chest: Dictionary = {
					"id": "dtr_%d" % troom_uid,
					"x": float(rcx) * TILE_SIZE + TILE_SIZE * 0.5,
					"z": float(rcz) * TILE_SIZE + TILE_SIZE * 0.5,
					"card_ids": [card1, card2],
					"opened": false,
				}
				if rng.randi() % 100 < 15:
					troom_chest["is_mimic"] = true
				map.chests.append(troom_chest)
				troom_uid += 1
			"event":
				map.npcs.append({
					"id": "dnpc_event_%d" % npc_uid,
					"x": float(rcx) * TILE_SIZE + TILE_SIZE * 0.5,
					"z": float(rcz) * TILE_SIZE + TILE_SIZE * 0.5,
					"dialogue": "Something stirs in this chamber. An unseen presence lingers.",
					"npc_type": "event_room",
					"flag_key": "",
					"after_dialogue": p_name + "_room_" + str(i),
				})
				npc_uid += 1

	# --- End room: chest + exit door (always combat-style reward) ---
	var end_room: Rect2i = rooms[rooms.size() - 1]
	var ecx: int = end_room.position.x + end_room.size.x / 2
	var ecz: int = end_room.position.y + end_room.size.y / 2

	var end_chest: Dictionary = {
		"id": "dc_0",
		"x": float(ecx - 2) * TILE_SIZE + TILE_SIZE * 0.5,
		"z": float(ecz) * TILE_SIZE + TILE_SIZE * 0.5,
		"card_ids": [card_pool[rng.randi_range(0, card_pool.size() - 1)]],
		"opened": false,
	}
	if rng.randi() % 100 < 15:
		end_chest["is_mimic"] = true
	map.chests.append(end_chest)

	# Exit door — empty target_map triggers exit_map(), returning to overworld
	map.doors.append({
		"id": "exit",
		"x": float(ecx + 2) * TILE_SIZE + TILE_SIZE * 0.5,
		"z": float(ecz) * TILE_SIZE + TILE_SIZE * 0.5,
		"target_map": "",
		"target_door_id": "",
	})

	# 30% chance to add a secret room branching off a corridor or room wall
	if rng.randi() % 100 < 30:
		_try_gen_secret_room(map, rng, card_pool)

	# Persist to user://maps/<p_name>.tres so MapRegistry can load it on re-entry
	# without regenerating. WorldScene checks MapRegistry first before calling generate().
	map.save_to_file(p_name)

	return map


static func _gen_sequential_rooms(rng: RandomNumberGenerator) -> Array[Rect2i]:
	# Divide the dungeon width into ROOM_COUNT columns, place one room per column.
	# This guarantees a natural left-to-right reading of start → middle → end.
	var rooms: Array[Rect2i] = []
	const MARGIN: int = 3
	var col_w: int = (DW - MARGIN * 2) / ROOM_COUNT

	for i in range(ROOM_COUNT):
		var rw: int = rng.randi_range(MIN_ROOM_W, min(MAX_ROOM_W, col_w - 2))
		var rh: int = rng.randi_range(MIN_ROOM_H, MAX_ROOM_H)

		# X: within this column, with a small random offset
		var col_start: int = MARGIN + i * col_w
		var rx: int = col_start + rng.randi_range(1, maxi(1, col_w - rw - 1))

		# Z: centred vertically with random jitter
		var z_centre: int = DH / 2
		var z_jitter: int = rng.randi_range(-(DH / 4 - rh / 2), DH / 4 - rh / 2)
		var rz: int = clamp(z_centre + z_jitter - rh / 2, MARGIN, DH - rh - MARGIN)

		rooms.append(Rect2i(rx, rz, rw, rh))

	return rooms


static func _carve(map: _WorldMap, room: Rect2i) -> void:
	for tz in range(room.position.y, room.position.y + room.size.y):
		for tx in range(room.position.x, room.position.x + room.size.x):
			map.set_tile(tx, tz, IsoConst.TILE_GRASS)
			map.set_height(tx, tz, 0)


static func _connect(map: _WorldMap, a: Rect2i, b: Rect2i) -> void:
	# L-shaped corridor between the right edge of a and left edge of b,
	# using room vertical centres. 3 tiles wide.
	var ax: int = a.position.x + a.size.x - 1   # right edge of a
	var az: int = a.position.y + a.size.y / 2    # vertical centre of a
	var bx: int = b.position.x                   # left edge of b
	var bz: int = b.position.y + b.size.y / 2    # vertical centre of b

	# Horizontal leg from a's right to b's left at a's height
	for tx in range(ax, bx + 1):
		for dz in range(-CORRIDOR_HALF, CORRIDOR_HALF + 1):
			var tz: int = az + dz
			if tz >= 0 and tz < DH:
				map.set_tile(tx, tz, IsoConst.TILE_GRASS)
				map.set_height(tx, tz, 0)

	# Vertical leg from a's height to b's height at b's left
	var z0: int = mini(az, bz)
	var z1: int = maxi(az, bz)
	for tz in range(z0, z1 + 1):
		for dx in range(-CORRIDOR_HALF, CORRIDOR_HALF + 1):
			var tx: int = bx + dx
			if tx >= 0 and tx < DW:
				map.set_tile(tx, tz, IsoConst.TILE_GRASS)
				map.set_height(tx, tz, 0)


# Try to carve one secret room branching off any TILE_GRASS tile in the dungeon.
# Returns true if a room was placed.  The connecting wall tile becomes TILE_CRACKED.
static func _try_gen_secret_room(map: _WorldMap, rng: RandomNumberGenerator, card_pool: Array[String]) -> bool:
	# Collect candidates: [cracked_x, cracked_z, room_cx, room_cz]
	var candidates: Array[Array] = []

	const DIRS: Array = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	for tz in range(2, DH - 3):
		for tx in range(2, DW - 3):
			if map.get_tile(tx, tz) != IsoConst.TILE_GRASS:
				continue
			for dir_v in DIRS:
				var dir: Vector2i = dir_v as Vector2i
				var wx: int = tx + dir.x
				var wz: int = tz + dir.y
				if map.get_tile(wx, wz) != IsoConst.TILE_WALL:
					continue
				# Check that a 3×3 area centered one step beyond the wall is all TILE_WALL
				var rcx: int = wx + dir.x
				var rcz: int = wz + dir.y
				if rcx < 1 or rcx >= DW - 1 or rcz < 1 or rcz >= DH - 1:
					continue
				var fits: bool = true
				for ddz in range(-1, 2):
					for ddx in range(-1, 2):
						if map.get_tile(rcx + ddx, rcz + ddz) != IsoConst.TILE_WALL:
							fits = false
							break
					if not fits:
						break
				if fits:
					candidates.append([wx, wz, rcx, rcz])

	if candidates.is_empty():
		return false

	var pick: Array = candidates[rng.randi() % candidates.size()]
	var cw_x: int = int(pick[0])
	var cw_z: int = int(pick[1])
	var rc_x: int = int(pick[2])
	var rc_z: int = int(pick[3])

	# Carve the 3×3 secret room first — the wall tile (cw_x,cw_z) is one step from the
	# room centre so it falls inside the carve area and would get set to TILE_GRASS.
	# Setting TILE_CRACKED afterwards preserves it.
	for ddz in range(-1, 2):
		for ddx in range(-1, 2):
			map.set_tile(rc_x + ddx, rc_z + ddz, IsoConst.TILE_GRASS)
			map.set_height(rc_x + ddx, rc_z + ddz, 0)

	# Set the entrance wall to TILE_CRACKED after the carve so it isn't overwritten.
	map.set_tile(cw_x, cw_z, IsoConst.TILE_CRACKED)
	map.set_height(cw_x, cw_z, WALL_H)

	# Place a bonus chest in the room centre
	var card1: String = card_pool[rng.randi() % card_pool.size()]
	var card2: String = card_pool[rng.randi() % card_pool.size()]
	map.chests.append({
		"id": "dsr_0",
		"x": float(rc_x) * TILE_SIZE + TILE_SIZE * 0.5,
		"z": float(rc_z) * TILE_SIZE + TILE_SIZE * 0.5,
		"card_ids": [card1, card2],
		"opened": false,
	})
	return true
