# Gambit catalogue for GID-063. Callers must preload — never rely on class_name scan.
# Static helpers return safe defaults so no-gambit paths are mathematically unchanged.

const ALL: Dictionary = {
	"wounded_pride": {
		"name": "Wounded Pride",
		"desc": "Start with 25 HP instead of 30.",
		"multiplier": 1.5,
		"rarity_tier_bonus": 1,
	},
	"slow_start": {
		"name": "Slow Start",
		"desc": "Skip your first card draw on turn 1.",
		"multiplier": 1.5,
		"rarity_tier_bonus": 1,
	},
	"emboldened_foe": {
		"name": "Emboldened Foe",
		"desc": "All enemy minions gain +1 Attack.",
		"multiplier": 2.0,
		"rarity_tier_bonus": 2,
	},
	"iron_veil": {
		"name": "Iron Veil",
		"desc": "Enemy hero starts with 5 armor.",
		"multiplier": 2.0,
		"rarity_tier_bonus": 2,
	},
}

static func get_gambit(id: String) -> Dictionary:
	if id.is_empty() or not ALL.has(id):
		return {}
	return ALL[id]

static func get_multiplier(id: String) -> float:
	var g: Dictionary = get_gambit(id)
	if g.is_empty():
		return 1.0
	return float(g.get("multiplier", 1.0))

static func get_rarity_tier_bonus(id: String) -> int:
	var g: Dictionary = get_gambit(id)
	if g.is_empty():
		return 0
	return int(g.get("rarity_tier_bonus", 0))

static func apply_reward_multiplier(base_coins: int, gambit_id: String) -> int:
	return int(round(float(base_coins) * get_multiplier(gambit_id)))
