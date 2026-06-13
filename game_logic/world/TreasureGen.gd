extends RefCounted

const InfiniteWorldGen = preload("res://game_logic/world/InfiniteWorldGen.gd")
const IsoConst = preload("res://autoloads/IsoConst.gd")

# Ring distances in tiles from world origin where dig sites are placed.
const DIG_SITE_MIN_RADIUS: int = 100
const DIG_SITE_MAX_RADIUS: int = 200

# Returns a deterministic tile coordinate for a dig site, nudged to the nearest
# walkable grass tile within a 5×5 neighborhood of the derived position.
static func get_dig_site(world_seed: int, treasure_counter: int) -> Vector2i:
	var h: int = _hash_site(world_seed, treasure_counter)
	var angle: float = float(h % 360) * PI / 180.0
	var radius: int = DIG_SITE_MIN_RADIUS + (h % (DIG_SITE_MAX_RADIUS - DIG_SITE_MIN_RADIUS + 1))
	var raw_x: int = int(float(radius) * cos(angle))
	var raw_z: int = int(float(radius) * sin(angle))
	return _nudge_to_grass(raw_x, raw_z, world_seed)

static func _hash_site(world_seed: int, treasure_counter: int) -> int:
	var h: int = (world_seed ^ (treasure_counter * 2654435761)) & 0x7FFFFFFF
	return h

# Scans a 5×5 neighborhood (Manhattan expanding outward) for the first TILE_GRASS tile.
static func _nudge_to_grass(tx: int, tz: int, world_seed: int) -> Vector2i:
	for radius: int in range(3):
		for dz: int in range(-radius, radius + 1):
			for dx: int in range(-radius, radius + 1):
				if abs(dx) != radius and abs(dz) != radius:
					continue
				var cx: int = int(floor(float(tx + dx) / float(IsoConst.CHUNK_SIZE)))
				var cz_chunk: int = int(floor(float(tz + dz) / float(IsoConst.CHUNK_SIZE)))
				var chunk: RefCounted = InfiniteWorldGen.generate_chunk_data_only(cx, cz_chunk, world_seed)
				var lx: int = (tx + dx) - cx * IsoConst.CHUNK_SIZE
				var lz: int = (tz + dz) - cz_chunk * IsoConst.CHUNK_SIZE
				if chunk.get_tile(lx, lz) == IsoConst.TILE_GRASS:
					return Vector2i(tx + dx, tz + dz)
	# Fallback: return the raw position (chunk loading will handle near-wall placement)
	return Vector2i(tx, tz)
