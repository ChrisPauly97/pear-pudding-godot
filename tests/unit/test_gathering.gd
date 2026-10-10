# gdlint: disable=max-public-methods
# Test suite: every test_* case is a public method, so max-public-methods doesn't apply.
## Unit tests for gathering nodes (GID-182 / TID-760): GatherDefs planning,
## the material → profession map, SaveProfessions.add_xp and the GatherNode harvest.
extends "res://tests/framework/test_case.gd"

const GatherDefs = preload("res://game_logic/professions/GatherDefs.gd")
const ProfessionDefs = preload("res://game_logic/professions/ProfessionDefs.gd")
const BiomeDef = preload("res://game_logic/world/BiomeDef.gd")
const SaveManagerScript = preload("res://autoloads/SaveManager.gd")
const GatherNodeScript = preload("res://scenes/world/entities/GatherNode.gd")

const SEED_COUNT: int = 300

var _sm: SaveManagerScript


func before_each() -> void:
	_sm = SaveManagerScript.new()
	_sm._loaded = true
	_sm.profession_xp = {}
	_sm.materials = {}


func after_each() -> void:
	_sm.free()


# ---- Planning (pure) ----

func test_plan_is_deterministic_per_chunk_seed() -> void:
	for s: int in [1, 42, 9999, 123456789]:
		for b: int in range(BiomeDef.COUNT):
			var a: Array[Dictionary] = GatherDefs.plan_chunk(s, b, true)
			var c: Array[Dictionary] = GatherDefs.plan_chunk(s, b, true)
			assert_eq(a, c, "seed %d biome %d must plan identically" % [s, b])


func test_plan_entries_are_well_formed() -> void:
	for s: int in range(SEED_COUNT):
		for b: int in range(BiomeDef.COUNT):
			for node: Dictionary in GatherDefs.plan_chunk(s, b, true):
				assert_true(GatherDefs.KINDS.has(str(node["kind"])), "known kind")
				assert_true(int(node["pick"]) >= 0, "pick is non-negative")
				assert_true(GatherDefs.profession_for(str(node["material"])) != "",
					"material has a profession")


func test_no_fish_without_water() -> void:
	for s: int in range(SEED_COUNT):
		for b: int in range(BiomeDef.COUNT):
			for node: Dictionary in GatherDefs.plan_chunk(s, b, false):
				assert_ne(str(node["kind"]), GatherDefs.FISH, "no fishing spot away from water")


func test_biome_gating() -> void:
	for s: int in range(SEED_COUNT):
		for node: Dictionary in GatherDefs.plan_chunk(s, BiomeDef.DESERT, true):
			assert_ne(str(node["kind"]), GatherDefs.ORE, "desert has no ore")
		for node: Dictionary in GatherDefs.plan_chunk(s, BiomeDef.MOUNTAINS, true):
			assert_ne(str(node["kind"]), GatherDefs.HERB, "mountains have no herbs")
		for node: Dictionary in GatherDefs.plan_chunk(s, BiomeDef.SCORCHED, true):
			assert_ne(str(node["kind"]), GatherDefs.HERB, "scorched lands have no herbs")


func test_grasslands_plant_some_nodes() -> void:
	var planted: int = 0
	for s: int in range(SEED_COUNT):
		planted += GatherDefs.plan_chunk(s, BiomeDef.GRASSLANDS, true).size()
	assert_gt(planted, 0, "grasslands plant gathering nodes over many chunks")


func test_out_of_range_biome_plans_nothing() -> void:
	assert_true(GatherDefs.plan_chunk(7, -1, true).is_empty(), "negative biome")
	assert_true(GatherDefs.plan_chunk(7, BiomeDef.COUNT + 3, true).is_empty(), "biome past the table")


# ---- Yields and tables ----

func test_yields_are_valid_materials_of_the_matching_source() -> void:
	var source_for: Dictionary = {GatherDefs.HERB: "herb", GatherDefs.ORE: "ore", GatherDefs.FISH: "fish"}
	for b: int in range(GatherDefs.YIELDS.size()):
		var table: Dictionary = GatherDefs.YIELDS[b]
		for kind: String in table:
			assert_true(source_for.has(kind), "biome %d kind %s is a gather kind" % [b, kind])
			var mats: Array = table[kind]
			assert_false(mats.is_empty(), "biome %d kind %s yields something" % [b, kind])
			for mat: String in mats:
				assert_true(ProfessionDefs.MATERIALS.has(mat), "%s is a material" % mat)
				assert_eq(str(ProfessionDefs.MATERIALS[mat]["source"]), str(source_for[kind]),
					"%s comes from the %s source" % [mat, kind])


func test_every_kind_has_a_profession_xp_and_respawn() -> void:
	for kind: String in GatherDefs.KINDS:
		assert_gt(GatherDefs.xp(kind), 0, kind + " xp")
		assert_gt(GatherDefs.respawn_seconds(kind), 0.0, kind + " respawn")
		assert_ne(GatherDefs.display_name(kind), kind, kind + " has a display name")


func test_profession_for_maps_each_source() -> void:
	assert_eq(GatherDefs.profession_for("silverleaf"), ProfessionDefs.ALCHEMY)
	assert_eq(GatherDefs.profession_for("wild_grain"), ProfessionDefs.COOKING)
	assert_eq(GatherDefs.profession_for("iron_ore"), ProfessionDefs.CRAFTING)
	assert_eq(GatherDefs.profession_for("river_trout"), ProfessionDefs.COOKING)
	assert_eq(GatherDefs.profession_for("no_such_material"), "")


# ---- Save: gathering XP ----

func test_add_xp_grants_and_levels_up() -> void:
	assert_eq(_sm.professions.add_xp(ProfessionDefs.ALCHEMY, 2), 0, "small grant does not level")
	assert_eq(_sm.professions.xp(ProfessionDefs.ALCHEMY), 2, "xp recorded")
	var lv: int = _sm.professions.add_xp(ProfessionDefs.ALCHEMY, ProfessionDefs.xp_for_level(2))
	assert_eq(lv, 2, "crossing the level-2 threshold returns the new level")
	assert_eq(_sm.professions.level(ProfessionDefs.ALCHEMY), 2)


func test_add_xp_refuses_unknown_profession_and_nonpositive() -> void:
	assert_eq(_sm.professions.add_xp("fishing", 5), 0, "unknown profession")
	assert_eq(_sm.professions.add_xp(ProfessionDefs.COOKING, 0), 0, "zero grant")
	assert_eq(_sm.professions.xp(ProfessionDefs.COOKING), 0, "nothing recorded")


# ---- Node entity ----

func test_harvest_yields_once_then_respawn_is_pending() -> void:
	var node: Node3D = GatherNodeScript.new()
	node.call("init_from_data", {"id": "g_test_0", "kind": GatherDefs.HERB, "material": "silverleaf"})
	assert_true(bool(node.call("is_harvestable")), "fresh node is harvestable")
	assert_eq(str(node.call("harvest")), "silverleaf", "first harvest yields the material")
	assert_false(node.visible, "harvested node hides")
	assert_eq(str(node.call("harvest")), "", "depleted node yields nothing")
	assert_false(bool(node.call("is_harvestable")), "depleted node is not harvestable before respawn")
	node.free()
