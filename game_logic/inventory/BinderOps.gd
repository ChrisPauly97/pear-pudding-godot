## Pure binder rules for the deck table (GID-180 / TID-739): magic-type pages,
## stacking same-template + same-rarity copies, and the silhouettes of cards on
## a page the player has not found yet.
extends RefCounted

const MagicTypes = preload("res://game_logic/MagicTypes.gd")
const DeckInsights = preload("res://game_logic/inventory/DeckInsights.gd")

## Binder pages in tab order. "all" shows the whole bag and no silhouettes.
const PAGES: Array[String] = ["all", "light", "dark", "verdant", "rift", "neutral"]


static func page_label(page: String) -> String:
	if page == "all":
		return "All"
	if page == "neutral":
		return "Neutral"
	return MagicTypes.display_name(page)


## The page a template lives on: its magic type, or "neutral".
static func page_of(tmpl: Dictionary) -> String:
	var mt: String = str(tmpl.get("magic_type", ""))
	return mt if MagicTypes.is_valid_type(mt) else "neutral"


static func on_page(tmpl: Dictionary, page: String) -> bool:
	return page == "all" or page_of(tmpl) == page


static func stack_key(inst: Dictionary) -> String:
	return "%s|%s" % [str(inst.get("template_id", "")), str(inst.get("rarity", "common"))]


## Groups `insts` (already in display order) into stacks of one template+rarity.
## Each stack: {key, best, copies (best first), in_decks (copies sitting in some deck)}.
## `best` prefers a copy that is in no deck, so tapping the stack never steals
## a card from another loadout while a free copy exists.
static func stack(insts: Array[Dictionary], membership: Dictionary) -> Array[Dictionary]:
	var order: Array[String] = []
	var groups: Dictionary = {}
	for inst: Dictionary in insts:
		var k: String = stack_key(inst)
		if not groups.has(k):
			groups[k] = []
			order.append(k)
		(groups[k] as Array).append(inst)
	var out: Array[Dictionary] = []
	for k: String in order:
		var copies: Array[Dictionary] = []
		copies.assign(groups[k] as Array)
		copies.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			var fa: bool = membership.has(str(a.get("uid", "")))
			var fb: bool = membership.has(str(b.get("uid", "")))
			if fa != fb:
				return not fa
			return DeckInsights.power_score(a) > DeckInsights.power_score(b))
		var in_decks: int = 0
		for c: Dictionary in copies:
			if membership.has(str(c.get("uid", ""))):
				in_decks += 1
		out.append({"key": k, "best": copies[0], "copies": copies, "in_decks": in_decks})
	return out


## Template ids on `page` that the player owns no copy of (anywhere, decks included).
static func missing_on_page(page: String, owned_tids: Dictionary, all_ids: Array[String],
		tmpl_for: Callable) -> Array[String]:
	var out: Array[String] = []
	if page == "all":
		return out
	for tid: String in all_ids:
		if owned_tids.has(tid):
			continue
		var t: Dictionary = tmpl_for.call(tid)
		if page_of(t) == page:
			out.append(tid)
	out.sort()
	return out


## Vector2i(found, total) of distinct templates on `page`.
static func page_progress(page: String, owned_tids: Dictionary, all_ids: Array[String],
		tmpl_for: Callable) -> Vector2i:
	var found: int = 0
	var total: int = 0
	for tid: String in all_ids:
		var t: Dictionary = tmpl_for.call(tid)
		if not on_page(t, page):
			continue
		total += 1
		if owned_tids.has(tid):
			found += 1
	return Vector2i(found, total)
