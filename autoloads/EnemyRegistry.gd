extends Node

# Enemy type definitions — each entry has a display name and a battle deck.
# Decks are lists of card template IDs (duplicates allowed, same as player decks).
const _TYPES: Dictionary = {
	"undead_basic": {
		"name": "Undead Wanderer",
		"deck": [
			"ghost", "ghost", "ghost",
			"skeleton", "skeleton", "skeleton",
			"zombie", "zombie", "zombie",
			"ghoul",
		],
	},
	"undead_horde": {
		"name": "Horde Shambler",
		"deck": [
			"ghost", "ghost", "ghost", "ghost",
			"skeleton", "skeleton", "skeleton",
			"zombie", "zombie",
			"ghoul", "ghoul",
		],
	},
	"ghoul_pack": {
		"name": "Ghoul Pack Leader",
		"deck": [
			"ghoul", "ghoul", "ghoul", "ghoul",
			"zombie", "zombie", "zombie", "zombie",
			"skeleton", "skeleton", "skeleton", "skeleton",
		],
	},
	"undead_elite": {
		"name": "Undead Warlord",
		"deck": [
			"ghoul", "ghoul", "ghoul", "ghoul", "ghoul",
			"zombie", "zombie", "zombie", "zombie",
			"skeleton", "skeleton", "skeleton",
		],
	},
}

# Returns the battle deck for a type. Falls back to undead_basic if unknown.
func get_deck(type_id: String) -> Array[String]:
	var result: Array[String] = []
	if _TYPES.has(type_id):
		var entry: Dictionary = _TYPES[type_id]
		result.assign(entry.get("deck", []))
	else:
		result = ["ghost", "ghost", "skeleton", "skeleton",
				  "zombie", "zombie", "ghoul", "ghoul"]
	return result

# Returns the display name for a type.
func get_display_name(type_id: String) -> String:
	if _TYPES.has(type_id):
		var entry: Dictionary = _TYPES[type_id]
		return str(entry.get("name", type_id))
	return type_id

# Selects an enemy type based on depth through a named map (0 = start, 1 = end).
func type_for_depth(depth: int, max_depth: int) -> String:
	var pct: float = float(depth) / float(max(max_depth, 1))
	if pct < 0.33:
		return "undead_basic"
	elif pct < 0.66:
		return "undead_horde"
	return "ghoul_pack"

# Selects an enemy type based on Manhattan distance from the world origin chunk.
func type_for_chunk_dist(dist: int) -> String:
	if dist <= 3:
		return "undead_basic"
	elif dist <= 8:
		return "undead_horde"
	elif dist <= 14:
		return "ghoul_pack"
	return "undead_elite"
