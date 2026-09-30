extends RefCounted

## Where the local player appears when a WorldScene loads (BID-055: lifted out of
## WorldScene._spawn_player so the rules are testable without a scene).
##
## | Entry path                        | Position used                    |
## |-----------------------------------|----------------------------------|
## | Overworld, leaving an interior    | the `pos:` token in the door id  |
## | Overworld / named map, continue   | saved x/z (save's map == this)   |
## | Named map, through a door         | that door's position             |
## | Otherwise                         | Madrian spawn / map SPAWN marker |

const _RealmLayout = preload("res://game_logic/world/RealmLayout.gd")

const _FALLBACK_TILES := 3.0


## The map's SPAWN marker centre in world units, or 3 tiles in on both axes when
## the map has none. Also the dedicated server's streaming reference point.
static func map_spawn(world_map: WorldMap) -> Vector2:
	if world_map != null and world_map.has_player_spawn():
		return Vector2((float(world_map.player_spawn_x) + 0.5) * IsoConst.TILE_SIZE,
				(float(world_map.player_spawn_z) + 0.5) * IsoConst.TILE_SIZE)
	return Vector2(_FALLBACK_TILES, _FALLBACK_TILES) * IsoConst.TILE_SIZE


## The spawn x/z. `saved_map` / `saved_pos` are the save's `current_map` and
## player x/z. The `saved_map == map_name` guard alone decides a restore — fresh
## entries (new game, door, waystone) leave `current_map` on the previous map.
static func resolve(is_infinite: bool, map_name: String, world_map: WorldMap, target_door_id: String,
		saved_map: String, saved_pos: Vector2) -> Vector2:
	var has_saved: bool = saved_map == map_name and saved_pos != Vector2.ZERO
	if is_infinite:
		var back: Variant = _RealmLayout.parse_pos_token(target_door_id)  # leaving an interior
		if back is Vector3:
			return Vector2((back as Vector3).x, (back as Vector3).z)
		if has_saved:
			return saved_pos
		var madrian: Vector3 = _RealmLayout.spawn_pos("madrian")  # new game (GID-138)
		return Vector2(madrian.x, madrian.z)
	var fallback: Vector2 = map_spawn(world_map)
	if not target_door_id.is_empty():
		var door: Dictionary = world_map.find_door_by_id(target_door_id)
		if door.is_empty():
			return fallback
		return Vector2(float(door.get("x", fallback.x)), float(door.get("z", fallback.y)))
	return saved_pos if has_saved else fallback
