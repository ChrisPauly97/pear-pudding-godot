extends Node

const BiomeDef = preload("res://game_logic/world/BiomeDef.gd")

# Keep preloads so the export scanner packages these .tres files in the APK.
const _E_DUELIST_ADEPT    := preload("res://data/enemies/duelist_adept.tres")
const _E_DUELIST_CHAMPION := preload("res://data/enemies/duelist_champion.tres")
const _E_DUELIST_NOVICE   := preload("res://data/enemies/duelist_novice.tres")
const _E_GHOUL_PACK       := preload("res://data/enemies/ghoul_pack.tres")
const _E_ROAMING_TERROR   := preload("res://data/enemies/roaming_terror.tres")
const _E_UNDEAD_BASIC     := preload("res://data/enemies/undead_basic.tres")
const _E_UNDEAD_ELITE     := preload("res://data/enemies/undead_elite.tres")
const _E_UNDEAD_HORDE     := preload("res://data/enemies/undead_horde.tres")

static var _enemies: Dictionary = {}
static var _loaded: bool = false

const _FALLBACK_DECK: Array[String] = [
	"ghost", "ghost", "skeleton", "skeleton",
	"zombie", "zombie", "ghoul", "ghoul",
]

static func _ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true
	_enemies = {
		"undead_basic": {
			"display_name": "Undead Wanderer",
			"deck": ["ghost", "ghost", "ghost", "skeleton", "skeleton", "skeleton", "zombie", "zombie", "zombie", "ghoul"],
			"drop_pool": ["ghost", "skeleton", "mend", "wither", "surge_spirit", "ember_imp"],
			"coin_reward": 5,
			"is_boss": false,
			"boss_hp": 0,
			"phase2_deck": [],
			"difficulty_tier": 1,
			"lore_text": "Drawn forth by ancient dark rites, these shambling dead roam the wilds seeking the warmth of the living. They are slow but relentless, overwhelming lone travelers with sheer numbers.",
		},
		"undead_horde": {
			"display_name": "Horde Shambler",
			"deck": ["ghost", "ghost", "ghost", "ghost", "skeleton", "skeleton", "skeleton", "zombie", "zombie", "ghoul", "ghoul"],
			"drop_pool": ["skeleton", "zombie", "dawn_acolyte", "dusk_wraith", "shrouded_wraith", "dusk_seer", "void_creeper"],
			"coin_reward": 8,
			"is_boss": false,
			"boss_hp": 0,
			"phase2_deck": [],
			"difficulty_tier": 2,
			"lore_text": "Where one undead wanders, a horde is never far behind. These pack hunters press forward in relentless waves, making up in numbers what they lack in cunning.",
		},
		"undead_elite": {
			"display_name": "Undead Warlord",
			"deck": ["ghoul", "ghoul", "ghoul", "ghoul", "ghoul", "zombie", "zombie", "zombie", "zombie", "skeleton", "skeleton", "skeleton"],
			"drop_pool": ["ghoul", "restore", "drain", "blitz_ghoul", "veiled_paladin", "ash_warden"],
			"coin_reward": 20,
			"is_boss": false,
			"boss_hp": 0,
			"phase2_deck": [],
			"difficulty_tier": 4,
			"lore_text": "A champion re-risen by Martarquas sorcery, the Undead Warlord retains fragments of its battle tactics. It fights with brutal efficiency — a grim echo of the soldier it once was.",
		},
		"ghoul_pack": {
			"display_name": "Ghoul Pack Leader",
			"deck": ["ghoul", "ghoul", "ghoul", "ghoul", "zombie", "zombie", "zombie", "zombie", "skeleton", "skeleton", "skeleton", "skeleton"],
			"drop_pool": ["zombie", "ghoul", "dawn_paladin", "dusk_vampire", "iron_revenant", "dawn_guardian", "dawn_healer"],
			"coin_reward": 12,
			"is_boss": false,
			"boss_hp": 0,
			"phase2_deck": [],
			"difficulty_tier": 3,
			"lore_text": "Once a fierce warrior in life, the Ghoul Pack Leader still commands through primal instinct, driving its kin with savage coordination. Its bite carries a rot that weakens even the stoutest heart.",
		},
		"duelist_novice": {
			"display_name": "Novice Duelist",
			"deck": ["ghost", "ghost", "ghost", "skeleton", "skeleton", "skeleton", "zombie", "zombie", "ghoul", "mend"],
			"drop_pool": [],
			"coin_reward": 0,
			"is_boss": false,
			"boss_hp": 0,
			"phase2_deck": [],
			"difficulty_tier": 1,
			"lore_text": "A young card duelist eager to prove themselves on the Blancogov tournament circuit. Their deck is simple, but they fight with an enthusiasm that belies their rank.",
		},
		"duelist_adept": {
			"display_name": "Adept Duelist",
			"deck": ["ghost", "ghost", "skeleton", "skeleton", "zombie", "zombie", "ghoul", "ghoul", "mend", "wither", "surge_spirit", "ember_imp"],
			"drop_pool": [],
			"coin_reward": 0,
			"is_boss": false,
			"boss_hp": 0,
			"phase2_deck": [],
			"difficulty_tier": 2,
			"lore_text": "A seasoned competitor with dozens of tournament wins behind them. They read the board well and know how to manage resources to outlast less patient opponents.",
		},
		"duelist_champion": {
			"display_name": "Champion of Blancogov",
			"deck": ["ghoul", "ghoul", "blitz_ghoul", "blitz_ghoul", "shrouded_wraith", "void_wyrm", "wither", "wither", "soul_rend", "dark_pact"],
			"drop_pool": [],
			"coin_reward": 0,
			"is_boss": false,
			"boss_hp": 0,
			"phase2_deck": [],
			"difficulty_tier": 3,
			"lore_text": "The undefeated champion of the Blancogov card tournament. Years of dedicated study and thousands of matches have honed their deck to a razor's edge — they have not lost in three seasons.",
		},
		"roaming_terror": {
			"display_name": "Roaming Terror",
			"deck": ["ghoul", "ghoul", "ghoul", "ghoul", "blitz_ghoul", "blitz_ghoul", "soul_harvest", "soul_harvest", "drain", "drain", "void_creeper", "void_creeper", "dusk_wraith", "dusk_wraith", "wither", "wither"],
			"drop_pool": ["blitz_ghoul", "soul_harvest", "void_wyrm", "dusk_vampire", "dark_pact", "shrouded_wraith", "iron_revenant"],
			"coin_reward": 40,
			"is_boss": true,
			"boss_hp": 50,
			"phase2_deck": ["void_wyrm", "void_wyrm", "soul_rend", "soul_rend", "dusk_vampire", "dusk_vampire", "drain", "wither", "dark_pact", "blitz_ghoul", "blitz_ghoul", "ghoul", "ghoul", "ghoul", "void_creeper", "void_creeper"],
			"difficulty_tier": 4,
			"lore_text": "An ancient horror that drifts the borderlands, drawn by conflict and chaos. When the Martarquas surge, this creature follows in their wake — and grows more dangerous as it is wounded.",
		},
	}

## Returns the battle deck for a type. Falls back to a minimal undead deck if unknown.
static func get_deck(type_id: String) -> Array[String]:
	_ensure_loaded()
	var result: Array[String] = []
	if _enemies.has(type_id):
		result.assign(_enemies[type_id]["deck"])
	else:
		push_warning("EnemyRegistry: unknown enemy type '%s', using fallback deck" % type_id)
		result = _FALLBACK_DECK.duplicate()
	return result

## Returns the drop pool for a type. Falls back to a single ghost if unknown.
static func get_drop_pool(type_id: String) -> Array[String]:
	_ensure_loaded()
	var result: Array[String] = []
	if _enemies.has(type_id):
		result.assign(_enemies[type_id]["drop_pool"])
	else:
		result = ["ghost"]
	return result

## Returns the coin reward for defeating an enemy of this type. Falls back to 5 if unknown.
static func get_coin_reward(type_id: String) -> int:
	_ensure_loaded()
	if _enemies.has(type_id):
		return int(_enemies[type_id]["coin_reward"])
	return 5

## Returns true if the enemy type is a boss.
static func is_boss(type_id: String) -> bool:
	_ensure_loaded()
	if _enemies.has(type_id):
		return bool(_enemies[type_id]["is_boss"])
	return false

## Alias for is_boss() — kept for backward compatibility.
static func get_is_boss(type_id: String) -> bool:
	return is_boss(type_id)

## Returns the display name for a type, or the raw ID if unknown.
static func get_display_name(type_id: String) -> String:
	_ensure_loaded()
	if _enemies.has(type_id):
		return str(_enemies[type_id]["display_name"])
	return type_id

## Returns the boss HP override (0 = use default 30).
static func get_boss_hp(type_id: String) -> int:
	_ensure_loaded()
	if _enemies.has(type_id):
		return int(_enemies[type_id]["boss_hp"])
	return 0

## Returns the phase 2 deck for this enemy type, or empty array if none.
static func get_phase2_deck(type_id: String) -> Array[String]:
	_ensure_loaded()
	var result: Array[String] = []
	if _enemies.has(type_id):
		result.assign(_enemies[type_id]["phase2_deck"])
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
		return int(_enemies[type_id]["difficulty_tier"])
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
static func type_for_biome(biome_id: int, dist: int) -> String:
	var pool: Array = BiomeDef.ENEMY_POOLS[biome_id]
	var idx: int = clamp(dist / 8, 0, pool.size() - 1)
	return pool[idx]

## Returns all known enemy type IDs sorted by difficulty_tier then id.
static func get_all_enemy_ids() -> Array[String]:
	_ensure_loaded()
	var result: Array[String] = []
	for k: String in _enemies.keys():
		result.append(k)
	result.sort_custom(func(a: String, b: String) -> bool:
		var ta: int = int(_enemies[a]["difficulty_tier"])
		var tb: int = int(_enemies[b]["difficulty_tier"])
		if ta != tb:
			return ta < tb
		return a < b
	)
	return result

## Returns the lore text for a type, or "" if unknown or not yet written.
static func get_lore_text(type_id: String) -> String:
	_ensure_loaded()
	if _enemies.has(type_id):
		return str(_enemies[type_id]["lore_text"])
	return ""
