extends RefCounted

const _EnemyRegistry = preload("res://autoloads/EnemyRegistry.gd")

const ENEMY_TYPE_IDS: Array[String] = [
	"undead_basic", "undead_horde", "ghoul_pack", "undead_elite"
]
const BIOME_NAMES: Array[String] = [
	"grasslands", "forest", "desert", "scorched", "mountains"
]

## Returns exactly 3 bounties for the given world seed and day index.
## The result is fully deterministic: same inputs always produce the same output.
## Each entry: { "id", "type", "target", "count", "reward", "offered_at_day" (added by SaveManager) }
static func generate_daily(world_seed: int, day_index: int) -> Array[Dictionary]:
	var rng := RandomNumberGenerator.new()
	rng.seed = (world_seed ^ (day_index * 2654435761)) & 0x7FFFFFFF
	var bounties: Array[Dictionary] = []
	bounties.append(_gen_defeat_enemy_type(rng, day_index, 0))
	bounties.append(_gen_defeat_in_biome(rng, day_index, 1))
	bounties.append(_gen_open_chests(rng, day_index, 2))
	return bounties

static func _gen_defeat_enemy_type(rng: RandomNumberGenerator, day_index: int, roll: int) -> Dictionary:
	var idx: int = rng.randi_range(0, ENEMY_TYPE_IDS.size() - 1)
	var target: String = ENEMY_TYPE_IDS[idx]
	var count: int = rng.randi_range(2, 4)
	var tier: int = _EnemyRegistry.get_difficulty_tier(target)
	var reward: int = 40 + count * 15 + tier * 10
	return {
		"id": "bounty_%d_deftype_%d" % [day_index, roll],
		"type": "defeat_enemy_type",
		"target": target,
		"count": count,
		"reward": reward,
	}

static func _gen_defeat_in_biome(rng: RandomNumberGenerator, day_index: int, roll: int) -> Dictionary:
	var biome_idx: int = rng.randi_range(0, BIOME_NAMES.size() - 1)
	var target: String = BIOME_NAMES[biome_idx]
	var count: int = rng.randi_range(3, 5)
	var reward: int = 50 + count * 12 + biome_idx * 15
	return {
		"id": "bounty_%d_defbiome_%d" % [day_index, roll],
		"type": "defeat_in_biome",
		"target": target,
		"count": count,
		"reward": reward,
	}

static func _gen_open_chests(rng: RandomNumberGenerator, day_index: int, roll: int) -> Dictionary:
	var count: int = rng.randi_range(1, 3)
	var reward: int = count * 30
	return {
		"id": "bounty_%d_chests_%d" % [day_index, roll],
		"type": "open_chests",
		"target": "chest",
		"count": count,
		"reward": reward,
	}
