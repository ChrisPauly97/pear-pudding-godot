## GID-142 / TID-597: per-biome rifts with their own tier ladders.
extends "res://tests/framework/test_case.gd"

const RiftDefs = preload("res://game_logic/spire/RiftDefs.gd")
const BiomeDef = preload("res://game_logic/world/BiomeDef.gd")
const EnemyRegistry = preload("res://autoloads/EnemyRegistry.gd")
const SpireFloorGen = preload("res://game_logic/spire/SpireFloorGen.gd")
const SaveMigrations = preload("res://game_logic/save/SaveMigrations.gd")
const SaveManagerScript = preload("res://autoloads/SaveManager.gd")
const WorldMapScript = preload("res://game_logic/world/WorldMap.gd")


func test_one_rift_per_biome_with_real_enemies() -> void:
	assert_eq(RiftDefs.all().size(), BiomeDef.COUNT)
	var biomes: Dictionary = {}
	for r: Dictionary in RiftDefs.all():
		biomes[int(r["biome"])] = true
		for f: int in range(1, RiftDefs.FLOORS_PER_TIER + 1):
			var etype: String = RiftDefs.enemy_type(str(r["id"]), f)
			assert_false(EnemyRegistry.get_deck(etype).is_empty(), "%s floor %d: %s has a deck" % [r["id"], f, etype])
	assert_eq(biomes.size(), BiomeDef.COUNT, "every biome has its rift")


func test_guardian_on_last_floor_and_levels_climb() -> void:
	assert_true(RiftDefs.is_guardian_floor(RiftDefs.FLOORS_PER_TIER))
	assert_false(RiftDefs.is_guardian_floor(RiftDefs.FLOORS_PER_TIER - 1))
	assert_eq(RiftDefs.enemy_type("mountains", RiftDefs.FLOORS_PER_TIER), "stone_golem")
	assert_gt(RiftDefs.enemy_level(2, 1), RiftDefs.enemy_level(1, 1), "higher tier, higher level")
	assert_gt(RiftDefs.enemy_level(1, RiftDefs.FLOORS_PER_TIER), RiftDefs.enemy_level(1, 1), "guardian tougher")


func test_tier_cap_is_best_plus_one() -> void:
	assert_eq(RiftDefs.max_start_tier(0), 1)
	assert_eq(RiftDefs.max_start_tier(4), 5)
	assert_eq(RiftDefs.clamp_tier(9, 4), 5)
	assert_eq(RiftDefs.clamp_tier(0, 4), 1)


func test_floor_gen_uses_the_rift() -> void:
	var run: Dictionary = {"rift": "desert", "tier": 3}
	var wm: WorldMapScript = SpireFloorGen.generate(2, 777, run)
	var e: Dictionary = wm.enemies[0]
	assert_eq(str(e["enemy_type"]), RiftDefs.enemy_type("desert", 2))
	assert_eq(int(e["enemy_level"]), RiftDefs.enemy_level(3, 2))


func test_each_rift_tracks_its_own_tier() -> void:
	var sm: SaveManagerScript = SaveManagerScript.new()
	sm.new_game(false)
	sm.spire.start_spire_run(1, "forest", 1)
	for _i: int in range(RiftDefs.FLOORS_PER_TIER):
		sm.spire.advance_spire_floor()
	assert_true(sm.spire.tier_complete())
	var stats: Dictionary = sm.spire.end_spire_run()
	assert_true(bool(stats["tier_cleared"]))
	assert_eq(sm.spire.best_tier("forest"), 1)
	assert_eq(sm.spire.best_tier("desert"), 0, "other rifts untouched")
	sm.spire.start_spire_run(2, "forest", 99)
	assert_eq(int(sm.spire.get_spire_run()["tier"]), 2, "clamped to best + 1")
	sm.spire.advance_spire_floor()
	var fail: Dictionary = sm.spire.end_spire_run()
	assert_false(bool(fail["tier_cleared"]), "leaving early clears nothing")
	assert_eq(sm.spire.best_tier("forest"), 1)


func test_migration_maps_old_spire_best_to_grasslands() -> void:
	var d: Dictionary = {"version": 44, "spire_best_floor": 12, "spire_run": {"active": true, "floor": 3}}
	SaveMigrations.apply(d)
	assert_eq(int((d["rift_best_tiers"] as Dictionary)["grasslands"]), 12 / RiftDefs.FLOORS_PER_TIER)
	assert_eq(str((d["spire_run"] as Dictionary)["rift"]), "grasslands")


func test_boons_and_picks_are_run_only() -> void:
	var sm: SaveManagerScript = SaveManagerScript.new()
	sm.new_game(false)
	var owned_before: int = sm.owned_cards.size()
	sm.spire.start_spire_run(3, "grasslands", 1)
	assert_true(sm.spire.uses_own_deck(), "rift runs fight with the player's deck")
	sm.spire.add_drafted_card("wraith")
	sm.spire.add_boon("boon_vigor")
	sm.spire.add_boon("boon_edge")
	sm.spire.add_boon("not_a_boon")
	assert_eq(sm.owned_cards.size(), owned_before, "picks never enter the collection")
	assert_eq(sm.spire.drafted_cards(), ["wraith"] as Array[String])
	assert_eq(sm.spire.boons().size(), 2)
	assert_eq(int(sm.spire.get_spire_run()["hero_hp"]), 36, "Vigor heals as it raises the cap")
	assert_eq(RiftDefs.boon_total(sm.spire.boons(), "minion_attack"), 1)
	sm.spire.end_spire_run()
	assert_eq(sm.owned_cards.size(), owned_before)
	sm.spire.start_spire_run(4, "grasslands", 1)
	assert_true(sm.spire.boons().is_empty(), "boons reset each run")
