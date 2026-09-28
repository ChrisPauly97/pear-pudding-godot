## Pure backpack logic behind InventoryScene (GID-144): sort orders, search,
## the "select extras" pick and bulk sell/scrap value. No scene or SaveManager
## access — templates come in through a `tmpl_for(template_id) -> Dictionary`
## Callable so tests can stub the registry.
extends RefCounted

const VeterancyUtil = preload("res://game_logic/VeterancyUtil.gd")

const SORT_MODES: Array[String] = ["name", "rarity", "cost", "power", "newest"]
const SORT_LABELS: Dictionary = {
	"name": "Name", "rarity": "Rarity", "cost": "Cost", "power": "Power", "newest": "Newest",
}

## Next sort mode in the cycle (unknown modes restart at the first).
static func next_sort(mode: String) -> String:
	var i: int = SORT_MODES.find(mode)
	return SORT_MODES[(i + 1) % SORT_MODES.size()]

## uid -> loadout name for every card sitting in a saved loadout, plus the
## unsaved working deck under `working_name`. Selling or scrapping one of these
## strips it out of that deck, so bulk actions skip them.
static func deck_membership(loadouts: Array, working_deck: Array, active_idx: int,
		working_name: String) -> Dictionary:
	var out: Dictionary = {}
	for i in range(loadouts.size()):
		if i == active_idx:
			continue
		var lo: Dictionary = loadouts[i]
		var cards: Array = lo.get("cards", [])
		for uid: Variant in cards:
			out[str(uid)] = str(lo.get("name", "Deck %d" % (i + 1)))
	for uid: Variant in working_deck:
		out[str(uid)] = working_name
	return out

static func rarity_rank(inst: Dictionary) -> int:
	return IsoConst.RARITY_ORDER.find(str(inst.get("rarity", "common")))

static func power(inst: Dictionary) -> int:
	return int(inst.get("attack", 0)) + int(inst.get("health", 0))

## Sorts `insts` in place. Ties fall back to name, then best rarity first.
## "newest" relies on `insts` being in acquisition order (owned_cards is append-only).
static func sort_instances(insts: Array[Dictionary], mode: String, tmpl_for: Callable) -> void:
	if mode == "newest":
		insts.reverse()
		return
	var names: Dictionary = {}
	for inst: Dictionary in insts:
		var tid: String = str(inst.get("template_id", ""))
		if not names.has(tid):
			var tmpl: Dictionary = tmpl_for.call(tid)
			names[tid] = str(tmpl.get("name", tid)).to_lower()
	insts.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		match mode:
			"rarity":
				if rarity_rank(a) != rarity_rank(b):
					return rarity_rank(a) > rarity_rank(b)
			"cost":
				if int(a.get("cost", 0)) != int(b.get("cost", 0)):
					return int(a.get("cost", 0)) < int(b.get("cost", 0))
			"power":
				if power(a) != power(b):
					return power(a) > power(b)
		var na: String = names.get(str(a.get("template_id", "")), "")
		var nb: String = names.get(str(b.get("template_id", "")), "")
		if na != nb:
			return na < nb
		return rarity_rank(a) > rarity_rank(b))

## Case-insensitive match on name, description and keywords. Empty query matches all.
static func matches_search(tmpl: Dictionary, query: String) -> bool:
	var q: String = query.strip_edges().to_lower()
	if q == "":
		return true
	var hay: String = "%s %s %s" % [tmpl.get("name", ""), tmpl.get("description", ""),
			" ".join(PackedStringArray(tmpl.get("keywords", PackedStringArray())))]
	return hay.to_lower().contains(q)

## True for copies bulk actions must never touch: uniques, renamed cards and
## veterans (the player has invested in them).
static func is_protected(inst: Dictionary, tmpl: Dictionary) -> bool:
	if bool(tmpl.get("is_unique", false)):
		return true
	if str(inst.get("custom_name", "")) != "":
		return true
	return VeterancyUtil.rank_for(int(inst.get("kills", 0)), int(inst.get("battles_survived", 0))) > 0

## Better-copy ordering: rarity, then rolled power, then cheaper cost.
static func is_better(a: Dictionary, b: Dictionary) -> bool:
	if rarity_rank(a) != rarity_rank(b):
		return rarity_rank(a) > rarity_rank(b)
	if power(a) != power(b):
		return power(a) > power(b)
	return int(a.get("cost", 0)) < int(b.get("cost", 0))

## Uids of spare copies: for each template the best copy you own is kept, and
## every other copy that is not in a deck and not protected is an extra.
static func pick_extras(insts: Array[Dictionary], in_deck: Dictionary, tmpl_for: Callable) -> Array[String]:
	var best: Dictionary = {}   # template_id -> best instance
	for inst: Dictionary in insts:
		var tid: String = str(inst.get("template_id", ""))
		# On a tie the deck copy is the keeper, so its bag twin counts as spare.
		var tie_in_deck: bool = best.has(tid) and in_deck.has(str(inst.get("uid", ""))) \
				and not is_better(best[tid], inst)
		if not best.has(tid) or is_better(inst, best[tid]) or tie_in_deck:
			best[tid] = inst
	var out: Array[String] = []
	for inst: Dictionary in insts:
		var uid: String = str(inst.get("uid", ""))
		var tid: String = str(inst.get("template_id", ""))
		var kept: Dictionary = best[tid]
		if in_deck.has(uid) or str(kept.get("uid", "")) == uid:
			continue
		if is_protected(inst, tmpl_for.call(tid)):
			continue
		out.append(uid)
	return out

## Total {"gold", "essence"} for selling / scrapping every instance in `insts`.
static func bulk_value(insts: Array[Dictionary]) -> Dictionary:
	var gold: int = 0
	var ess: int = 0
	for inst: Dictionary in insts:
		var cfg: Dictionary = IsoConst.RARITY_CONFIG.get(str(inst.get("rarity", "common")), {})
		gold += int(cfg.get("sell_gold", 0))
		ess += int(cfg.get("scrap_essence", 0))
	return {"gold": gold, "essence": ess}
