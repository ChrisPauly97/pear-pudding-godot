## Draft pick logic for the Endless Spire.
##
## generate_picks accepts the full card pool from the caller (CardRegistry.get_all_ids())
## so this class stays pure and works in headless tests without autoload access.
##
## Seeding the RNG with (spire_run.seed + floor) before calling generate_picks
## guarantees the same picks are shown if the player reopens the draft after
## an app restart.
extends RefCounted

const CardRegistry = preload("res://autoloads/CardRegistry.gd")

# Tier meanings
# 0 = basic   : cost 1-2 minions
# 1 = standard: cost 3-4 minions | cost 1-2 spells
# 2 = premium : cost 5+ minions  | cost 3+ spells
# 3 = legendary: card_class == "legendary"

## Pure tier computation from a template dict (no CardRegistry dependency).
func card_tier_from_template(tmpl: Dictionary) -> int:
	if tmpl.is_empty():
		return 0
	var cls: String = str(tmpl.get("card_class", "minion"))
	var cost: int = int(tmpl.get("cost", 1))
	if cls == "legendary":
		return 3
	if cls == "spell":
		return 2 if cost >= 3 else 1
	# minion
	if cost <= 2:
		return 0
	if cost <= 4:
		return 1
	return 2

## Tier computation by card ID (resolves via CardRegistry; use card_tier_from_template for tests).
func card_tier(card_id: String) -> int:
	return card_tier_from_template(CardRegistry.get_template(card_id))

## Returns [t0_weight, t1_weight, t2_weight, t3_weight] for a given floor.
func tier_weights(floor: int) -> Array[int]:
	if floor <= 3:
		return [60, 30, 10, 0]
	elif floor <= 6:
		return [35, 40, 20, 5]
	else:
		return [15, 35, 35, 15]

## Returns 3 distinct card IDs sampled with floor-depth rarity weighting.
## pool_templates: Dictionary {card_id: template_dict} — build from CardRegistry in the caller.
## The caller must seed rng before calling (e.g. rng.seed = spire_run.seed + floor).
func generate_picks(floor: int, rng: RandomNumberGenerator, pool_templates: Dictionary) -> Array[String]:
	# Bucket cards by tier
	var buckets: Array = [[], [], [], []]
	for id: String in pool_templates.keys():
		var t: int = card_tier_from_template(pool_templates[id] as Dictionary)
		(buckets[t] as Array).append(id)

	var weights: Array[int] = tier_weights(floor)
	var picks: Array[String] = []

	for _i in range(3):
		var id: String = _pick_one(buckets, weights, picks, rng)
		if id != "":
			picks.append(id)

	return picks

func _pick_one(
		buckets: Array,
		weights: Array[int],
		exclude: Array[String],
		rng: RandomNumberGenerator) -> String:

	var pool_ids: Array[String] = []
	var pool_weights: Array[int] = []

	for tier: int in buckets.size():
		var w: int = weights[tier]
		if w <= 0:
			continue
		for cid in (buckets[tier] as Array):
			var cid_str: String = str(cid)
			if not exclude.has(cid_str):
				pool_ids.append(cid_str)
				pool_weights.append(w)

	if pool_ids.is_empty():
		return ""

	var total: int = 0
	for pw: int in pool_weights:
		total += pw

	var roll: int = rng.randi_range(0, total - 1)
	var cumulative: int = 0
	for idx: int in pool_ids.size():
		cumulative += pool_weights[idx]
		if roll < cumulative:
			return pool_ids[idx]

	return pool_ids[pool_ids.size() - 1]
