# Static pack definitions and card-roll logic.
# No class_name — callers preload this file directly (see CLAUDE.md).
const CardRegistry = preload("res://autoloads/CardRegistry.gd")
const CardDropUtil = preload("res://game_logic/CardDropUtil.gd")

# After this many packs without a legendary, the next pack forces one.
const PITY_THRESHOLD: int = 20

# Pack table: Standard (tier-1 weights, 120 coins) and Premium (tier-2 + rare guarantee, 300 coins).
const PACKS: Dictionary = {
	"standard_pack": {
		"id": "standard_pack",
		"name": "Standard Pack",
		"price": 120,
		"card_count": 3,
		"tier": 1,
	},
	"premium_pack": {
		"id": "premium_pack",
		"name": "Premium Pack",
		"price": 300,
		"card_count": 3,
		"tier": 2,
		"guaranteed_min_rarity": "rare",
	},
}

static func get_pack(pack_id: String) -> Dictionary:
	return PACKS.get(pack_id, {})

static func get_all_pack_ids() -> Array[String]:
	var result: Array[String] = []
	for k in PACKS.keys():
		result.append(str(k))
	return result

## Rolls cards for a pack purchase. Returns an array of card dicts:
## { template_id, rarity, attack, health, cost }
##
## current_pity: packs_since_legendary *after* the caller has incremented it.
## If current_pity >= PITY_THRESHOLD the last slot is forced to legendary.
## Premium packs additionally guarantee the slot-1 card is at least rare.
static func roll_pack(pack_id: String, current_pity: int) -> Array[Dictionary]:
	var pack_def: Dictionary = PACKS.get(pack_id, {})
	if pack_def.is_empty():
		return []

	var tier: int = int(pack_def.get("tier", 1))
	var card_count: int = int(pack_def.get("card_count", 3))
	var guaranteed_min_rarity: String = str(pack_def.get("guaranteed_min_rarity", ""))

	# Build the pool of template IDs eligible for packs (craftable cards only).
	var all_ids: Array[String] = CardRegistry.get_all_ids()
	var pool: Array[String] = []
	for id: String in all_ids:
		if CardRegistry.is_craftable(id):
			pool.append(id)
	if pool.is_empty():
		pool = all_ids

	var rarity_order: Array[String] = ["common", "rare", "epic", "legendary"]

	# No cards available (e.g. headless tests without .tres loading) — bail out.
	if pool.is_empty():
		return []

	# Roll all slots.
	var results: Array[Dictionary] = []
	for i: int in range(card_count):
		var template_id: String = pool[randi() % pool.size()]
		var rarity: String = CardDropUtil.roll_rarity(tier)
		var stats: Dictionary = CardDropUtil.roll_stats(template_id, rarity)
		results.append({
			"template_id": template_id,
			"rarity": rarity,
			"attack": int(stats.get("attack", 0)),
			"health": int(stats.get("health", 0)),
			"cost": int(stats.get("cost", 1)),
		})

	# Apply guaranteed_min_rarity to slot 1 (Premium pack guarantee).
	if guaranteed_min_rarity != "" and results.size() >= 2:
		var min_idx: int = rarity_order.find(guaranteed_min_rarity)
		var slot_rarity: String = str(results[1].get("rarity", "common"))
		var slot_idx: int = rarity_order.find(slot_rarity)
		if min_idx >= 0 and slot_idx < min_idx:
			var tmpl_id: String = str(results[1].get("template_id", pool[0]))
			var new_stats: Dictionary = CardDropUtil.roll_stats(tmpl_id, guaranteed_min_rarity)
			results[1]["rarity"] = guaranteed_min_rarity
			results[1]["attack"] = int(new_stats.get("attack", 0))
			results[1]["health"] = int(new_stats.get("health", 0))
			results[1]["cost"] = int(new_stats.get("cost", 1))

	# Pity: force last slot to legendary when threshold is reached.
	if current_pity >= PITY_THRESHOLD and results.size() > 0:
		var last: int = results.size() - 1
		var tmpl_id: String = str(results[last].get("template_id", pool[0]))
		var pity_stats: Dictionary = CardDropUtil.roll_stats(tmpl_id, "legendary")
		results[last]["rarity"] = "legendary"
		results[last]["attack"] = int(pity_stats.get("attack", 0))
		results[last]["health"] = int(pity_stats.get("health", 0))
		results[last]["cost"] = int(pity_stats.get("cost", 1))

	return results
