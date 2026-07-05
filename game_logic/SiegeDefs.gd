# Pure static helpers for the town siege system.
# No instance state — call all methods as SiegeDefs.method_name().

const SIEGE_SPAWN_CHANCE: int = 8   # ~8% daily probability once gating conditions are met

# World-space gate positions per named town (tile coords × TILE_SIZE = 2.0).
# Raiders spawn clustered around these positions.
const TOWN_GATES: Dictionary = {
	"madrian":     Vector3(10.0, 0.0, 16.0),   # tile (5, 8)
	"maykalene":   Vector3(24.0, 0.0, 12.0),   # tile (12, 6)
	"blancogov":   Vector3(16.0, 0.0, 8.0),    # tile (8, 4)
	# GID-108 / TID-407 — Chapter 2 story siege: the west-wall breach the hold
	# was already overrun through (see assets/maps/marsax_hold.tres).
	"marsax_hold": Vector3(50.0, 0.0, 100.0),  # tile (25, 50)
}

# Gate positions that qualify as "named towns" for siege purposes.
static func is_siege_town(map_name: String) -> bool:
	return TOWN_GATES.has(map_name)

## Returns true when all three siege conditions are satisfied:
##   1. Gating story flag chapter1_warned_farsyth is set.
##   2. At least 4 in-game days since the last siege.
##   3. Deterministic seeded probability (~8% per day).
static func should_trigger(flags: Dictionary, days_elapsed: int, last_siege_day: int, world_seed: int) -> bool:
	if not flags.get("chapter1_warned_farsyth", false):
		return false
	if days_elapsed - last_siege_day < 4:
		return false
	return hash(world_seed ^ days_elapsed) % 100 < SIEGE_SPAWN_CHANCE

## Returns the card ID list for the given gauntlet stage (0, 1, or 2).
## Difficulty escalates: stage 0 is easiest, stage 2 is hardest.
static func get_raider_deck_ids(stage: int) -> Array[String]:
	match stage:
		0:
			return ["ghost", "ghost", "zombie", "zombie", "ghoul"]
		1:
			return ["ghost", "skeleton", "zombie", "zombie", "ghoul", "ghoul"]
		2:
			return ["ghost", "skeleton", "skeleton", "zombie", "zombie", "ghoul", "ghoul"]
	return ["ghost", "ghost", "skeleton", "zombie"]

## Returns the interstitial stage name shown between gauntlet waves.
static func get_stage_name(stage: int) -> String:
	match stage:
		0: return "Wave 1 of 3"
		1: return "Wave 2 of 3"
		2: return "Wave 3 of 3"
	return "Wave"
