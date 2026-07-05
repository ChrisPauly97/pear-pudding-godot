## Unit tests for Chapter 2 content wiring (GID-108 / TID-407):
## the war-camp boss EnemyData, the story siege town gate, and the
## dungeon-door seed/flag gating on marsax_hold.tres.
extends "res://tests/framework/test_case.gd"

const EnemyRegistryScript = preload("res://autoloads/EnemyRegistry.gd")
const SiegeDefsScript = preload("res://game_logic/SiegeDefs.gd")
const WorldMapScript = preload("res://game_logic/world/WorldMap.gd")

# ---------------------------------------------------------------------------
# martarquas_warleader (war-camp dungeon boss)
# ---------------------------------------------------------------------------

func test_warleader_is_boss() -> void:
	assert_true(EnemyRegistryScript.get_is_boss("martarquas_warleader"))


func test_warleader_boss_hp() -> void:
	assert_eq(EnemyRegistryScript.get_boss_hp("martarquas_warleader"), 45)


func test_warleader_has_phase2_deck() -> void:
	assert_gt(EnemyRegistryScript.get_phase2_deck("martarquas_warleader").size(), 0)


func test_warleader_difficulty_tier_is_four() -> void:
	assert_eq(EnemyRegistryScript.get_difficulty_tier("martarquas_warleader"), 4)


func test_warleader_excluded_from_bestiary() -> void:
	# Story/siege/special enemies are excluded from bestiary completion —
	# matches the treatment of martarquas_raider_1/2/3 and rival_isfig_1/2/3.
	assert_false(EnemyRegistryScript.get_bestiary_enemy_ids().has("martarquas_warleader"))


# ---------------------------------------------------------------------------
# Story siege town gate (SiegeDefs)
# ---------------------------------------------------------------------------

func test_marsax_hold_is_siege_town() -> void:
	assert_true(SiegeDefsScript.is_siege_town("marsax_hold"))


func test_marsax_hold_has_a_gate_position() -> void:
	assert_true(SiegeDefsScript.TOWN_GATES.has("marsax_hold"))


# ---------------------------------------------------------------------------
# marsax_hold.tres door gating
# ---------------------------------------------------------------------------

func _door_by_id(wm: RefCounted, id: String) -> Dictionary:
	for d in wm.doors:
		if str(d.get("id", "")) == id:
			return d
	return {}


func test_warcamp_door_gated_on_traitor_seal() -> void:
	var wm: RefCounted = WorldMapScript.new("marsax_hold")
	var d: Dictionary = _door_by_id(wm, "door_2")
	assert_eq(str(d.get("flag_key", "")), "chapter2_traitor_seal")
	assert_true(str(d.get("target_map", "")).begins_with("dungeon_"))
