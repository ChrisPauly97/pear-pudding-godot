## Pure deterministic wave planning for the co-op Town Siege event
## (GID-103 / TID-384).
##
## Every peer independently computes the *same* wave plan from
## (map_name, siege_id, wave) — the host only broadcasts *when* to advance
## (recv_siege_wave / recv_siege_boss_phase); the actual enemy ids/types/
## positions are derived identically everywhere, exactly like CoopNightHunts.
## Lifecycle (engaged/removed/defeated) rides the existing GID-096
## WorldObjectSync events, keyed by the deterministic ids this file produces.
##
## Callers: preload("res://game_logic/CoopSiege.gd"). No scene dependencies.
extends RefCounted

## Number of raider waves before the finale boss phase.
const WAVE_COUNT: int = 3

## Fixed candidate offsets (world units) from the map's town-gate anchor
## (SiegeDefs.TOWN_GATES) — same fixed-offset-near-gate technique as
## WorldScene._spawn_siege_raiders (single-player) and CoopNightHunts.
const _CANDIDATE_OFFSETS: Array[Vector2] = [
	Vector2(0.0, 0.0), Vector2(2.0, 1.0), Vector2(-2.0, 1.0), Vector2(2.0, -1.0),
	Vector2(-2.0, -1.0), Vector2(4.0, 0.0), Vector2(-4.0, 0.0), Vector2(0.0, 3.0),
]

## Boss finale enemy type — reuses the existing "roaming borderland horror that
## follows in the Martarquas's wake" boss data as-is (EnemyRegistry.gd), whose
## lore already ties it to this exact conflict, so no new enemy data is needed.
const _BOSS_ENEMY_TYPE: String = "roaming_terror"


## Only maps with a known gate anchor support a co-op siege.
static func supports_map(map_name: String) -> bool:
	const _SiegeDefs = preload("res://game_logic/SiegeDefs.gd")
	return _SiegeDefs.TOWN_GATES.has(map_name)


## Number of raiders in a given wave (0-indexed), escalating by 1 per wave.
static func wave_enemy_count(wave: int) -> int:
	return clampi(wave + 2, 2, _CANDIDATE_OFFSETS.size())


## Raider enemy type for a given wave — escalates through the three existing
## martarquas_raider tiers (same data single-player Town Siege uses).
static func wave_enemy_type(wave: int) -> String:
	return "martarquas_raider_%d" % clampi(wave + 1, 1, 3)


## Deterministic wave spawn plan: Array[{id, enemy_type, offset}].
static func generate_wave(map_name: String, siege_id: int, wave: int) -> Array[Dictionary]:
	if not supports_map(map_name):
		return []
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(str(siege_id) + "_wave_" + str(wave) + "_" + map_name)
	var offsets: Array[Vector2] = _CANDIDATE_OFFSETS.duplicate()
	for i in range(offsets.size() - 1, 0, -1):
		var j: int = rng.randi_range(0, i)
		var tmp: Vector2 = offsets[i]
		offsets[i] = offsets[j]
		offsets[j] = tmp
	var count: int = wave_enemy_count(wave)
	var etype: String = wave_enemy_type(wave)
	var plan: Array[Dictionary] = []
	for i in range(count):
		plan.append({
			"id": "siege_wave_%d_%d_enemy_%d" % [siege_id, wave, i],
			"enemy_type": etype,
			"offset": offsets[i],
		})
	return plan


## The boss's deterministic world-object id for a given siege.
static func boss_id(siege_id: int) -> String:
	return "siege_boss_%d" % siege_id


static func boss_enemy_type() -> String:
	return _BOSS_ENEMY_TYPE
