## TownDecor — set pieces placed in the stitched story towns (GID-167 / TID-688),
## e.g. the fountain in the middle of Madrian's square.
##
## Pure static data, no autoloads. Each piece blocks a square of town-local tiles:
## TownStreets routes around it (so walkers never cross it), tap-to-move treats it
## as a wall, and the StarterCamps module draws it with a collision cylinder.
extends RefCounted

## town → [{key, tile (town-local centre), radius (tiles blocked each side), height (world units)}]
const PIECES: Dictionary = {
	"madrian": [{"key": "fountain", "tile": Vector2i(30, 28), "radius": 1, "height": 4.2}],
}


static func pieces(town: String) -> Array:
	return PIECES.get(town, []) as Array


## Town-local tiles covered by `town`'s pieces (Vector2i → true).
static func blocked_local(town: String) -> Dictionary:
	var out: Dictionary = {}
	for p: Dictionary in pieces(town):
		var c: Vector2i = p["tile"]
		var r: int = int(p["radius"])
		for dz: int in range(-r, r + 1):
			for dx: int in range(-r, r + 1):
				out[c + Vector2i(dx, dz)] = true
	return out
