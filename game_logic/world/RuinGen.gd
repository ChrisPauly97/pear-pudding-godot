## Ruins in the infinite overworld (moved out of InfiniteWorldGen, GID-173): about a third of
## the chunks away from the stitched realm get a small walled ruin — scenery to explore; old saves'
## `dungeon_<n>` ruin dungeons still load (DungeonGen), but no new door leads to them. Pure static logic (runs on
## the chunk worker threads).
extends RefCounted

const IsoConst = preload("res://autoloads/IsoConst.gd")  # usable before autoloads register (-s runs)
const _ChunkData = preload("res://game_logic/world/ChunkData.gd")
const _RealmLayout = preload("res://game_logic/world/RealmLayout.gd")


## True when chunk (cx, cz) has a ruin: off the realm, and a 1-in-3 roll on its seed.
static func has_ruin(p_cx: int, p_cz: int, chunk_seed: int) -> bool:
	if _RealmLayout.chunk_touches_realm(p_cx, p_cz):
		return false
	var rng := RandomNumberGenerator.new()
	rng.seed = chunk_seed + 2
	return rng.randi_range(0, 2) == 0


## Stamps chunk (cx, cz)'s ruin, if it has one: wall ring with crumbled segments, a flat floor
## and 1–2 gaps in the wall. Ruins are scenery: since GID-173 / TID-702 caves (CaveSites) are the
## way underground, so the gaps carry no door. `chunk_seed` is the chunk's InfiniteWorldGen seed.
static func stamp(chunk: _ChunkData, p_cx: int, p_cz: int, chunk_seed: int) -> void:
	if not has_ruin(p_cx, p_cz, chunk_seed):
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = chunk_seed + 2
	rng.randi_range(0, 2)  # the has_ruin roll, so every later draw matches the old stream

	# Inner size: 3x3 to 6x6 tiles; outer includes the wall ring
	var inner_w: int = rng.randi_range(3, 6)
	var inner_h: int = rng.randi_range(3, 6)
	var outer_w: int = inner_w + 2
	var outer_h: int = inner_h + 2

	# Ensure the structure fits with a margin from chunk edges
	const MARGIN: int = 2
	if outer_w + MARGIN * 2 > IsoConst.CHUNK_SIZE or outer_h + MARGIN * 2 > IsoConst.CHUNK_SIZE:
		return

	var sx: int = rng.randi_range(MARGIN, IsoConst.CHUNK_SIZE - outer_w - MARGIN)
	var sz: int = rng.randi_range(MARGIN, IsoConst.CHUNK_SIZE - outer_h - MARGIN)

	# Wall heights: base 4–6 levels, corner towers get an extra 1–3 on top
	var base_h: int = rng.randi_range(4, 6)
	var corner_bonus: int = rng.randi_range(1, 3)

	# Pick 1–2 gaps in the wall ring (not at corners)
	var gaps: Array[Vector2i] = []
	var possible_gaps: Array[Vector2i] = []
	for i in range(1, outer_w - 1):
		possible_gaps.append(Vector2i(sx + i, sz))
		possible_gaps.append(Vector2i(sx + i, sz + outer_h - 1))
	for i in range(1, outer_h - 1):
		possible_gaps.append(Vector2i(sx, sz + i))
		possible_gaps.append(Vector2i(sx + outer_w - 1, sz + i))
	var gap_count: int = rng.randi_range(1, 2)
	for _d in range(gap_count):
		if possible_gaps.is_empty():
			break
		var gap_idx: int = rng.randi_range(0, possible_gaps.size() - 1)
		gaps.append(possible_gaps[gap_idx])
		possible_gaps.remove_at(gap_idx)

	chunk.has_ruin = true

	# Stamp the ruin — perimeter walls, flat interior floor
	for lx in range(outer_w):
		for lz in range(outer_h):
			var tx: int = sx + lx
			var tz: int = sz + lz
			var on_perimeter: bool = lx == 0 or lx == outer_w - 1 or lz == 0 or lz == outer_h - 1

			if not on_perimeter:
				# Interior: clear to flat grass so the floor is walkable
				chunk.set_tile(tx, tz, IsoConst.TILE_GRASS)
				chunk.set_height(tx, tz, 0)
				continue

			var pos: Vector2i = Vector2i(tx, tz)
			if pos in gaps:
				# Gap — leave as grass
				chunk.set_tile(tx, tz, IsoConst.TILE_GRASS)
				chunk.set_height(tx, tz, 0)
				continue

			var is_corner: bool = (lx == 0 or lx == outer_w - 1) and (lz == 0 or lz == outer_h - 1)
			if is_corner:
				# Corner towers are always intact and slightly taller
				chunk.set_tile(tx, tz, IsoConst.TILE_WALL)
				chunk.set_height(tx, tz, base_h + corner_bonus)
			else:
				# 80% of wall segments remain; the rest have crumbled
				if rng.randf() < 0.80:
					var wall_h: int = base_h + rng.randi_range(-1, 1)
					chunk.set_tile(tx, tz, IsoConst.TILE_WALL)
					chunk.set_height(tx, tz, maxi(2, wall_h))
				else:
					chunk.set_tile(tx, tz, IsoConst.TILE_GRASS)
					chunk.set_height(tx, tz, 0)
