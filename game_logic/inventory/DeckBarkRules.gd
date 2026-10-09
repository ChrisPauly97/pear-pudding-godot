## Maiteln's one-line comments on the deck being built (GID-180 / TID-744).
## Same shape as `game_logic/battle/BarkRules.gd`: pure rules, a LINES table,
## a rate limit, no UI. InventoryScene calls `candidates` after each deck edit
## and shows whatever `next_bark` returns in the deck pile's speech bubble.
extends RefCounted

const CardRegistry = preload("res://autoloads/CardRegistry.gd")
const DeckInsights = preload("res://game_logic/inventory/DeckInsights.gd")
const TechniqueDefs = preload("res://game_logic/battle/TechniqueDefs.gd")

## Seconds between two barks.
const MIN_INTERVAL_S: float = 6.0

## Bark ids in priority order (most useful first). Text lives here so tests and
## the UI read the same copy.
const LINES: Dictionary = {
	"too_small": "That's not a deck, that's a hand. Add a few more.",
	"top_heavy": "Heavy top end, that. You'll stall early.",
	"no_early": "Nothing cheap to open with — give yourself a turn-one play.",
	"no_allies": "Not a single ally to stand beside you? Bold.",
	"no_spells": "All muscle, no magic. A spell or two wouldn't hurt.",
	"upgrade": "There's a stronger copy sitting in your bag. Swap it in.",
	"synergy": "Those cards like each other. Good eye.",
	"full": "Full to the brim. Shuffle it and try a hand.",
}
const ORDER: Array[String] = ["too_small", "top_heavy", "no_early", "no_allies", "no_spells", "upgrade",
	"synergy", "full"]


## Maiteln coaches the deck while he is the active companion, and before the
## companion system is learned (he is the starter-zone mentor then).
static func is_eligible(active_companion: String, companion_learned: bool) -> bool:
	return not companion_learned or active_companion == "maiteln"


## Bark ids that apply to `deck`, in ORDER. `bag` = cards outside the deck.
static func candidates(deck: Array, bag: Array, templates: Dictionary = {}) -> Array[String]:
	var out: Array[String] = []
	var cards: Array = deck.filter(func(i: Dictionary) -> bool:
		return not TechniqueDefs.is_technique(str(i.get("template_id", ""))))
	if deck.size() < IsoConst.DECK_MIN:
		out.append("too_small")
		return out
	var cheap: int = 0
	var heavy: int = 0
	var spells: int = 0
	for inst: Dictionary in cards:
		var c: int = int(inst.get("cost", 0))
		cheap += 1 if c <= 2 else 0
		heavy += 1 if c >= 5 else 0
		var t: Dictionary = templates.get(str(inst.get("template_id", "")), {}) if not templates.is_empty() \
				else CardRegistry.get_template(str(inst.get("template_id", "")))
		spells += 1 if str(t.get("card_class", "")) == "spell" else 0
	var n: int = maxi(cards.size(), 1)
	if float(heavy) / float(n) >= 0.35:
		out.append("top_heavy")
	if cheap < 3:
		out.append("no_early")
	if spells == n:
		out.append("no_allies")
	if spells == 0:
		out.append("no_spells")
	for b: Dictionary in bag:
		if DeckInsights.is_upgrade(b, deck):
			out.append("upgrade")
			break
	var kw: int = 0
	for p: Dictionary in DeckInsights.synergy_pairs(deck, templates):
		kw += 1 if str(p["kind"]) == "keyword" else 0
	if kw >= 2:
		out.append("synergy")
	if deck.size() >= IsoConst.DECK_MAX:
		out.append("full")
	return out


## The bark to show now, or "": the top candidate, unless it is the line just
## said or the last bark was under MIN_INTERVAL_S ago.
static func next_bark(cands: Array[String], last_id: String, since_last_s: float) -> String:
	if cands.is_empty() or since_last_s < MIN_INTERVAL_S:
		return ""
	for id: String in cands:
		if id != last_id:
			return id
	return ""


static func text_for(id: String) -> String:
	return str(LINES.get(id, ""))
