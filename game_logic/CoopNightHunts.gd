## Pure deterministic spawn planning for co-op Party Night Hunts (GID-103 / TID-383).
##
## Both the host and every client independently compute the *same* nightly spawn
## plan from (map_name, days_elapsed) — no network message carries the spawn
## itself (mirrors how a named map's authored enemies are identical on every peer
## by construction). Only the *discrete* lifecycle (engaged/removed/defeated) rides
## the existing GID-096 WorldObjectSync events, keyed by the deterministic id this
## file produces — the generic co-op engage-lock code in WorldScene needs no
## changes to support these enemies.
##
## Callers: preload("res://game_logic/CoopNightHunts.gd"). No scene dependencies.
extends RefCounted

## Maximum spectral enemies spawned per night per map.
const HUNT_SIZE: int = 4

## Fixed candidate offsets (world units) from the map's town-gate anchor
## (SiegeDefs.TOWN_GATES) — mirrors the fixed-offset pattern already used by
## WorldScene._spawn_siege_raiders for the same reason: named maps have no
## runtime walkability query available to pure logic, so offsets are hand-picked
## clear ground near the gate.
const _CANDIDATE_OFFSETS: Array[Vector2] = [
	Vector2(4.0, 3.0), Vector2(-4.0, 3.0), Vector2(4.0, -3.0), Vector2(-4.0, -3.0),
	Vector2(6.0, 0.0), Vector2(-6.0, 0.0), Vector2(0.0, 6.0), Vector2(0.0, -6.0),
]

## Spectral tiers, matching single-player Night Hunts (docs/agent/night-hunts.md).
const _TIERS: Array[String] = ["spectre_wisp", "spectre_haunt", "spectre_dread"]


## Only maps with a known gate anchor (SiegeDefs.TOWN_GATES) support night hunts —
## reuses that table rather than inventing a second per-map coordinate list.
static func supports_map(map_name: String) -> bool:
	const _SiegeDefs = preload("res://game_logic/SiegeDefs.gd")
	return _SiegeDefs.TOWN_GATES.has(map_name)


## Deterministic nightly spawn plan: Array[{id, enemy_type, offset}]. Identical on
## every peer given the same (map_name, days_elapsed) — days_elapsed alone (not
## time_of_day) keys the plan so it stays fixed for the whole night and both host
## and clients can derive it from the synced-clock day counter (TID-382) without
## needing the world seed broadcast too.
static func generate_hunt(map_name: String, days_elapsed: int) -> Array[Dictionary]:
	if not supports_map(map_name):
		return []
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(map_name + "_night_hunt_" + str(days_elapsed))
	var offsets: Array[Vector2] = _CANDIDATE_OFFSETS.duplicate()
	# Deterministic Fisher-Yates using the seeded rng — Array.shuffle() draws from
	# the engine's global RNG and would not reproduce identically across peers.
	for i in range(offsets.size() - 1, 0, -1):
		var j: int = rng.randi_range(0, i)
		var tmp: Vector2 = offsets[i]
		offsets[i] = offsets[j]
		offsets[j] = tmp
	var count: int = mini(HUNT_SIZE, offsets.size())
	var plan: Array[Dictionary] = []
	for i in range(count):
		var tier: String = _TIERS[rng.randi_range(0, _TIERS.size() - 1)]
		plan.append({
			"id": "night_hunt_%d_%d" % [days_elapsed, i],
			"enemy_type": tier,
			"offset": offsets[i],
		})
	return plan


## Card-drop rarity tier bonus (on top of the existing single-player night boost)
## scaled by connected party size. A 3+ member party gets a further +1 tier —
## a simple discrete stand-in for the "chance * (1 + 0.15 * extra members)"
## formula sketched in the task notes, since the existing drop system only has
## integer tiers to work with (see SceneManager._on_battle_won).
static func party_drop_tier_bonus(party_size: int) -> int:
	return 1 if party_size >= 3 else 0
