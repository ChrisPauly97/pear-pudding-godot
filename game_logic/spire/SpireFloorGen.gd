## Spire floor generator and enemy picker.
##
## generate() produces a compact arena WorldMap for a single Spire floor and
## persists it to user://maps/ so MapRegistry can load it on re-entry (same
## pattern as DungeonGen).
##
## Pure helpers (map_name_for, cleared_flag_for, pick_enemy_type, is_boss_floor)
## carry no engine dependency and are safe to call from headless tests.
extends RefCounted

const _WorldMap = preload("res://game_logic/world/WorldMap.gd")
const _EnemyRegistry = preload("res://autoloads/EnemyRegistry.gd")

# Full WorldMap grid dimensions (100×100).
const MAP_W: int  = 100
const MAP_H: int  = 100
# Cleared arena carved from the wall-filled grid.
const ROOM_W: int = 12
const ROOM_H: int = 8
const WALL_H: int = 4

# ── Pure helpers ─────────────────────────────────────────────────────────────

static func map_name_for(floor: int, run_seed: int) -> String:
	return "spire_floor_%d_%d" % [floor, run_seed]

static func cleared_flag_for(floor: int, run_seed: int) -> String:
	return "spire_floor_%d_%d_cleared" % [floor, run_seed]

## Enemy type ladder: 1-3 basic, 4-6 horde, 7-9 pack, 10+ elite; boss on floor % 7 == 0.
static func pick_enemy_type(floor: int) -> String:
	if is_boss_floor(floor):
		return "undead_elite"
	if floor <= 3:
		return "undead_basic"
	elif floor <= 6:
		return "undead_horde"
	elif floor <= 9:
		return "ghoul_pack"
	return "undead_elite"

static func is_boss_floor(floor: int) -> bool:
	return floor > 0 and floor % 7 == 0

# ── Map generation ───────────────────────────────────────────────────────────

## Generates and saves a Spire floor arena map.
## Caller (WorldScene) should check MapRegistry first to avoid regeneration.
static func generate(floor: int, run_seed: int) -> _WorldMap:
	var p_name: String = map_name_for(floor, run_seed)
	var map: _WorldMap = _WorldMap.new(p_name, true)  # skip MapRegistry lookup

	# Fill entire 100×100 grid with walls so the arena feels fully enclosed.
	for tz in range(MAP_H):
		for tx in range(MAP_W):
			map.set_tile(tx, tz, IsoConst.TILE_WALL)
			map.set_height(tx, tz, WALL_H)

	# Carve a small grass arena in the centre of the map.
	var room_x: int = (MAP_W - ROOM_W) / 2
	var room_z: int = (MAP_H - ROOM_H) / 2
	for tz in range(room_z, room_z + ROOM_H):
		for tx in range(room_x, room_x + ROOM_W):
			map.set_tile(tx, tz, IsoConst.TILE_GRASS)
			map.set_height(tx, tz, 0)

	var ts: float = IsoConst.TILE_SIZE

	# Player spawns on the west side of the arena.
	map.player_spawn_x = room_x + 1
	map.player_spawn_z = room_z + ROOM_H / 2

	# Enemy in the centre.
	var ecx: int = room_x + ROOM_W / 2
	var ecz: int = room_z + ROOM_H / 2
	var etype: String = pick_enemy_type(floor)
	var deck: Array[String] = _EnemyRegistry.get_deck(etype)
	var enemy_entry: Dictionary = {
		"id": "spire_enemy",
		"x": float(ecx) * ts + ts * 0.5,
		"z": float(ecz) * ts + ts * 0.5,
		"alive": true, "tracking": true,
		"enemy_type": etype,
		"enemy_deck": deck,
	}
	if is_boss_floor(floor):
		enemy_entry["is_boss"] = true
		var bhp: int = _EnemyRegistry.get_boss_hp(etype)
		if bhp > 0:
			enemy_entry["boss_hp"] = bhp
	map.enemies.append(enemy_entry)

	# Exit door on the east side of the arena, locked until the enemy is defeated.
	map.doors.append({
		"id": "spire_exit",
		"x": float(room_x + ROOM_W - 1) * ts + ts * 0.5,
		"z": float(ecz) * ts + ts * 0.5,
		"target_map": "",
		"target_door_id": "",
		"flag_key": cleared_flag_for(floor, run_seed),
	})

	map.save_to_file(p_name)
	return map
