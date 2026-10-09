## Each town's vendor favours some cards and pays a bonus for them (GID-180 /
## TID-746). Pure table + pricing so the counter, its pitch line and tests agree.
extends RefCounted

const BinderOps = preload("res://game_logic/inventory/BinderOps.gd")
const RealmLayout = preload("res://game_logic/world/RealmLayout.gd")

## Sale bonus on a favoured card.
const BONUS: float = 0.25

## town -> {pages (BinderOps pages the vendor favours), who (the pitch's subject)}.
const TOWNS: Dictionary = {
	"madrian": {"pages": ["light"], "who": "Madrian's merchant"},
	"maykalene": {"pages": ["rift"], "who": "Maykalene's dockmaster"},
	"blancogov": {"pages": ["verdant"], "who": "Blancogov's herbalist-trader"},
	"larik": {"pages": ["dark"], "who": "Larik's fence"},
	"marsax_hold": {"pages": ["neutral"], "who": "The Hold's quartermaster"},
}


## The town a story place belongs to: a town itself, a town interior
## ("blancogov_temple" → "blancogov"), else "".
static func town_of(place: String) -> String:
	if TOWNS.has(place):
		return place
	for town: String in RealmLayout.town_names():
		if place.begins_with(town + "_") and TOWNS.has(town):
			return town
	return ""


static func prefers(tmpl: Dictionary, town: String) -> bool:
	var pages: Array = (TOWNS.get(town, {}) as Dictionary).get("pages", []) as Array
	return pages.has(BinderOps.page_of(tmpl))


## Sale price: the rarity's sell_gold, +BONUS when the town favours the card.
static func price(inst: Dictionary, tmpl: Dictionary, town: String) -> int:
	var cfg: Dictionary = IsoConst.RARITY_CONFIG.get(str(inst.get("rarity", "common")), {})
	var base: int = int(cfg.get("sell_gold", 0))
	return roundi(float(base) * (1.0 + BONUS)) if prefers(tmpl, town) else base


## "Maykalene's dockmaster pays +25% for Rift cards." — "" outside a town.
static func pitch(town: String) -> String:
	if not TOWNS.has(town):
		return ""
	var t: Dictionary = TOWNS[town]
	var names: Array[String] = []
	for p: Variant in t["pages"] as Array:
		names.append(BinderOps.page_label(str(p)))
	return "%s pays +%d%% for %s cards." % [str(t["who"]), roundi(BONUS * 100.0), " & ".join(names)]
