extends RefCounted

# Pure static A* pathfinder over a Callable tile lookup.
# Callable signature: func(tx: int, tz: int) -> int
# Matches the TerrainMath pattern so it works for both named maps and
# the infinite world without any dependency on scene nodes.

const _SQRT2: float = 1.4142136

const _DIRS: Array[Vector2i] = [
	Vector2i(1, 0),
	Vector2i(-1, 0),
	Vector2i(0, 1),
	Vector2i(0, -1),
	Vector2i(1, 1),
	Vector2i(1, -1),
	Vector2i(-1, 1),
	Vector2i(-1, -1),
]

# Find a tile-coordinate path from `from` to `to`.
#
# tile_lookup — Callable(tx: int, tz: int) -> int, same signature as TerrainMath.
# max_radius  — max Manhattan distance from `from` before giving up; prevents
#               runaway searches on unreachable tiles (recommend 64 tiles).
#
# Returns ordered Array[Vector2i] from source (inclusive) to destination
# (inclusive), or empty Array[Vector2i] if unreachable within max_radius.
static func find_path(
		tile_lookup: Callable,
		from: Vector2i,
		to: Vector2i,
		max_radius: int) -> Array[Vector2i]:

	if from == to:
		var result: Array[Vector2i] = [from]
		return result

	# Quick rejection: wall destination is always unreachable.
	var dest_type: int = tile_lookup.call(to.x, to.y)
	if not _is_walkable(dest_type):
		var empty: Array[Vector2i] = []
		return empty

	var g_cost: Dictionary[Vector2i, float] = {}
	var f_cost: Dictionary[Vector2i, float] = {}
	var came_from: Dictionary[Vector2i, Vector2i] = {}
	var open_set: Dictionary[Vector2i, bool] = {}
	var closed_set: Dictionary[Vector2i, bool] = {}

	g_cost[from] = 0.0
	f_cost[from] = _heuristic(from, to)
	open_set[from] = true

	while not open_set.is_empty():
		# Pop the open-set tile with the lowest f-cost; break ties by h-cost.
		var current := Vector2i.ZERO
		var best_f: float = INF
		var best_h: float = INF
		for tile: Vector2i in open_set:
			var tf: float = f_cost.get(tile, INF)
			var th: float = _heuristic(tile, to)
			if tf < best_f or (tf == best_f and th < best_h):
				best_f = tf
				best_h = th
				current = tile

		if current == to:
			return _reconstruct(came_from, current)

		open_set.erase(current)
		closed_set[current] = true

		for d: Vector2i in _DIRS:
			var nb: Vector2i = current + d

			if closed_set.has(nb):
				continue

			# Bound the search to max_radius from the origin.
			if abs(nb.x - from.x) + abs(nb.y - from.y) > max_radius:
				continue

			# Corner-cutting guard: a diagonal step is only legal if both
			# adjacent cardinal tiles are walkable, preventing passage through
			# the gap between two diagonally-touching wall tiles.
			if d.x != 0 and d.y != 0:
				var tx: int = tile_lookup.call(current.x + d.x, current.y)
				var tz: int = tile_lookup.call(current.x, current.y + d.y)
				if not _is_walkable(tx) or not _is_walkable(tz):
					continue

			var tile_type: int = tile_lookup.call(nb.x, nb.y)
			if not _is_walkable(tile_type):
				continue

			var step_cost: float = _SQRT2 if (d.x != 0 and d.y != 0) else 1.0
			var tentative_g: float = g_cost.get(current, INF) + step_cost
			if tentative_g < g_cost.get(nb, INF):
				came_from[nb] = current
				g_cost[nb] = tentative_g
				f_cost[nb] = tentative_g + _heuristic(nb, to)
				open_set[nb] = true

	var empty: Array[Vector2i] = []
	return empty


static func _is_walkable(tile_type: int) -> bool:
	return tile_type == IsoConst.TILE_GRASS \
		or tile_type == IsoConst.TILE_HILL \
		or tile_type == IsoConst.TILE_PATH


static func _heuristic(a: Vector2i, b: Vector2i) -> float:
	var dx: int = abs(a.x - b.x)
	var dz: int = abs(a.y - b.y)
	var hi: int = dx if dx > dz else dz
	var lo: int = dz if dx > dz else dx
	return float(hi) + (_SQRT2 - 1.0) * float(lo)


static func _reconstruct(came_from: Dictionary, current: Vector2i) -> Array[Vector2i]:
	var path: Array[Vector2i] = [current]
	var node: Vector2i = current
	while came_from.has(node):
		node = came_from[node]
		path.push_front(node)
	return path
