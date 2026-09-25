## Player-facing names for map ids (GID-134 / TID-517). Map ids are internal
## (`dungeon_48213`, `marsax_hold`); door labels and the HUD show these instead.
## Dungeon names are hashed from the id, so a dungeon keeps its name.
extends RefCounted

const _BattlefieldRules = preload("res://game_logic/battle/BattlefieldRules.gd")

const TITLES: Dictionary = {
	"main": "The Wilds",
	"madrian": "Madrian",
	"blancogov": "Blancogov",
	"blancogov_temple": "Blancogov Temple",
	"farsyth_mansion": "Farsyth Mansion",
	"guildhall": "Guildhall",
	"larik": "Larik",
	"marsax_hold": "Marsax Hold",
	"maykalene": "Maykalene",
	"player_home": "Your Home",
	"spire": "The Endless Spire",
}

const DUNGEON_ADJECTIVES: Array[String] = [
	"Hollow", "Sunken", "Forgotten", "Whispering", "Mossy", "Shattered", "Silent", "Ashen",
	"Drowned", "Gloom", "Crooked", "Old",
]
const DUNGEON_NOUNS: Array[String] = [
	"Crypt", "Barrow", "Vault", "Catacombs", "Warren", "Undercroft", "Tomb", "Cellars",
]


## The name to show for `map_id`; empty for an empty id.
static func title(map_id: String) -> String:
	if map_id.is_empty():
		return ""
	if TITLES.has(map_id):
		return str(TITLES[map_id])
	if map_id.begins_with("dungeon_"):
		return dungeon_title(map_id)
	if map_id.begins_with("spire_floor_"):
		return "Spire — Floor %s" % map_id.trim_prefix("spire_floor_")
	return map_id.replace("_", " ").capitalize()


## Infinite-world HUD title for the biome the player is in.
static func biome_title(biome_id: int) -> String:
	return _BattlefieldRules.get_biome_name(biome_id) if biome_id >= 0 else str(TITLES["main"])


static func dungeon_title(map_id: String) -> String:
	var h: int = absi(hash(map_id))
	var adj: String = DUNGEON_ADJECTIVES[h % DUNGEON_ADJECTIVES.size()]
	var noun: String = DUNGEON_NOUNS[(h / DUNGEON_ADJECTIVES.size()) % DUNGEON_NOUNS.size()]
	return "The %s %s" % [adj, noun]
