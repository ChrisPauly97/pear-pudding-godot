## Pure deck/collection analysis for the deck table (GID-180 / TID-736).
##
## No autoload state, no scene tree: every function takes card instances
## (`CardInstanceUtil` dicts) plus an optional `templates` table
## (template_id → template dict). When `templates` is empty the template comes
## from `CardRegistry`, so tests can pass a hand-built table instead.
extends RefCounted

const CardRegistry = preload("res://autoloads/CardRegistry.gd")
const MagicTypes = preload("res://game_logic/MagicTypes.gd")
const TechniqueDefs = preload("res://game_logic/battle/TechniqueDefs.gd")

## Highest cost bucket of the mana curve; costs at or above it share the last bar.
const CURVE_MAX: int = 7
## Synergy threads beyond this many get noisy on a 30-card strip.
const MAX_SYNERGY_PAIRS: int = 12

## Adjective per dominant branch. Neutral/unbranched decks use NEUTRAL_WORD.
const BRANCH_WORDS: Dictionary = {
	"ember": "Cinder",
	"dawn": "Dawnlit",
	"dusk": "Gloam",
	"ash": "Bone-Choir",
	"bloom": "Bloomwild",
	"thorn": "Thornbound",
	"flux": "Flux",
	"fracture": "Shardbreak",
}
const NEUTRAL_WORD: String = "Wanderer's"
const NEUTRAL_COLOR: Color = Color(0.75, 0.7, 0.6)

## Archetype noun per deck shape (see `archetype`).
const ARCHETYPE_NOUNS: Dictionary = {
	"swarm": "Swarm",
	"tempo": "Tempo",
	"titans": "Titans",
	"grimoire": "Grimoire",
	"bulwark": "Bulwark",
	"rush": "Rush",
	"host": "Host",
}


static func _tmpl(tid: String, templates: Dictionary) -> Dictionary:
	if not templates.is_empty():
		var t: Dictionary = templates.get(tid, {})
		return t
	return CardRegistry.get_template(tid)


static func _tid(inst: Dictionary) -> String:
	return str(inst.get("template_id", ""))


## Cost buckets 0..CURVE_MAX (last bucket = CURVE_MAX and above).
static func mana_curve(instances: Array, _templates: Dictionary = {}) -> Array[int]:
	var curve: Array[int] = []
	curve.resize(CURVE_MAX + 1)
	curve.fill(0)
	for inst: Dictionary in instances:
		var c: int = clampi(int(inst.get("cost", 0)), 0, CURVE_MAX)
		curve[c] += 1
	return curve


static func average_cost(instances: Array) -> float:
	if instances.is_empty():
		return 0.0
	var total: int = 0
	for inst: Dictionary in instances:
		total += int(inst.get("cost", 0))
	return float(total) / float(instances.size())


## Branch → card count, unbranched cards skipped.
static func branch_counts(instances: Array, templates: Dictionary = {}) -> Dictionary:
	var counts: Dictionary = {}
	for inst: Dictionary in instances:
		var b: String = str(_tmpl(_tid(inst), templates).get("magic_branch", ""))
		if b != "":
			counts[b] = int(counts.get(b, 0)) + 1
	return counts


## Most common branch, ties broken alphabetically so the name is stable. "" if none.
static func dominant_branch(instances: Array, templates: Dictionary = {}) -> String:
	var counts: Dictionary = branch_counts(instances, templates)
	var best: String = ""
	var best_n: int = 0
	var keys: Array = counts.keys()
	keys.sort()
	for b: String in keys:
		var n: int = int(counts[b])
		if n > best_n:
			best = b
			best_n = n
	return best


## Deck shape key, one of ARCHETYPE_NOUNS.
static func archetype(instances: Array, templates: Dictionary = {}) -> String:
	if instances.is_empty():
		return "host"
	var spells: int = 0
	var ward: int = 0
	var surge: int = 0
	for inst: Dictionary in instances:
		var t: Dictionary = _tmpl(_tid(inst), templates)
		if str(t.get("card_class", "")) == "spell":
			spells += 1
		var kws: PackedStringArray = PackedStringArray(t.get("keywords", PackedStringArray()))
		if kws.has("ward"):
			ward += 1
		if kws.has("surge"):
			surge += 1
	var n: float = float(instances.size())
	var avg: float = average_cost(instances)
	if float(ward) / n >= 0.3:
		return "bulwark"
	if float(surge) / n >= 0.3:
		return "rush"
	if avg >= 4.5:
		return "titans"
	if float(spells) / n >= 0.6:
		return "tempo" if avg <= 2.5 else "grimoire"
	if avg <= 2.5:
		return "swarm"
	return "host"


## Generated deck name, e.g. "Bone-Choir Swarm". Deterministic for a given deck.
static func deck_name(instances: Array, templates: Dictionary = {}) -> String:
	if instances.is_empty():
		return "Empty Deck"
	var branch: String = dominant_branch(instances, templates)
	var word: String = str(BRANCH_WORDS.get(branch, NEUTRAL_WORD))
	return "%s %s" % [word, str(ARCHETYPE_NOUNS[archetype(instances, templates)])]


## Crest description for the deck header: colour from the dominant branch,
## glyph = archetype key, rarity = the deck's average rarity tier name.
static func crest(instances: Array, templates: Dictionary = {}) -> Dictionary:
	var branch: String = dominant_branch(instances, templates)
	var col: Color = MagicTypes.branch_color(branch) if branch != "" else NEUTRAL_COLOR
	var tier_sum: int = 0
	for inst: Dictionary in instances:
		tier_sum += maxi(0, IsoConst.RARITY_ORDER.find(str(inst.get("rarity", "common"))))
	var avg_tier: int = 0
	if not instances.is_empty():
		avg_tier = roundi(float(tier_sum) / float(instances.size()))
	return {
		"color": col,
		"glyph": archetype(instances, templates),
		"branch": branch,
		"rarity": IsoConst.RARITY_ORDER[clampi(avg_tier, 0, IsoConst.RARITY_ORDER.size() - 1)],
	}


## Links between deck cards that combo: a shared keyword, or the same magic
## branch. Cards of one tag are chained in deck order (a—b—c, not every pair),
## one card per template; keyword links come first, a card already linked by a
## keyword is not linked again by branch; capped at MAX_SYNERGY_PAIRS.
## Each entry: {"a": uid, "b": uid, "kind": "keyword"|"branch", "tag": String}.
static func synergy_pairs(instances: Array, templates: Dictionary = {}) -> Array[Dictionary]:
	var firsts: Array[Dictionary] = []
	var seen: Dictionary = {}
	for inst: Dictionary in instances:
		var tid: String = _tid(inst)
		if not seen.has(tid):
			seen[tid] = true
			firsts.append(inst)
	var kw_groups: Dictionary = {}      # keyword -> Array of uids
	var branch_groups: Dictionary = {}  # branch -> Array of uids
	var kw_order: Array[String] = []
	var branch_order: Array[String] = []
	for inst: Dictionary in firsts:
		var t: Dictionary = _tmpl(_tid(inst), templates)
		var uid: String = str(inst.get("uid", ""))
		for k: String in PackedStringArray(t.get("keywords", PackedStringArray())):
			if not kw_groups.has(k):
				kw_groups[k] = []
				kw_order.append(k)
			(kw_groups[k] as Array).append(uid)
		var b: String = str(t.get("magic_branch", ""))
		if b != "":
			if not branch_groups.has(b):
				branch_groups[b] = []
				branch_order.append(b)
			(branch_groups[b] as Array).append(uid)
	var out: Array[Dictionary] = []
	var linked: Dictionary = {}
	for k: String in kw_order:
		var uids: Array = kw_groups[k]
		for i in range(uids.size() - 1):
			out.append({"a": uids[i], "b": uids[i + 1], "kind": "keyword", "tag": k})
			linked[uids[i]] = true
			linked[uids[i + 1]] = true
	for b: String in branch_order:
		var uids: Array = (branch_groups[b] as Array).filter(func(u: String) -> bool: return not linked.has(u))
		for i in range(uids.size() - 1):
			out.append({"a": uids[i], "b": uids[i + 1], "kind": "branch", "tag": b})
	if out.size() > MAX_SYNERGY_PAIRS:
		out.resize(MAX_SYNERGY_PAIRS)
	return out


## Lowest and highest value a stat can roll at `rarity` (CardDropUtil.roll_stats).
static func _stat_band(base: int, rarity: String) -> Vector2i:
	var cfg: Dictionary = IsoConst.RARITY_CONFIG.get(rarity, {})
	var mult: float = float(cfg.get("multiplier", 1.0))
	var v: float = float(cfg.get("variance", 0.0))
	return Vector2i(maxi(0, roundi(float(base) * mult * (1.0 - v))),
			maxi(0, roundi(float(base) * mult * (1.0 + v))))


## True when the instance's rarity can roll more than one value for some stat.
static func has_roll_range(inst: Dictionary, templates: Dictionary = {}) -> bool:
	var t: Dictionary = _tmpl(_tid(inst), templates)
	var rarity: String = str(inst.get("rarity", "common"))
	for key: String in ["attack", "health"]:
		var band: Vector2i = _stat_band(int(t.get(key, 0)), rarity)
		if band.y > band.x:
			return true
	return false


## 0..1: where the attack/health rolls sit inside their rarity's band
## (averaged over the stats that have a range). 1.0 when nothing can vary.
static func roll_quality(inst: Dictionary, templates: Dictionary = {}) -> float:
	var t: Dictionary = _tmpl(_tid(inst), templates)
	var rarity: String = str(inst.get("rarity", "common"))
	var total: float = 0.0
	var n: int = 0
	for key: String in ["attack", "health"]:
		var band: Vector2i = _stat_band(int(t.get(key, 0)), rarity)
		if band.y <= band.x:
			continue
		total += clampf(float(int(inst.get(key, 0)) - band.x) / float(band.y - band.x), 0.0, 1.0)
		n += 1
	return total / float(n) if n > 0 else 1.0


## A roll at the top of every variable stat's band. Never true when nothing can vary.
static func is_perfect_roll(inst: Dictionary, templates: Dictionary = {}) -> bool:
	return has_roll_range(inst, templates) and roll_quality(inst, templates) >= 1.0


## Stat deltas a − b: {"attack", "health", "cost", "rarity"} (rarity = tier difference).
static func compare(a: Dictionary, b: Dictionary) -> Dictionary:
	return {
		"attack": int(a.get("attack", 0)) - int(b.get("attack", 0)),
		"health": int(a.get("health", 0)) - int(b.get("health", 0)),
		"cost": int(a.get("cost", 0)) - int(b.get("cost", 0)),
		"rarity": IsoConst.RARITY_ORDER.find(str(a.get("rarity", "common")))
				- IsoConst.RARITY_ORDER.find(str(b.get("rarity", "common"))),
	}


## Strength score used for "better than": rarity tier first, then attack+health, then cheaper.
static func power_score(inst: Dictionary) -> int:
	var tier: int = maxi(0, IsoConst.RARITY_ORDER.find(str(inst.get("rarity", "common"))))
	return tier * 10000 + (int(inst.get("attack", 0)) + int(inst.get("health", 0))) * 10 \
			- int(inst.get("cost", 0))


## The weakest same-template deck card `inst` could replace, or {} when the deck
## has no copy of it (or `inst` is itself in the deck).
static func replace_target(inst: Dictionary, deck: Array) -> Dictionary:
	var uid: String = str(inst.get("uid", ""))
	var tid: String = _tid(inst)
	var worst: Dictionary = {}
	for d: Dictionary in deck:
		if str(d.get("uid", "")) == uid:
			return {}
		if _tid(d) != tid:
			continue
		if worst.is_empty() or power_score(d) < power_score(worst):
			worst = d
	return worst


## True when `inst` (not in the deck) beats the weakest deck copy of its template.
static func is_upgrade(inst: Dictionary, deck: Array) -> bool:
	var target: Dictionary = replace_target(inst, deck)
	return not target.is_empty() and power_score(inst) > power_score(target)


## A sample opening hand like a real-time fight deals it (BattleSetup): every
## technique card starts in hand, plus `draw_n` shuffled other cards. Seeded so
## a test (or "draw again" with a new seed) is reproducible.
static func sample_hand(instances: Array, draw_n: int, rng_seed: int) -> Array[Dictionary]:
	var techs: Array[Dictionary] = []
	var rest: Array[Dictionary] = []
	for inst: Dictionary in instances:
		if TechniqueDefs.is_technique(_tid(inst)):
			techs.append(inst)
		else:
			rest.append(inst)
	var rng := RandomNumberGenerator.new()
	rng.seed = rng_seed
	for i in range(rest.size() - 1, 0, -1):
		var j: int = rng.randi_range(0, i)
		var tmp: Dictionary = rest[i]
		rest[i] = rest[j]
		rest[j] = tmp
	var hand: Array[Dictionary] = techs
	hand.append_array(rest.slice(0, maxi(0, draw_n)))
	return hand
