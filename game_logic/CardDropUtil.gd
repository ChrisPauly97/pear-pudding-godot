# Static utility for rarity-weighted card drops.
# No class_name — callers preload this file directly (CLAUDE.md: don't rely on class_name scan).

const IsoConst = preload("res://autoloads/IsoConst.gd")
const CardRegistry = preload("res://autoloads/CardRegistry.gd")

# Rarity weights by source tier. Index = tier-1. Values sum to 100: [common, rare, epic, legendary].
const TIER_WEIGHTS: Array = [
	[80, 18, 2, 0],    # tier 1 — basic overworld enemies / world chests
	[60, 30, 9, 1],    # tier 2 — horde enemies / dungeon end chests
	[40, 40, 17, 3],   # tier 3 — elite packs / treasure rooms
	[20, 40, 30, 10],  # tier 4 — elite enemies / bosses
]

## Returns a rarity string based on a weighted roll for the given source tier (1–4).
static func roll_rarity(source_tier: int) -> String:
	var idx: int = clampi(source_tier - 1, 0, TIER_WEIGHTS.size() - 1)
	var w: Array = TIER_WEIGHTS[idx]
	var roll: int = randi_range(1, 100)
	if roll <= w[0]:
		return "common"
	if roll <= w[0] + w[1]:
		return "rare"
	if roll <= w[0] + w[1] + w[2]:
		return "epic"
	return "legendary"

## Forces the rarity to "legendary" for cards whose card_class is "legendary".
## All other cards keep the rolled rarity unchanged.
static func effective_rarity(template_id: String, rolled: String) -> String:
	var tmpl: Dictionary = CardRegistry.get_template(template_id)
	if str(tmpl.get("card_class", "")) == "legendary":
		return "legendary"
	return rolled

## Maps an enemy difficulty tier (1–4) to a rarity and returns rolled stats for that tier.
## Tier 1 = common, 2 = rare, 3 = epic, 4 = legendary. Cost is never scaled.
static func enemy_card_stats(template_id: String, difficulty_tier: int) -> Dictionary:
	const _TIER_RARITIES: Array[String] = ["common", "rare", "epic", "legendary"]
	var rarity: String = _TIER_RARITIES[clampi(difficulty_tier - 1, 0, 3)]
	return roll_stats(template_id, rarity)

## Rolls attack and health stats for a template at the given rarity using RARITY_CONFIG.
## Cost is never randomised. Returns {"attack": int, "health": int, "cost": int}.
static func roll_stats(template_id: String, rarity: String) -> Dictionary:
	var tmpl: Dictionary = CardRegistry.get_template(template_id)
	var cfg: Dictionary = IsoConst.RARITY_CONFIG.get(rarity, {"multiplier": 1.0, "variance": 0.0})
	var mult: float = float(cfg.get("multiplier", 1.0))
	var variance: float = float(cfg.get("variance", 0.0))
	var base_atk: int = int(tmpl.get("attack", 0))
	var base_hp: int  = int(tmpl.get("health", 0))
	var cost: int     = int(tmpl.get("cost", 1))
	var atk: int = maxi(0, roundi(float(base_atk) * mult * randf_range(1.0 - variance, 1.0 + variance)))
	var hp: int  = maxi(0, roundi(float(base_hp)  * mult * randf_range(1.0 - variance, 1.0 + variance)))
	return {"attack": atk, "health": hp, "cost": cost}
