## TownLife — walking townsfolk and their daily schedules in the stitched towns (GID-156).
##
## A few plain townsfolk per town stroll a loop along the TownStreets network:
## home street tile → two or three stops (the square, spots beside street lamps)
## → home, pausing at each stop. Each loop is precomputed once as keyframes
## (time → town-local world position), and its period is stretched so a whole
## number of loops fits in one day. A walker's position is therefore a pure
## function of the time of day: co-op peers share the synced clock, so they see
## the same walkers in the same places with no RPCs, and a day wrap never jumps.
##
## Roles give each walker a window of the day it is out of doors (villagers by
## day, revellers into the night, a lantern guard at night). Quest givers,
## trainers, merchants, story NPCs and indoor folk never walk.
##
## Pure static logic (no scene tree); `scenes/world/modules/TownLife.gd` drives it.

const _SideQuests = preload("res://game_logic/quests/SideQuests.gd")
const _UnlockLadder = preload("res://game_logic/progression/UnlockLadder.gd")
const _SpriteRegistry = preload("res://game_logic/SpriteRegistry.gd")

## World units per second along the street (the hero runs at 6).
const WALK_SPEED: float = 2.4
## At most this many walkers per town, and this share of the eligible townsfolk.
const MAX_WALKERS: int = 6
const WALKER_SHARE: float = 0.7
## A townsperson further than this (tiles) from any street stays put (indoors).
const MAX_HOME_DIST: int = 5
const STOPS_PER_LOOP: Vector2i = Vector2i(2, 3)
## Seconds a walker lingers at a stop, before the period stretch.
const PAUSE_RANGE: Vector2 = Vector2(3.0, 9.0)

const ROLE_VILLAGER: String = "villager"
const ROLE_REVELLER: String = "reveller"
const ROLE_GUARD: String = "guard"
## Time-of-day window (0..1, DayNightCycle: day ≈ 0.25–0.75) each role is out.
## from > to wraps past midnight.
const ROLE_HOURS: Dictionary = {
	ROLE_VILLAGER: Vector2(0.27, 0.72),
	ROLE_REVELLER: Vector2(0.34, 0.93),
	ROLE_GUARD: Vector2(0.72, 0.30),
}

const _DIRS: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]


## True for a plain townsperson who may walk: a generic town extra (id
## "<town>:npc_N") with no type, no story flags, no quest, no training and no
## bespoke sprite. Everyone else keeps their authored tile.
static func is_candidate(npc: Dictionary) -> bool:
	var nid: String = str(npc.get("id", ""))
	if not nid.contains(":npc_"):
		return false
	for key: String in ["npc_type", "flag_key", "hide_flag_key", "show_flag_key"]:
		if str(npc.get(key, "")) != "":
			return false
	if _SideQuests.giver_name_for(nid) != "" or _UnlockLadder.trainer_at(nid) != "":
		return false
	return _SpriteRegistry.named_npc_texture(nid) == null


## Whether `role` is out of doors at `time_of_day` (0..1).
static func is_out(role: String, time_of_day: float) -> bool:
	var w: Vector2 = ROLE_HOURS.get(role, ROLE_HOURS[ROLE_VILLAGER])
	var t: float = fposmod(time_of_day, 1.0)
	if w.x <= w.y:
		return t >= w.x and t < w.y
	return t >= w.x or t < w.y


## Plans a town's walkers. `streets` is the TownStreets plan ("tiles", "lamps"),
## `hub` the square tile, `npcs` the town's NPC dicts in town-local world units
## ("id", "x", "z", …), `world_seed` mixes into every roll and `day_seconds` is the
## length of one day. Returns {id → walker}; a walker is
## {"role", "times": PackedFloat32Array, "points": PackedVector2Array, "period"}.
static func plan(streets: Dictionary, hub: Vector2i, npcs: Array[Dictionary], world_seed: int,
		day_seconds: float) -> Dictionary:
	var tiles: Dictionary = streets.get("tiles", {})
	var out: Dictionary = {}
	if tiles.is_empty() or day_seconds <= 0.0:
		return out
	var stops: Array[Vector2i] = _stops(tiles, streets.get("lamps", []) as Array, hub)
	var homes: Dictionary = {}  # id → home street tile
	var ids: Array[String] = []
	for n: Dictionary in npcs:
		if not is_candidate(n):
			continue
		var tile := IsoConst.entity_tile(n)
		var home: Vector2i = _nearest_street(tiles, tile)
		if home.x == -9999:
			continue
		var nid: String = str(n["id"])
		homes[nid] = home
		ids.append(nid)
	ids.sort()
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([world_seed, ids])
	_shuffle(ids, rng)
	var count: int = mini(MAX_WALKERS, ceili(float(ids.size()) * WALKER_SHARE))
	for i: int in range(count):
		var nid: String = ids[i]
		var role: String = ROLE_VILLAGER
		if i == 0 and count >= 3:
			role = ROLE_GUARD
		elif i % 3 == 2:
			role = ROLE_REVELLER
		var w: Dictionary = _loop(tiles, homes[nid] as Vector2i, stops, hash([world_seed, nid]), day_seconds)
		if w.is_empty():
			continue
		w["role"] = role
		out[nid] = w
	return out


## Where `walker` is at `t_seconds` into the day: {"pos": Vector2 (town-local
## world x/z), "dir": Vector2 (unit, zero while paused), "moving": bool}.
static func sample(walker: Dictionary, t_seconds: float) -> Dictionary:
	var times: PackedFloat32Array = walker["times"]
	var pts: PackedVector2Array = walker["points"]
	var period: float = float(walker["period"])
	var t: float = fposmod(t_seconds, period)
	var hi: int = times.bsearch(t, true)
	hi = clampi(hi, 1, times.size() - 1)
	var lo: int = hi - 1
	var span: float = times[hi] - times[lo]
	var f: float = 0.0 if span <= 0.0 else clampf((t - times[lo]) / span, 0.0, 1.0)
	var a: Vector2 = pts[lo]
	var b: Vector2 = pts[hi]
	var moving: bool = a.distance_squared_to(b) > 0.0001
	return {"pos": a.lerp(b, f), "dir": (b - a).normalized() if moving else Vector2.ZERO, "moving": moving}


## Stops: the square plus the street tile beside each lamp, deduplicated.
static func _stops(tiles: Dictionary, lamps: Array, hub: Vector2i) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	if tiles.has(hub):
		out.append(hub)
	for l: Variant in lamps:
		var lamp: Vector2i = l
		for d: Vector2i in _DIRS:
			var s: Vector2i = lamp + d
			if tiles.has(s) and not out.has(s):
				out.append(s)
				break
	return out


## Closest street tile to `tile` within MAX_HOME_DIST (Chebyshev), or (-9999, …).
static func _nearest_street(tiles: Dictionary, tile: Vector2i) -> Vector2i:
	var best := Vector2i(-9999, -9999)
	var best_d: int = MAX_HOME_DIST + 1
	for r: int in range(0, MAX_HOME_DIST + 1):
		for dz: int in range(-r, r + 1):
			for dx: int in range(-r, r + 1):
				if maxi(absi(dx), absi(dz)) != r:
					continue
				var c := Vector2i(tile.x + dx, tile.y + dz)
				var d: int = absi(dx) + absi(dz)
				if tiles.has(c) and d < best_d:
					best = c
					best_d = d
		if best.x != -9999:
			return best
	return best


## One walker's loop as keyframes; {} when no stop is reachable.
static func _loop(tiles: Dictionary, home: Vector2i, stops: Array[Vector2i], wseed: int,
		day_seconds: float) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = wseed
	var pool: Array[Vector2i] = stops.duplicate()
	pool.erase(home)
	_shuffle(pool, rng)
	var want: int = rng.randi_range(STOPS_PER_LOOP.x, STOPS_PER_LOOP.y)
	var route: Array[Vector2i] = [home]
	for s: Vector2i in pool:
		if route.size() > want:
			break
		route.append(s)
	if route.size() < 2:
		return {}
	route.append(home)
	# Legs as tile paths; pauses after every leg (the last one is at home).
	var legs: Array = []
	var walk_time: float = 0.0
	for i: int in range(route.size() - 1):
		var path: Array[Vector2i] = _street_path(tiles, route[i], route[i + 1])
		if path.is_empty():
			return {}
		legs.append(path)
		walk_time += float(path.size() - 1) * IsoConst.TILE_SIZE / WALK_SPEED
	var pauses: Array[float] = []
	var pause_time: float = 0.0
	for _i: int in range(legs.size()):
		var p: float = rng.randf_range(PAUSE_RANGE.x, PAUSE_RANGE.y)
		pauses.append(p)
		pause_time += p
	var raw: float = walk_time + pause_time
	if raw > day_seconds:
		return {}
	# A whole number of loops per day: stretch the pauses to fill the slack.
	var loops: int = maxi(1, floori(day_seconds / raw))
	var period: float = day_seconds / float(loops)
	var extra: float = (period - raw) / float(pauses.size())
	var times := PackedFloat32Array()
	var points := PackedVector2Array()
	var t: float = 0.0
	times.append(0.0)
	points.append(_centre(home))
	for i: int in range(legs.size()):
		var path: Array[Vector2i] = []
		path.assign(legs[i])
		for k: int in range(1, path.size()):
			t += IsoConst.TILE_SIZE / WALK_SPEED
			times.append(t)
			points.append(_centre(path[k]))
		t += pauses[i] + extra
		times.append(t)
		points.append(_centre(path[path.size() - 1]))
	times[times.size() - 1] = period  # float drift
	return {"times": times, "points": points, "period": period}


static func _centre(t: Vector2i) -> Vector2:
	return Vector2(IsoConst.tile_center(t.x), IsoConst.tile_center(t.y))


## Breadth-first path over street tiles, `from` and `to` included ([] if cut off).
static func _street_path(tiles: Dictionary, from: Vector2i, to: Vector2i) -> Array[Vector2i]:
	var came: Dictionary = {from: from}
	var queue: Array[Vector2i] = [from]
	var head: int = 0
	while head < queue.size():
		var cur: Vector2i = queue[head]
		head += 1
		if cur == to:
			break
		for d: Vector2i in _DIRS:
			var n: Vector2i = cur + d
			if tiles.has(n) and not came.has(n):
				came[n] = cur
				queue.append(n)
	var out: Array[Vector2i] = []
	if not came.has(to):
		return out
	var c: Vector2i = to
	while c != from:
		out.append(c)
		c = came[c]
	out.append(from)
	out.reverse()
	return out


## Seeded Fisher–Yates (Array.shuffle uses the global RNG).
static func _shuffle(arr: Array, rng: RandomNumberGenerator) -> void:
	for i: int in range(arr.size() - 1, 0, -1):
		var j: int = rng.randi_range(0, i)
		var tmp: Variant = arr[i]
		arr[i] = arr[j]
		arr[j] = tmp
