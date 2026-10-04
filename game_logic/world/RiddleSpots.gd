## Riddle spots — the Pear Pudding legend's world puzzles (GID-153 / TID-655).
##
## Each spot is scenery until its tale (Tales.gd) has been heard and its
## condition holds: the right hour, the right weather, the right action (Dig or
## a plain look), and any ingredient flags. No marker ever points at one.
## Pure static data + `evaluate()`, so the rules are unit-tested without a world.
##
## Keys: id, prop (texture key in SpriteRegistry legend props), tile (overworld tile),
##       height (billboard world height), tale (Tales id that makes it meaningful),
##       needs (story flags), time ("" | "dawn" | "day" | "dusk" | "night"),
##       weather ([] = any, else weather ids), action ("interact" | "dig"),
##       sets_flag, name, idle, hint, missing, solved, done (dialogue lines).
extends RefCounted

const _Tales = preload("res://game_logic/quests/Tales.gd")

const RESULT_IDLE: String = "idle"        # tale not heard: plain scenery
const RESULT_HINT: String = "hint"        # tale heard, wrong hour / weather / action
const RESULT_MISSING: String = "missing"  # right moment, ingredients missing
const RESULT_SOLVED: String = "solved"    # the riddle resolves now
const RESULT_DONE: String = "done"        # already solved

## Spectre's Sigh ("Ask the dead what they sighed"): beating a spectre (Night Hunts)
## once the bard's tale is heard, while carrying the Burnt Recipe.
const SIGH_FLAG: String = "legend_sigh"
const SIGH_TEXT: String = ("As the spectre fades, it lets out one last sigh — and the scorched recipe in your pack "
	+ "drinks it in. A faint new line glows on the vellum: \"...a spectre's sigh.\"")
## Set by the queen's well; owning it means owning Perrine's Bottomless Pudding.
const PUDDING_FLAG: String = "legend_pudding_owned"

const SPOTS: Array[Dictionary] = [
	{"id": "leaning_stones", "prop": "legend_stones", "tile": Vector2i(-6, 46), "height": 2.6,
		"tale": "soldier", "needs": [], "time": "dusk", "weather": [], "action": "dig",
		"sets_flag": "legend_recipe", "name": "Three Leaning Stones",
		"idle": "Three old stones lean together, as if sharing a secret.",
		"hint": ("Three stones lean... Old Garrick's words come back to you. The light is wrong. "
			+ "Perhaps when the sun goes down, and with a spade in hand."),
		"missing": "",
		"solved": ("The dusk shadows of the three stones meet on one patch of earth. You dig — and pull up a "
			+ "scorched scrap of vellum. Half a recipe, in a spidery hand: \"Mother Perrine's Pudding.\""),
		"done": "The earth between the stones lies turned and quiet."},
	{"id": "golden_pear_tree", "prop": "legend_pear_tree", "tile": Vector2i(112, 148), "height": 4.2,
		"tale": "rhyme", "needs": [], "time": "", "weather": [], "action": "interact",
		"sets_flag": "legend_golden_pear", "name": "A Lone Pear Tree",
		"idle": "A gnarled old tree, far from any orchard. Something golden glints in its boughs.",
		"hint": "", "missing": "",
		"solved": ("Pear so gold, never old... You reach up and twist it free. It is warm, and smells of "
			+ "honey. It has not a single bruise."),
		"done": "The old tree rustles. Its one golden pear is gone; you have it."},
	{"id": "queens_well", "prop": "legend_well", "tile": Vector2i(-62, 300), "height": 1.8,
		"tale": "farmer", "needs": ["legend_recipe", "legend_golden_pear", "legend_sigh"], "time": "",
		"weather": ["rain", "storm"], "action": "interact",
		"sets_flag": "legend_pudding_owned", "name": "The Queen's Well",
		"idle": "A ring of tumbled stones around a dry, dark shaft.",
		"hint": "\"...when the rain sings.\" The well is dry rubble under a dry sky. Not yet.",
		"missing": ("The rain sings on the old stones and water gathers in the well. But the recipe asks for "
			+ "more than you carry: the burnt scrap, a pear that never rots, and a spectre's sigh."),
		"solved": ("Rain pours into the old queen's well. You stir in the golden pear, the moonroot and the "
			+ "spectre's sigh as the recipe says, and the brew turns thick and gold. Perrine's Pudding — "
			+ "and the flask never seems to empty."),
		"done": "Rain or shine, the old well is just stones now. Its secret travels with you."},
]


static func def(spot_id: String) -> Dictionary:
	for s: Dictionary in SPOTS:
		if str(s["id"]) == spot_id:
			return s
	return {}


## Time-of-day phase for `t` in [0, 1): sunrise at 0.25, sunset at 0.75 (DayNightCycle.is_night).
static func phase(t: float) -> String:
	t = fposmod(t, 1.0)
	if t >= 0.70 and t < 0.80:
		return "dusk"
	if t >= 0.20 and t < 0.30:
		return "dawn"
	return "night" if sin((t - 0.25) * TAU) < 0.0 else "day"


## What happens when the player tries `action` at `spot`. `ctx`: {flags: Dictionary,
## time_of_day: float, weather: String}.
static func evaluate(spot: Dictionary, action: String, ctx: Dictionary) -> String:
	var flags: Dictionary = ctx.get("flags", {})
	if bool(flags.get(str(spot["sets_flag"]), false)):
		return RESULT_DONE
	if not _Tales.is_heard(str(spot["tale"]), flags):
		return RESULT_IDLE
	var want_time: String = str(spot.get("time", ""))
	var weathers: Array = spot.get("weather", [])
	var right_moment: bool = action == str(spot.get("action", "interact")) \
			and (want_time == "" or phase(float(ctx.get("time_of_day", 0.4))) == want_time) \
			and (weathers.is_empty() or weathers.has(str(ctx.get("weather", ""))))
	if not right_moment:
		return RESULT_HINT
	for f: Variant in spot.get("needs", []):
		if not bool(flags.get(str(f), false)):
			return RESULT_MISSING
	return RESULT_SOLVED


## Spectre's Sigh ("Ask the dead what they sighed"): beating a spectre (Night Hunts)
## once the bard's tale is heard, while carrying the Burnt Recipe.
static func earns_sigh(enemy_type: String, flags: Dictionary) -> bool:
	return enemy_type.begins_with("spectre") and _Tales.is_heard("bard", flags) \
			and bool(flags.get("legend_recipe", false)) and not bool(flags.get(SIGH_FLAG, false))


## The line to show for `result` (hint/missing fall back to idle when a spot has none).
static func line_for(spot: Dictionary, result: String) -> String:
	var text: String = str(spot.get(result, ""))
	return text if text != "" else str(spot.get("idle", ""))
