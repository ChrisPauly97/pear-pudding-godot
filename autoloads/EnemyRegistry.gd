extends Node

const EnemyData = preload("res://data/EnemyData.gd")
const BiomeDef  = preload("res://game_logic/world/BiomeDef.gd")
const ENEMY_DIR := "res://data/enemies"

static var _enemies: Dictionary = {}  # id -> EnemyData
static var _loaded: bool = false

# Fallback deck used when an unknown type is requested.
const _FALLBACK_DECK: Array[String] = [
	"ghost", "ghost", "skeleton", "skeleton",
	"zombie", "zombie", "ghoul", "ghoul",
]

static func _ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true
	var dir := DirAccess.open(ENEMY_DIR)
	if not dir:
		return
	dir.list_dir_begin()
	var fname := dir.get_next()
	while fname != "":
		if fname.ends_with(".tres"):
			var res := ResourceLoader.load(ENEMY_DIR + "/" + fname)
			if res is EnemyData:
				var enemy := res as EnemyData
				_enemies[enemy.id] = enemy
		fname = dir.get_next()

## Returns the battle deck for a type. Falls back to a minimal undead deck if unknown.
## Add a new enemy by dropping an EnemyData .tres in res://data/enemies/ — no code changes needed.
static func get_deck(type_id: String) -> Array[String]:
	_ensure_loaded()
	var result: Array[String] = []
	if _enemies.has(type_id):
		result.assign((_enemies[type_id] as EnemyData).deck)
	else:
		result = _FALLBACK_DECK.duplicate()
	return result

## Returns the drop pool for a type. Falls back to a single ghost if unknown.
static func get_drop_pool(type_id: String) -> Array[String]:
	_ensure_loaded()
	var result: Array[String] = []
	if _enemies.has(type_id):
		result.assign((_enemies[type_id] as EnemyData).drop_pool)
	else:
		result = ["ghost"]
	return result

## Returns the coin reward for defeating an enemy of this type. Falls back to 5 if unknown.
static func get_coin_reward(type_id: String) -> int:
	_ensure_loaded()
	if _enemies.has(type_id):
		return (_enemies[type_id] as EnemyData).coin_reward
	return 5

## Returns true if the enemy type is a boss.
static func is_boss(type_id: String) -> bool:
	_ensure_loaded()
	if _enemies.has(type_id):
		return (_enemies[type_id] as EnemyData).is_boss
	return false

## Returns the display name for a type, or the raw ID if unknown.
static func get_display_name(type_id: String) -> String:
	_ensure_loaded()
	if _enemies.has(type_id):
		return (_enemies[type_id] as EnemyData).display_name
	return type_id

## Returns true if this enemy type uses boss battle presentation.
static func get_is_boss(type_id: String) -> bool:
	_ensure_loaded()
	if _enemies.has(type_id):
		return (_enemies[type_id] as EnemyData).is_boss
	return false

## Returns the boss HP override (0 = use default 30).
static func get_boss_hp(type_id: String) -> int:
	_ensure_loaded()
	if _enemies.has(type_id):
		return (_enemies[type_id] as EnemyData).boss_hp
	return 0

## Returns the phase 2 deck for this enemy type, or empty array if none.
static func get_phase2_deck(type_id: String) -> Array[String]:
	_ensure_loaded()
	var result: Array[String] = []
	if _enemies.has(type_id):
		result.assign((_enemies[type_id] as EnemyData).phase2_deck)
	return result

## Selects an enemy type based on depth through a named map (0 = start, 1 = end).
static func type_for_depth(depth: int, max_depth: int) -> String:
	var pct: float = float(depth) / float(max(max_depth, 1))
	if pct < 0.33:
		return "undead_basic"
	elif pct < 0.66:
		return "undead_horde"
	return "ghoul_pack"

## Returns the difficulty tier (1–4) for an enemy type. Falls back to 1 if unknown.
static func get_difficulty_tier(type_id: String) -> int:
	_ensure_loaded()
	if _enemies.has(type_id):
		return (_enemies[type_id] as EnemyData).difficulty_tier
	return 1

## Selects an enemy type based on Manhattan distance from the world origin chunk.
static func type_for_chunk_dist(dist: int) -> String:
	if dist <= 3:
		return "undead_basic"
	elif dist <= 8:
		return "undead_horde"
	elif dist <= 14:
		return "ghoul_pack"
	return "undead_elite"

## Selects an enemy type by biome and Manhattan distance from origin.
## The biome pool defines which enemy families appear; dist picks within the pool.
static func type_for_biome(biome_id: int, dist: int) -> String:
	var pool: Array = BiomeDef.ENEMY_POOLS[biome_id]
	var idx: int = clamp(dist / 8, 0, pool.size() - 1)
	return pool[idx]
