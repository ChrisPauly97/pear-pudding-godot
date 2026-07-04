extends Object

const IsoConst = preload("res://autoloads/IsoConst.gd")
const CardRegistry = preload("res://autoloads/CardRegistry.gd")

## Fills `working_deck` (by UID) with cards from `available` (not already in deck)
## up to `target_size`, using a balanced-curve heuristic: higher rarity first,
## then prefer the most under-represented mana-cost bucket. When multiple owned
## instances share a template (card "name"), the highest-rarity copy of that
## card is treated as the primary pick and filled in first across the whole
## deck; lower-rarity duplicates of an already-represented card are only used
## to top up remaining slots once every unique card has had a chance.
## Returns the new deck array (same UIDs as input plus added ones).
static func fill(working_deck: Array[String], available: Array[Dictionary], target_size: int) -> Array[String]:
	var result: Array[String] = []
	result.assign(working_deck)

	if result.size() >= target_size:
		return result

	var by_template: Dictionary = {}
	for inst: Dictionary in available:
		var uid: String = str(inst.get("uid", ""))
		if uid == "" or result.has(uid):
			continue
		var tid: String = str(inst.get("template_id", ""))
		if not by_template.has(tid):
			by_template[tid] = []
		(by_template[tid] as Array).append(inst)

	var primary: Array[Dictionary] = []
	var secondary: Array[Dictionary] = []
	for tid: String in by_template:
		var group: Array = by_template[tid]
		group.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			return _rarity_rank(a) > _rarity_rank(b))
		primary.append(group[0])
		for i in range(1, group.size()):
			secondary.append(group[i])

	_sort_candidates(primary)
	_sort_candidates(secondary)

	result = _fill_from(result, primary, target_size, available)
	result = _fill_from(result, secondary, target_size, available)
	return result

static func _rarity_rank(inst: Dictionary) -> int:
	return IsoConst.RARITY_ORDER.find(str(inst.get("rarity", "common")))

# Sort: rarity tier descending, then template_id alphabetical for determinism.
static func _sort_candidates(candidates: Array[Dictionary]) -> void:
	candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var ra: int = _rarity_rank(a)
		var rb: int = _rarity_rank(b)
		if ra != rb:
			return ra > rb
		return str(a.get("template_id", "")) < str(b.get("template_id", ""))
	)

static func _fill_from(result: Array[String], candidates: Array[Dictionary], target_size: int, available: Array[Dictionary]) -> Array[String]:
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
