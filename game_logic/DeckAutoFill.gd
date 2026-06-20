extends Object

const IsoConst = preload("res://autoloads/IsoConst.gd")
const CardRegistry = preload("res://autoloads/CardRegistry.gd")

## Fills `working_deck` (by UID) with cards from `available` (not already in deck)
## up to `target_size`, using a balanced-curve heuristic: higher rarity first,
## then prefer the most under-represented mana-cost bucket.
## Returns the new deck array (same UIDs as input plus added ones).
static func fill(working_deck: Array[String], available: Array[Dictionary], target_size: int) -> Array[String]:
	var result: Array[String] = []
	result.assign(working_deck)

	if result.size() >= target_size:
		return result

	var candidates: Array[Dictionary] = []
	for inst: Dictionary in available:
		var uid: String = str(inst.get("uid", ""))
		if uid == "" or result.has(uid):
			continue
		candidates.append(inst)

	# Sort: rarity tier descending, then template_id alphabetical for determinism.
	candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var ra: int = IsoConst.RARITY_ORDER.find(str(a.get("rarity", "common")))
		var rb: int = IsoConst.RARITY_ORDER.find(str(b.get("rarity", "common")))
		if ra != rb:
			return ra > rb
		return str(a.get("template_id", "")) < str(b.get("template_id", ""))
	)

	while result.size() < target_size and not candidates.is_empty():
		var bucket_counts: Dictionary = {"low": 0, "mid": 0, "high": 0}
		for uid: String in result:
			var cost: int = _uid_cost(uid, available)
			bucket_counts[_cost_bucket(cost)] = int(bucket_counts[_cost_bucket(cost)]) + 1

		var best_idx: int = 0
		var best_under: int = -1
		for i in range(candidates.size()):
			var bkt: String = _cost_bucket(_inst_cost(candidates[i]))
			var under: int = -int(bucket_counts[bkt])
			if under > best_under:
				best_under = under
				best_idx = i

		var chosen: Dictionary = candidates[best_idx]
		result.append(str(chosen.get("uid", "")))
		candidates.remove_at(best_idx)

	return result

static func _cost_bucket(cost: int) -> String:
	if cost <= 2:
		return "low"
	elif cost <= 5:
		return "mid"
	return "high"

static func _inst_cost(inst: Dictionary) -> int:
	var rolled: int = int(inst.get("cost", -1))
	if rolled >= 0:
		return rolled
	var tid: String = str(inst.get("template_id", ""))
	if tid == "":
		return 0
	var tmpl: Dictionary = CardRegistry.get_template(tid)
	return int(tmpl.get("cost", 0))

static func _uid_cost(uid: String, all_insts: Array[Dictionary]) -> int:
	for inst: Dictionary in all_insts:
		if str(inst.get("uid", "")) == uid:
			return _inst_cost(inst)
	return 0
