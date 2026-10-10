## Guardrail tests for enemy damage-school profiles (GID-181 / TID-750).
##
## Every enemy type carries a resist / weak profile (and bosses may carry a phase 2
## profile with immunities). These tests keep the table honest: every enemy has a
## profile, no enemy resists or immunes every school, immunity only appears in a
## boss's phase 2, and each biome roster gives every school at least one weakness
## without any school being resisted by the whole roster.
extends "res://tests/framework/test_case.gd"

const EnemyRegistry = preload("res://autoloads/EnemyRegistry.gd")
const _DamageSchools = preload("res://game_logic/battle/DamageSchools.gd")
const _BiomeDef = preload("res://game_logic/world/BiomeDef.gd")

const _KINDS: Array[String] = ["resist", "weak", "immune"]

func _tags(profile: Dictionary, kind: String) -> Array[String]:
	var out: Array[String] = []
	var tags: Dictionary = profile.get(kind, {})
	for k: Variant in tags.keys():
		out.append(str(k))
	return out

func _is_empty_profile(profile: Dictionary) -> bool:
	for kind: String in _KINDS:
		if not _tags(profile, kind).is_empty():
			return false
	return true

## Schools an enemy resists or is immune to (phase 1 profile).
func _blocked(profile: Dictionary) -> Array[String]:
	var out: Array[String] = _tags(profile, "resist")
	for s: String in _tags(profile, "immune"):
		if not out.has(s):
			out.append(s)
	return out

## Each biome's roster, sampled through the same lookup the world uses (type_for_biome).
func _biome_roster(biome: int) -> Array[String]:
	var pools: Array = _BiomeDef.ENEMY_POOLS
	var pool: Array = pools[biome]
	var out: Array[String] = []
	for i: int in range(pool.size()):
		var t: String = EnemyRegistry.type_for_biome(biome, i * 8)
		if not out.has(t):
			out.append(t)
	return out

func _check_roster(roster: Array[String], label: String) -> void:
	for school: String in _DamageSchools.all_schools():
		var weak_somewhere: bool = false
		var resisted_by_all: bool = true
		for id: String in roster:
			var p: Dictionary = EnemyRegistry.get_school_profile(id)
			if _DamageSchools.outcome(school, p) == _DamageSchools.WEAK:
				weak_somewhere = true
			if not _blocked(p).has(school):
				resisted_by_all = false
		assert_true(weak_somewhere, "%s: no enemy is weak to %s" % [label, school])
		assert_false(resisted_by_all, "%s: every enemy resists %s" % [label, school])

# ---------------------------------------------------------------------------
# Coverage and validity
# ---------------------------------------------------------------------------

func test_every_enemy_id_has_a_profile() -> void:
	var ids: Array[String] = EnemyRegistry.get_all_enemy_ids()
	assert_gt(ids.size(), 0)
	for id: String in ids:
		var p: Dictionary = EnemyRegistry.get_school_profile(id)
		assert_false(_is_empty_profile(p), "%s has no school profile" % id)

func test_profile_schools_are_valid() -> void:
	for id: String in EnemyRegistry.get_all_enemy_ids():
		for phase: int in [1, 2]:
			var p: Dictionary = EnemyRegistry.get_school_profile(id, phase)
			for kind: String in _KINDS:
				for s: String in _tags(p, kind):
					assert_true(_DamageSchools.is_school(s), "%s phase %d %s: unknown school %s" % [id, phase, kind, s])

func test_profile_shape_matches_damage_schools() -> void:
	var p: Dictionary = EnemyRegistry.get_school_profile("undead_basic")
	assert_true(p.has("resist") and p.has("weak") and p.has("immune"))
	assert_eq(_DamageSchools.outcome("dark", p), "resist")
	assert_eq(_DamageSchools.outcome("light", p), "weak")

func test_unknown_type_is_neutral() -> void:
	assert_true(_is_empty_profile(EnemyRegistry.get_school_profile("no_such_enemy")))
	assert_true(_is_empty_profile(EnemyRegistry.get_school_profile("no_such_enemy", 2)))

# ---------------------------------------------------------------------------
# Limits
# ---------------------------------------------------------------------------

func test_no_profile_resists_or_immunes_every_school() -> void:
	var all: Array[String] = _DamageSchools.all_schools()
	for id: String in EnemyRegistry.get_all_enemy_ids():
		for phase: int in [1, 2]:
			var blocked: Array[String] = _blocked(EnemyRegistry.get_school_profile(id, phase))
			assert_lt(blocked.size(), all.size(), "%s phase %d resists or immunes every school" % [id, phase])

func test_immunity_only_in_boss_phase_two() -> void:
	for id: String in EnemyRegistry.get_all_enemy_ids():
		var p1: Dictionary = EnemyRegistry.get_school_profile(id, 1)
		assert_true(_tags(p1, "immune").is_empty(), "%s has immunity in phase 1" % id)
		var p2: Dictionary = EnemyRegistry.get_school_profile(id, 2)
		if not _tags(p2, "immune").is_empty():
			assert_true(EnemyRegistry.is_boss(id), "%s is immune in phase 2 but is not a boss" % id)
			assert_gt(EnemyRegistry.get_phase2_deck(id).size(), 0,
				"%s is immune in phase 2 but has no phase 2 deck" % id)

func test_non_boss_phase_two_matches_phase_one() -> void:
	for id: String in EnemyRegistry.get_all_enemy_ids():
		if EnemyRegistry.is_boss(id):
			continue
		assert_eq(EnemyRegistry.get_school_profile(id, 2), EnemyRegistry.get_school_profile(id, 1),
			"%s changes profile in phase 2 but is not a boss" % id)

func test_boss_phase_two_override_grants_immunity() -> void:
	var p2: Dictionary = EnemyRegistry.get_school_profile("barrow_king", 2)
	assert_eq(_DamageSchools.outcome("dark", p2), "immune")
	var p1: Dictionary = EnemyRegistry.get_school_profile("barrow_king", 1)
	assert_eq(_DamageSchools.outcome("dark", p1), "resist")

# ---------------------------------------------------------------------------
# Biomes and the whole roster
# ---------------------------------------------------------------------------

func test_every_biome_roster_has_weak_targets_for_each_school() -> void:
	var pools: Array = _BiomeDef.ENEMY_POOLS
	for b: int in range(pools.size()):
		_check_roster(_biome_roster(b), "biome %d" % b)

func test_whole_roster_has_weak_targets_for_each_school() -> void:
	_check_roster(EnemyRegistry.get_all_enemy_ids(), "all enemies")

# ---------------------------------------------------------------------------
# Theme spot checks (lore / biome)
# ---------------------------------------------------------------------------

func test_undead_resist_dark_and_are_weak_to_light() -> void:
	var p: Dictionary = EnemyRegistry.get_school_profile("undead_horde")
	assert_eq(_DamageSchools.outcome("dark", p), "resist")
	assert_eq(_DamageSchools.outcome("light", p), "weak")

func test_forest_creatures_resist_verdant() -> void:
	assert_eq(_DamageSchools.outcome("verdant", EnemyRegistry.get_school_profile("bog_hag")), "resist")
	assert_eq(_DamageSchools.outcome("verdant", EnemyRegistry.get_school_profile("wolf_pack")), "resist")

func test_rift_beings_resist_rift_and_are_weak_to_light() -> void:
	var p: Dictionary = EnemyRegistry.get_school_profile("rift_echo")
	assert_eq(_DamageSchools.outcome("rift", p), "resist")
	assert_eq(_DamageSchools.outcome("light", p), "weak")

func test_armoured_golems_resist_physical() -> void:
	assert_eq(_DamageSchools.outcome("physical", EnemyRegistry.get_school_profile("stone_golem")), "resist")

# TID-751: enemy hero swings and heavy blows carry a school (default physical).

func test_attack_schools_are_valid_and_default_physical() -> void:
	for id: String in EnemyRegistry.get_all_enemy_ids():
		assert_true(_DamageSchools.is_school(EnemyRegistry.get_attack_school(id)), "bad attack school: " + id)
	assert_eq(EnemyRegistry.get_attack_school("wolf_pack"), "physical")
	assert_eq(EnemyRegistry.get_attack_school("no_such_enemy"), "physical")

func test_undead_and_forest_enemies_strike_with_their_school() -> void:
	assert_eq(EnemyRegistry.get_attack_school("undead_basic"), "dark")
	assert_eq(EnemyRegistry.get_attack_school("bog_hag"), "verdant")

func test_setup_enemy_fills_the_enemy_school_profile() -> void:
	const _PlayerState = preload("res://game_logic/battle/PlayerState.gd")
	const _BattleSetup = preload("res://game_logic/battle/BattleSetup.gd")
	var foe := _PlayerState.new(1, true)
	var me := _PlayerState.new(0, false)
	var deck: Array[String] = []
	_BattleSetup.setup_enemy(foe, me, "undead_basic", deck, 1, 1)
	assert_eq(foe.school_profile, EnemyRegistry.get_school_profile("undead_basic", 1))
