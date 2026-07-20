## Cantrip system — deck-derived overworld abilities (GID-065).
## Pure static utility: no mutable state, headless-testable.
extends RefCounted

# Cooldown durations in seconds (tunable)
const GHOST_PHASE_COOLDOWN: float = 15.0
const SKELETON_DIG_COOLDOWN: float = 10.0

# Minimum deck-count thresholds to unlock each cantrip
const GHOST_PHASE_THRESHOLD: int = 4
const SKELETON_DIG_THRESHOLD: int = 4

static func _get_family(cantrip_id: String) -> Array[String]:
	match cantrip_id:
		"ghost_phase":
			return ["ghost", "dusk_wraith", "shrouded_wraith", "surge_spirit"]
		"skeleton_dig":
			return ["skeleton", "zombie", "ghoul", "blitz_ghoul", "iron_revenant"]
	return []

static func get_threshold(cantrip_id: String) -> int:
	match cantrip_id:
		"ghost_phase":
			return GHOST_PHASE_THRESHOLD
		"skeleton_dig":
			return SKELETON_DIG_THRESHOLD
	return 4

static func get_cooldown(cantrip_id: String) -> float:
	match cantrip_id:
		"ghost_phase":
			return GHOST_PHASE_COOLDOWN
		"skeleton_dig":
			return SKELETON_DIG_COOLDOWN
	return 30.0

static func _count_family(template_ids: Array[String], family: Array[String]) -> int:
	var count: int = 0
	for tid: String in template_ids:
		if family.has(tid):
			count += 1
	return count

## Returns true if the player's deck contains enough family cards for cantrip_id.
static func is_available(cantrip_id: String, template_ids: Array[String]) -> bool:
	var family: Array[String] = _get_family(cantrip_id)
	if family.is_empty():
		return false
	return _count_family(template_ids, family) >= get_threshold(cantrip_id)

## Public count for progress readouts (e.g. "3/4 Ghost cards") on a locked
## cantrip button — BID-050 discoverability fix.
static func count_family(cantrip_id: String, template_ids: Array[String]) -> int:
	return _count_family(template_ids, _get_family(cantrip_id))

## Returns all cantrip IDs available given the current deck.
static func available_cantrips(template_ids: Array[String]) -> Array[String]:
	var result: Array[String] = []
	for cid: String in ["ghost_phase", "skeleton_dig"]:
		if is_available(cid, template_ids):
			result.append(cid)
	return result

## Returns true if the cooldown expiry timestamp is in the future.
static func is_on_cooldown(cantrip_id: String, cooldowns: Dictionary, current_time: float) -> bool:
	var expiry: float = float(cooldowns.get(cantrip_id, 0.0))
	return current_time < expiry

## Seconds remaining on the cooldown (0 if not on cooldown).
static func cooldown_remaining(cantrip_id: String, cooldowns: Dictionary, current_time: float) -> int:
	var expiry: float = float(cooldowns.get(cantrip_id, 0.0))
	return int(ceil(max(0.0, expiry - current_time)))
