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

	var map: _WorldMap = _WorldMap.new(p_name)

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

	# --- Middle rooms: enemies scaling with room index ---
	var dist: int = int(abs(float(dungeon_seed % 10000)) / 500.0)
	var uid: int = 0
	for i in range(1, rooms.size() - 1):
		var room: Rect2i = rooms[i]
		# Scale enemy difficulty: early rooms = dist, late rooms = dist+2
		var room_dist: int = dist + (i - 1)
		var etype: String = _EnemyRegistry.type_for_chunk_dist(room_dist)
		var deck: Array[String] = _EnemyRegistry.get_deck(etype)

		# 1 enemy in first middle room, 2 in later ones
		var enemy_count: int = 1 if i == 1 else 2
		var offsets: Array[Vector2i] = [
			Vector2i(-2, -2), Vector2i(2, 2)
		]
		for e in range(enemy_count):
			var cx: int = room.position.x + room.size.x / 2 + offsets[e].x
			var cz: int = room.position.y + room.size.y / 2 + offsets[e].y
			map.enemies.append({
				"id": "de_%d" % uid,
				"x": float(cx) * TILE_SIZE + TILE_SIZE * 0.5,
				"z": float(cz) * TILE_SIZE + TILE_SIZE * 0.5,
				"alive": true, "tracking": true,
				"enemy_type": etype,
				"enemy_deck": deck,
			})
			uid += 1

	# --- End room: chest + exit door ---
	var end_room: Rect2i = rooms[rooms.size() - 1]
	var ecx: int = end_room.position.x + end_room.size.x / 2
	var ecz: int = end_room.position.y + end_room.size.y / 2

	var card_pool: Array[String] = ["ghost", "skeleton", "zombie", "ghoul"]
	map.chests.append({
		"id": "dc_0",
		"x": float(ecx - 2) * TILE_SIZE + TILE_SIZE * 0.5,
		"z": float(ecz) * TILE_SIZE + TILE_SIZE * 0.5,
		"card_ids": [card_pool[rng.randi_range(0, card_pool.size() - 1)]],
		"opened": false,
	})

	# Exit door — empty target_map triggers exit_map(), returning to overworld
	map.doors.append({
		"id": "exit",
		"x": float(ecx + 2) * TILE_SIZE + TILE_SIZE * 0.5,
		"z": float(ecz) * TILE_SIZE + TILE_SIZE * 0.5,
		"target_map": "",
		"target_door_id": "",
	})

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
