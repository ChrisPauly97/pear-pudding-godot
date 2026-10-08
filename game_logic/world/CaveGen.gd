## Cave interiors (GID-173 / TID-701): `dungeon_cave_<seed>` maps, entered by a cave mouth in the
## overworld (CaveSites). Organic caverns instead of DungeonGen's rooms and corridors: a seeded
## random fill smoothed by a cellular automaton, kept to its largest connected cavern. The entrance
## is at the west end, the exit (and its reward chest) at the far end by walking distance; cave
## dwellers stand along the way, harder the deeper they are; stalagmites, crystal caches in quiet
## side pockets, sometimes a campfire to rest at, and DungeonGen's secret-room chance.
##
## Pure static logic (`-s` safe); saved like a dungeon so re-entry finds the same cave.
extends RefCounted

const IsoConst = preload("res://autoloads/IsoConst.gd")  # usable before autoloads register (-s runs)
const _WorldMap = preload("res://game_logic/world/WorldMap.gd")
const _EnemyRegistry = preload("res://autoloads/EnemyRegistry.gd")
const _DungeonGen = preload("res://game_logic/world/DungeonGen.gd")  # cyclic, fine

const CW: int = 64           # cave box width  (tiles)
const CH: int = 48           # cave box height (tiles)
const WALL_H: int = 4
const PILLAR_H: int = 2      # stalagmites
const FILL: float = 0.45     # initial wall share
const SMOOTH_PASSES: int = 5
## A cell becomes rock with at least this many rock neighbours (of 8), open with at most CLEAR.
const ROCK_AT: int = 5
const CLEAR_AT: int = 3
## Fewer open tiles than this in the largest cavern: re-roll (then fall back to rooms).
const MIN_OPEN: int = 700
const TRIES: int = 6
## Cave dwellers, shallow to deep (existing roster: no bespoke cave art needed).
const CAVE_POOL: Array[String] = ["ghoul_pack", "stone_golem", "mountain_troll", "frost_wendigo"]
## Enemies stand at these fractions of the walk from entrance to exit.
const ENEMY_DEPTHS: Array[float] = [0.25, 0.4, 0.55, 0.7, 0.85]
const PILLAR_CHANCE: float = 0.04
const CACHE_COUNT: int = 2
const REST_CHANCE: int = 50  # percent
const CARD_POOL: Array[String] = ["ghost", "skeleton", "zombie", "ghoul"]
const DIRS4: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]


static func generate(p_name: String, cave_seed: int) -> _WorldMap:
	var rng := RandomNumberGenerator.new()
	rng.seed = cave_seed
	var open: Dictionary = {}
	for _t: int in TRIES:
		open = _cavern(rng)
		if open.size() >= MIN_OPEN:
			break
	if open.size() < MIN_OPEN:
		return _DungeonGen.generate_rooms(p_name, cave_seed)
	var map: _WorldMap = _WorldMap.new(p_name, true)
	for tz: int in range(_WorldMap.MAP_HEIGHT):
		for tx: int in range(_WorldMap.MAP_WIDTH):
			var cell := Vector2i(tx, tz)
			map.set_tile(tx, tz, IsoConst.TILE_GRASS if open.has(cell) else IsoConst.TILE_WALL)
			map.set_height(tx, tz, 0 if open.has(cell) else WALL_H)
	map.enemies.clear()
	map.chests.clear()
	map.doors.clear()
	map.npcs.clear()
	var spawn: Vector2i = _westmost(open)
	map.player_spawn_x = spawn.x
	map.player_spawn_z = spawn.y
	var dist: Dictionary = _walk_distances(open, spawn)
	var exit: Vector2i = _farthest(dist)
	var far: int = int(dist[exit])
	var used: Dictionary = {spawn: true, exit: true}
	_place_exit(map, dist, exit, used)
	_place_enemies(map, rng, dist, far, cave_seed, used)
	_place_caches(map, rng, open, dist, far, used)
	if rng.randi() % 100 < REST_CHANCE:
		var mid: Vector2i = _at_depth(dist, far, 0.5, used, rng)
		if mid.x >= 0:
			used[mid] = true
			map.npcs.append({
				"id": "dnpc_rest_0", "x": IsoConst.tile_center(mid.x), "z": IsoConst.tile_center(mid.y),
				"dialogue": "A ring of stones round old embers, under a crack of daylight. You could rest here.",
				"npc_type": "rest_site", "flag_key": "", "after_dialogue": p_name + "_room_1",
			})
	_place_pillars(map, rng, open, used)
	if rng.randi() % 100 < 30:
		_DungeonGen._try_gen_secret_room(map, rng, CARD_POOL)
	map.save_to_file(p_name)
	return map


## The largest connected cavern (Dictionary of open Vector2i → true) of one seeded fill + smoothing.
static func _cavern(rng: RandomNumberGenerator) -> Dictionary:
	var rock: Array[PackedByteArray] = []
	for z: int in range(CH):
		var row := PackedByteArray()
		row.resize(CW)
		for x: int in range(CW):
			var edge: bool = x == 0 or z == 0 or x == CW - 1 or z == CH - 1
			row[x] = 1 if edge or rng.randf() < FILL else 0
		rock.append(row)
	for _p: int in SMOOTH_PASSES:
		var next: Array[PackedByteArray] = []
		for z: int in range(CH):
			var row: PackedByteArray = rock[z].duplicate()
			for x: int in range(1, CW - 1):
				if z == 0 or z == CH - 1:
					continue
				var n: int = 0
				for dz: int in range(-1, 2):
					for dx: int in range(-1, 2):
						if (dx != 0 or dz != 0) and rock[z + dz][x + dx] == 1:
							n += 1
				if n >= ROCK_AT:
					row[x] = 1
				elif n <= CLEAR_AT:
					row[x] = 0
			next.append(row)
		rock = next
	# Keep the largest open region.
	var seen: Dictionary = {}
	var best: Dictionary = {}
	for z: int in range(CH):
		for x: int in range(CW):
			var c := Vector2i(x, z)
			if rock[z][x] == 1 or seen.has(c):
				continue
			var region: Dictionary = {}
			var stack: Array[Vector2i] = [c]
			seen[c] = true
			while not stack.is_empty():
				var q: Vector2i = stack.pop_back()
				region[q] = true
				for d: Vector2i in DIRS4:
					var nq: Vector2i = q + d
					if nq.x < 0 or nq.y < 0 or nq.x >= CW or nq.y >= CH:
						continue
					if rock[nq.y][nq.x] == 0 and not seen.has(nq):
						seen[nq] = true
						stack.append(nq)
			if region.size() > best.size():
				best = region
	return best


static func _westmost(open: Dictionary) -> Vector2i:
	var best := Vector2i(CW, CH)
	for k: Variant in open.keys():
		var c: Vector2i = k
		if c.x < best.x or (c.x == best.x and absi(c.y - CH / 2) < absi(best.y - CH / 2)):
			best = c
	return best


## Walking distance (4-way steps) from `from` to every open tile.
static func _walk_distances(open: Dictionary, from: Vector2i) -> Dictionary:
	var dist: Dictionary = {from: 0}
	var queue: Array[Vector2i] = [from]
	var head: int = 0
	while head < queue.size():
		var q: Vector2i = queue[head]
		head += 1
		for d: Vector2i in DIRS4:
			var nq: Vector2i = q + d
			if open.has(nq) and not dist.has(nq):
				dist[nq] = int(dist[q]) + 1
				queue.append(nq)
	return dist


static func _farthest(dist: Dictionary) -> Vector2i:
	var best := Vector2i.ZERO
	var best_d: int = -1
	for k: Variant in dist.keys():
		var d: int = dist[k]
		var c: Vector2i = k
		if d > best_d or (d == best_d and (c.y < best.y or (c.y == best.y and c.x < best.x))):
			best_d = d
			best = c
	return best


## An unused open tile whose walking distance is about `frac` of `far` (nearest such, seeded tie-break).
static func _at_depth(dist: Dictionary, far: int, frac: float, used: Dictionary,
		rng: RandomNumberGenerator) -> Vector2i:
	var want: int = roundi(float(far) * frac)
	var picks: Array[Vector2i] = []
	for slack: int in range(0, 6):
		for k: Variant in dist.keys():
			var c: Vector2i = k
			if absi(int(dist[c]) - want) == slack and not used.has(c) and not _near_used(c, used, 3):
				picks.append(c)
		if not picks.is_empty():
			break
	if picks.is_empty():
		return Vector2i(-1, -1)
	picks.sort()
	return picks[rng.randi() % picks.size()]


static func _near_used(c: Vector2i, used: Dictionary, r: int) -> bool:
	for k: Variant in used.keys():
		var u: Vector2i = k
		if absi(u.x - c.x) <= r and absi(u.y - c.y) <= r:
			return true
	return false


static func _place_exit(map: _WorldMap, dist: Dictionary, exit: Vector2i, used: Dictionary) -> void:
	# Exit door — empty target_map returns to the overworld (as in DungeonGen).
	map.doors.append({"id": "exit", "x": IsoConst.tile_center(exit.x), "z": IsoConst.tile_center(exit.y),
		"target_map": "", "target_door_id": ""})
	# The reward chest a few steps back from the exit.
	var far: int = int(dist[exit])
	var spot := Vector2i(-1, -1)
	for k: Variant in dist.keys():
		var c: Vector2i = k
		if int(dist[c]) == maxi(0, far - 3) and (spot.x < 0 or c < spot):
			spot = c
	if spot.x >= 0:
		used[spot] = true
		map.chests.append({"id": "dc_0", "x": IsoConst.tile_center(spot.x), "z": IsoConst.tile_center(spot.y),
			"card_ids": [CARD_POOL[absi(spot.x * 31 + spot.y) % CARD_POOL.size()]], "opened": false})


static func _place_enemies(map: _WorldMap, rng: RandomNumberGenerator, dist: Dictionary, far: int,
		cave_seed: int, used: Dictionary) -> void:
	var tier: int = absi(cave_seed % 10000) / 2500  # 0..3: how deep the cave's dwellers start
	for i: int in ENEMY_DEPTHS.size():
		var c: Vector2i = _at_depth(dist, far, ENEMY_DEPTHS[i], used, rng)
		if c.x < 0:
			continue
		used[c] = true
		var etype: String = CAVE_POOL[mini(CAVE_POOL.size() - 1, tier + i / 2)]
		map.enemies.append({
			"id": "de_%d" % i, "x": IsoConst.tile_center(c.x), "z": IsoConst.tile_center(c.y),
			"alive": true, "tracking": true, "enemy_type": etype, "enemy_deck": _EnemyRegistry.get_deck(etype),
		})


## Crystal caches: treasure chests ("dtr_" — better drops) in quiet side pockets, mostly walled in.
static func _place_caches(map: _WorldMap, rng: RandomNumberGenerator, open: Dictionary, dist: Dictionary,
		far: int, used: Dictionary) -> void:
	var pockets: Array[Vector2i] = []
	for k: Variant in open.keys():
		var c: Vector2i = k
		if int(dist[c]) < far / 4 or used.has(c) or _near_used(c, used, 4):
			continue
		var walls: int = 0
		for dz: int in range(-1, 2):
			for dx: int in range(-1, 2):
				if not open.has(c + Vector2i(dx, dz)):
					walls += 1
		if walls >= 5:
			pockets.append(c)
	pockets.sort()
	for n: int in CACHE_COUNT:
		if pockets.is_empty():
			return
		var c: Vector2i = pockets[rng.randi() % pockets.size()]
		used[c] = true
		pockets = pockets.filter(func(p: Vector2i) -> bool: return absi(p.x - c.x) > 6 or absi(p.y - c.y) > 6)
		map.chests.append({"id": "dtr_%d" % n, "x": IsoConst.tile_center(c.x), "z": IsoConst.tile_center(c.y),
			"card_ids": [CARD_POOL[rng.randi() % CARD_POOL.size()], CARD_POOL[rng.randi() % CARD_POOL.size()]],
			"opened": false, "crystal": true})


## Stalagmites: lone low rock pillars in wide-open floor (all 8 neighbours open, so a pillar can't
## cut the cavern), never on or beside a placed entity.
static func _place_pillars(map: _WorldMap, rng: RandomNumberGenerator, open: Dictionary, used: Dictionary) -> void:
	var cells: Array[Vector2i] = []
	for k: Variant in open.keys():
		cells.append(k as Vector2i)
	cells.sort()
	var pillars: Dictionary = {}
	for c: Vector2i in cells:
		if rng.randf() >= PILLAR_CHANCE or _near_used(c, used, 1):
			continue
		var clear: bool = true
		for dz: int in range(-1, 2):
			for dx: int in range(-1, 2):
				var n: Vector2i = c + Vector2i(dx, dz)
				if (dx != 0 or dz != 0) and (not open.has(n) or pillars.has(n)):
					clear = false
		if clear:
			pillars[c] = true
			map.set_tile(c.x, c.y, IsoConst.TILE_WALL)
			map.set_height(c.x, c.y, PILLAR_H)
