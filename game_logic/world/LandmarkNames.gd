extends RefCounted

const InfiniteWorldGen = preload("res://game_logic/world/InfiniteWorldGen.gd")

# Deterministic name generator: same (cx, cz, world_seed) → same name.
# Format: "The <epithet> <noun> of the <place>"

const _EPITHETS: Array[String] = [
	"Kneeling", "Silent", "Sunken", "Broken", "Watchful",
	"Ancient", "Forgotten", "Shattered", "Towering", "Slumbering",
]

const _NOUNS_BY_VARIANT: Dictionary = {
	"obelisk_ring":       ["Circle", "Ring", "Stones", "Pillars"],
	"stone_head":         ["Visage", "Face", "Watcher", "Gaze"],
	"kneeling_colossus":  ["King", "Giant", "Sentinel", "Colossus"],
	"shattered_spire":    ["Needle", "Fang", "Spire", "Shard"],
	"broken_arch":        ["Gate", "Arch", "Bridge", "Threshold"],
}

const _PLACES_BY_BIOME: Dictionary = {
	0: ["the Meadows", "the Sunlit Plain", "the Green Hills"],          # GRASSLANDS
	1: ["the Deep Wood", "the Ancient Forest", "the Darkened Canopy"], # FOREST
	2: ["the Endless Sands", "the Scorching Wastes", "the Dune Sea"],  # DESERT
	3: ["the Cinder Fields", "the Ashen Waste", "the Ember Reaches"],  # SCORCHED
	4: ["the High Peaks", "the Frozen Heights", "the Stone Crown"],    # MOUNTAINS
}

# Returns the procedural display name for a landmark.
static func get_name(cx: int, cz: int, world_seed: int) -> String:
	var data: Dictionary = InfiniteWorldGen.landmark_for_chunk(cx, cz, world_seed)
	if data.is_empty():
		return ""
	var variant: String = str(data.get("variant", "obelisk_ring"))
	var biome: int = int(data.get("biome", 0))
	# Use the same landmark hash for deterministic word selection
	var h: int = (cx * 16769023) ^ (cz * 6972593) ^ world_seed
	h = h & 0x7FFFFFFF
	var epithet: String = _EPITHETS[int(h % _EPITHETS.size())]
	var nouns: Array = _NOUNS_BY_VARIANT.get(variant, ["Stone"])
	var noun: String = nouns[int((h >> 8) % nouns.size())]
	var places: Array = _PLACES_BY_BIOME.get(biome, ["the Unknown Lands"])
	var place: String = places[int((h >> 16) % places.size())]
	return "The %s %s of %s" % [epithet, noun, place]

# Parses cx/cz from a landmark id ("landmark_cx_cz") and returns the display name.
static func name_from_id(landmark_id: String, world_seed: int) -> String:
	var parts: PackedStringArray = landmark_id.split("_")
	if parts.size() < 3:
		return landmark_id
	var cx: int = int(parts[1])
	var cz: int = int(parts[2])
	return get_name(cx, cz, world_seed)
