## Matchup loadouts (GID-181 / TID-756): ranks the player's saved deck loadouts against an
## enemy's KNOWN weak and resist schools. Pure: it takes school lists, not cards, so the unit
## tests load it directly. The UI (scenes/ui/LoadoutSwapRow.gd) maps each loadout's card ids
## to schools and passes the enemy's gated weak / resist lists (SchoolKnowledge.journal_view).
##
## Score = the number of loadout cards whose school the enemy is WEAK to (each one hits for
## the weak multiplier). Ties go to the loadout with fewer cards in a school the enemy RESISTS,
## then to the lower loadout index. A loadout that is not valid (card count out of range) is
## ranked but never the best match.
extends RefCounted

## Cards in `schools` whose school the enemy is weak to.
static func weak_hits(schools: Array[String], weak: Array[String]) -> int:
	var n: int = 0
	for s: String in schools:
		if weak.has(s):
			n += 1
	return n

## Cards in `schools` whose school the enemy resists (or is immune to).
static func resist_hits(schools: Array[String], resist: Array[String]) -> int:
	var n: int = 0
	for s: String in schools:
		if resist.has(s):
			n += 1
	return n

## `entries`: [{"index": int, "name": String, "schools": Array, "valid": bool}].
## Returns copies of each entry with "weak_hits", "resist_hits" and "score" added, sorted
## best first (valid before invalid, then score, then fewer resist hits, then index).
static func rank(entries: Array[Dictionary], weak: Array[String], resist: Array[String]) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for e: Dictionary in entries:
		var schools: Array[String] = []
		schools.assign(e.get("schools", []))
		var row: Dictionary = e.duplicate()
		var w: int = weak_hits(schools, weak)
		row["weak_hits"] = w
		row["resist_hits"] = resist_hits(schools, resist)
		row["score"] = w
		out.append(row)
	out.sort_custom(_better)
	return out

## The index of the best matching loadout in a `rank()` result, or -1 when none is a
## valid loadout with at least one weak hit (an unknown enemy profile never highlights).
static func best_index(ranked: Array[Dictionary]) -> int:
	if ranked.is_empty():
		return -1
	var top: Dictionary = ranked[0]
	if not bool(top.get("valid", false)) or int(top.get("score", 0)) <= 0:
		return -1
	return int(top.get("index", -1))

static func _better(a: Dictionary, b: Dictionary) -> bool:
	var av: bool = bool(a.get("valid", false))
	var bv: bool = bool(b.get("valid", false))
	if av != bv:
		return av
	var sa: int = int(a.get("score", 0))
	var sb: int = int(b.get("score", 0))
	if sa != sb:
		return sa > sb
	var ra: int = int(a.get("resist_hits", 0))
	var rb: int = int(b.get("resist_hits", 0))
	if ra != rb:
		return ra < rb
	return int(a.get("index", 0)) < int(b.get("index", 0))
