## QuestZones — the shaded "quest area" blobs the map views draw, WoW-style.
##
## A zone is an objective target ({map, tx, tz} or {map, site}) plus the spots
## the work actually happens at (`pts`, tile offsets from the target) and a
## reach in tiles (`r`). A kill objective at a starter camp takes the camp's
## enemy slots, so its blob hugs where the mobs stand; a story site gets one
## spot. `outline()` turns a zone into an organic closed shape (tile offsets).
##
## Pure static data — no autoloads — so tests and every map view read one rule.
extends RefCounted

const _StarterZone = preload("res://game_logic/world/StarterZone.gd")

## Tiles of reach around each enemy slot of a camp.
const R_CAMP: float = 6.5
## Tiles of reach around a story site (camp, ambush road).
const R_SITE: float = 6.0
## Outline vertices.
const _STEPS: int = 48

static var _outlines: Dictionary = {}


## The starter camp standing on overworld `tile`, or {}.
static func camp_at(tile: Vector2i) -> Dictionary:
	for c: Dictionary in _StarterZone.CAMPS:
		if c["tile"] == tile:
			return c
	return {}

## Zone for one overworld objective target: a camp's enemy slots when the
## target is a camp, else a single spot with the site reach.
static func for_target(t: Dictionary) -> Dictionary:
	var z: Dictionary = t.duplicate()
	var pts: Array[Vector2] = [Vector2.ZERO]
	var r: float = R_SITE
	if t.has("tx") and t.has("tz"):
		var camp: Dictionary = camp_at(Vector2i(int(t["tx"]), int(t["tz"])))
		if not camp.is_empty():
			r = R_CAMP
			for i: int in range(int(camp.get("count", 1))):
				pts.append(Vector2(_StarterZone.slot_tile(camp, i) - (camp["tile"] as Vector2i)))
	z["pts"] = pts
	z["r"] = r
	return z

## Zones over every camp whose mobs are `enemy_type` (bounty contracts).
static func for_enemy_type(enemy_type: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for c: Dictionary in _StarterZone.CAMPS:
		if str(c["enemy_type"]) == enemy_type:
			var tile: Vector2i = c["tile"]
			out.append(for_target({"map": "main", "tx": tile.x, "tz": tile.y}))
	return out

## Closed outline of `zone` as tile offsets from its target: the union of a
## circle of reach `r` around each spot, cast from the spots' centroid, with a
## gentle seeded wobble so it reads as a hand-drawn area rather than a circle.
static func outline(zone: Dictionary) -> PackedVector2Array:
	var pts: Array = zone.get("pts", [Vector2.ZERO])
	var r: float = float(zone.get("r", R_SITE))
	var key: String = "%s|%s" % [str(pts), r]
	if _outlines.has(key):
		return _outlines[key]
	var c := Vector2.ZERO
	for p: Vector2 in pts:
		c += p
	c /= float(maxi(1, pts.size()))
	var seed_a: float = float(hash(key) % 1000) * 0.01
	var out := PackedVector2Array()
	for i: int in range(_STEPS):
		var a: float = TAU * float(i) / float(_STEPS)
		var d := Vector2.from_angle(a)
		var reach: float = 0.0
		for p: Vector2 in pts:
			# Far hit of the ray c + d·s on the circle (p, r), if it crosses it.
			var off: Vector2 = p - c
			var along: float = off.dot(d)
			var perp2: float = off.length_squared() - along * along
			if perp2 <= r * r:
				reach = maxf(reach, along + sqrt(r * r - perp2))
		reach *= 1.0 + 0.07 * sin(3.0 * a + seed_a) + 0.05 * sin(5.0 * a + seed_a * 1.7)
		out.append(c + d * reach)
	_outlines[key] = out
	return out
