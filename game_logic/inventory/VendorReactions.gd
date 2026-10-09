## What the vendor says as a card slides across the counter (GID-180 / TID-745).
## Pure: picks a reaction id from facts about the card, plus the line table.
extends RefCounted

const LINES: Dictionary = {
	"perfect": ["Ooh — a perfect roll! You sure about this?", "Look at that edge. Flawless. I'll take it!"],
	"legendary": ["A legendary? My hands are shaking.", "This one's going behind glass."],
	"epic": ["Now that's a fine piece.", "Epic work. A fair price for it."],
	"preferred": ["Just what my regulars ask for!", "My kind of card — bonus for that one."],
	"veteran": ["This one's seen battle. Respect.", "Scuffed, but proud. I like it."],
	"duplicate": ["Another %s? Sigh.", "I've got a drawer full of %s already."],
	"plain": ["Hm. Fair enough.", "I'll find it a home.", "Into the bin it goes."],
	"basket": ["A whole basket! Let me count…", "Business is good today."],
}


## Reaction id for selling `inst`. `facts`: perfect (bool), preferred (bool),
## veteran (bool), copies_sold (how many of this template sold this visit).
static func reaction_for(inst: Dictionary, facts: Dictionary) -> String:
	if bool(facts.get("perfect", false)):
		return "perfect"
	var rarity: String = str(inst.get("rarity", "common"))
	if rarity == "legendary" or rarity == "epic":
		return rarity
	if bool(facts.get("preferred", false)):
		return "preferred"
	if bool(facts.get("veteran", false)):
		return "veteran"
	if int(facts.get("copies_sold", 0)) >= 1:
		return "duplicate"
	return "plain"


## The line for reaction `id`, rotating by `n`; `%s` is the card name.
static func line(id: String, n: int, card_name: String = "") -> String:
	var pool: Array = LINES.get(id, LINES["plain"]) as Array
	var text: String = str(pool[posmod(n, pool.size())])
	return text % card_name if text.contains("%s") else text
