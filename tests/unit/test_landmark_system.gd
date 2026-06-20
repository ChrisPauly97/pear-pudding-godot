## Unit tests for GID-067 Ancient Colossi — landmark placement, names, and discovery.
extends "res://tests/framework/test_case.gd"

const InfiniteWorldGen = preload("res://game_logic/world/InfiniteWorldGen.gd")
const LandmarkNames    = preload("res://game_logic/world/LandmarkNames.gd")
const LandmarkMesh     = preload("res://game_logic/world/LandmarkMesh.gd")
const BiomeDef         = preload("res://game_logic/world/BiomeDef.gd")

const SEED: int = 12345

# ---------------------------------------------------------------------------
# Placement — density
# ---------------------------------------------------------------------------

func test_landmark_density_in_range() -> void:
	var world_seed: int = SEED
	var count: int = 0
	var total: int = 0
	for cx in range(-50, 50):
		for cz in range(-50, 50):
			total += 1
			var d: Dictionary = InfiniteWorldGen.landmark_for_chunk(cx, cz, world_seed)
			if not d.is_empty():
				count += 1
	# Expect roughly 1/60; allow generous band 1/40 to 1/100
	var ratio: float = float(count) / float(total)
	assert_true(ratio >= 1.0 / 100.0,
		"landmark density too low: %d / %d = %.4f" % [count, total, ratio])
	assert_true(ratio <= 1.0 / 30.0,
		"landmark density too high: %d / %d = %.4f" % [count, total, ratio])

# ---------------------------------------------------------------------------
# Placement — safe zone
# ---------------------------------------------------------------------------

func test_no_landmark_in_safe_zone() -> void:
	var world_seed: int = SEED
	for cx in range(-InfiniteWorldGen.LANDMARK_SAFE_DIST, InfiniteWorldGen.LANDMARK_SAFE_DIST + 1):
		for cz in range(-InfiniteWorldGen.LANDMARK_SAFE_DIST, InfiniteWorldGen.LANDMARK_SAFE_DIST + 1):
			var d: Dictionary = InfiniteWorldGen.landmark_for_chunk(cx, cz, world_seed)
			assert_true(d.is_empty(),
				"chunk (%d,%d) inside safe zone must not have a landmark" % [cx, cz])

# ---------------------------------------------------------------------------
# Placement — determinism
# ---------------------------------------------------------------------------

func test_landmark_placement_deterministic() -> void:
	var world_seed: int = 9999
	for cx in range(5, 15):
		for cz in range(5, 15):
			var d1: Dictionary = InfiniteWorldGen.landmark_for_chunk(cx, cz, world_seed)
			var d2: Dictionary = InfiniteWorldGen.landmark_for_chunk(cx, cz, world_seed)
			assert_eq(str(d1), str(d2),
				"landmark_for_chunk must be deterministic for (%d,%d)" % [cx, cz])

# ---------------------------------------------------------------------------
# Placement — variant matches biome
# ---------------------------------------------------------------------------

func test_landmark_variant_matches_biome() -> void:
	var world_seed: int = SEED
	var found: int = 0
	for cx in range(-80, 80):
		for cz in range(-80, 80):
			var d: Dictionary = InfiniteWorldGen.landmark_for_chunk(cx, cz, world_seed)
			if d.is_empty():
				continue
			found += 1
			var biome: int = int(d.get("biome", -1))
			var variant: String = str(d.get("variant", ""))
			var expected: String = InfiniteWorldGen.LANDMARK_VARIANTS[biome % InfiniteWorldGen.LANDMARK_VARIANTS.size()]
			assert_eq(variant, expected,
				"variant mismatch at (%d,%d): expected %s got %s" % [cx, cz, expected, variant])
			if found >= 10:
				return
	if found == 0:
		_fail("no landmarks found in scan range — increase range or check placement logic")

# ---------------------------------------------------------------------------
# Placement — required dict fields
# ---------------------------------------------------------------------------

func test_landmark_dict_has_required_fields() -> void:
	var world_seed: int = SEED
	for cx in range(-80, 80):
		for cz in range(-80, 80):
			var d: Dictionary = InfiniteWorldGen.landmark_for_chunk(cx, cz, world_seed)
			if d.is_empty():
				continue
			assert_true(d.has("id"),      "landmark dict missing 'id'")
			assert_true(d.has("variant"), "landmark dict missing 'variant'")
			assert_true(d.has("biome"),   "landmark dict missing 'biome'")
			assert_true(d.has("x"),       "landmark dict missing 'x'")
			assert_true(d.has("z"),       "landmark dict missing 'z'")
			assert_true(d.has("cx"),      "landmark dict missing 'cx'")
			assert_true(d.has("cz"),      "landmark dict missing 'cz'")
			return
	pending("no landmarks found in range")

# ---------------------------------------------------------------------------
# Placement — no overlap with ruins (ruin chunks skip landmark)
# ---------------------------------------------------------------------------

func test_no_landmark_in_ruin_chunk() -> void:
	var world_seed: int = SEED
	for cx in range(-40, 40):
		for cz in range(-40, 40):
			if abs(cx) + abs(cz) <= InfiniteWorldGen.LANDMARK_SAFE_DIST:
				continue
			var ruin_rng := RandomNumberGenerator.new()
			ruin_rng.seed = (cx * 73856093) ^ (cz * 19349663) ^ world_seed
			ruin_rng.seed = (ruin_rng.seed & 0x7FFFFFFF)
			# Replicate _chunk_seed then +2 offset from _gen_ruins
			var chunk_s: int = ((cx * 73856093) ^ (cz * 19349663) ^ world_seed) + 2
			var rng2 := RandomNumberGenerator.new()
			rng2.seed = chunk_s & 0x7FFFFFFF
			var is_ruin: bool = rng2.randi_range(0, 2) == 0
			var d: Dictionary = InfiniteWorldGen.landmark_for_chunk(cx, cz, world_seed)
			if is_ruin and not d.is_empty():
				_fail("chunk (%d,%d) is a ruin chunk but also has a landmark" % [cx, cz])
				return

# ---------------------------------------------------------------------------
# ChunkData — landmarks field populated on generate_chunk
# ---------------------------------------------------------------------------

func test_generate_chunk_populates_landmarks_field() -> void:
	var world_seed: int = SEED
	var found_landmark: bool = false
	for cx in range(-80, 80):
		for cz in range(-80, 80):
			var expected: Dictionary = InfiniteWorldGen.landmark_for_chunk(cx, cz, world_seed)
			if expected.is_empty():
				continue
			var chunk := InfiniteWorldGen.generate_chunk(cx, cz, world_seed)
			assert_eq(chunk.landmarks.size(), 1,
				"chunk (%d,%d) should have 1 landmark" % [cx, cz])
			assert_eq(str(chunk.landmarks[0].get("id", "")), str(expected.get("id", "")),
				"landmark id mismatch in ChunkData")
			found_landmark = true
			break
		if found_landmark:
			break
	if not found_landmark:
		pending("no landmark chunks found in scan range")

# ---------------------------------------------------------------------------
# ChunkData — footprint tiles are flat grass
# ---------------------------------------------------------------------------

func test_landmark_footprint_tiles_are_grass() -> void:
	var world_seed: int = SEED
	for cx in range(-80, 80):
		for cz in range(-80, 80):
			var d: Dictionary = InfiniteWorldGen.landmark_for_chunk(cx, cz, world_seed)
			if d.is_empty():
				continue
			var chunk := InfiniteWorldGen.generate_chunk(cx, cz, world_seed)
			var tx: int = int(d.get("tx", 8))
			var tz: int = int(d.get("tz", 8))
			var fp: int = InfiniteWorldGen.LANDMARK_FP
			for dz: int in range(-fp, fp + 1):
				for dx: int in range(-fp, fp + 1):
					var tile: int = chunk.get_tile(tx + dx, tz + dz)
					assert_eq(tile, IsoConst.TILE_GRASS,
						"footprint tile (%d,%d) at landmark chunk (%d,%d) must be TILE_GRASS" % [tx+dx, tz+dz, cx, cz])
					var h: int = chunk.get_height(tx + dx, tz + dz)
					assert_eq(h, 0,
						"footprint height (%d,%d) at landmark chunk must be 0" % [tx+dx, tz+dz])
			return
	pending("no landmark chunks found")

# ---------------------------------------------------------------------------
# Name generator — determinism
# ---------------------------------------------------------------------------

func test_landmark_name_deterministic() -> void:
	var world_seed: int = SEED
	for cx in range(-80, 80):
		for cz in range(-80, 80):
			var d: Dictionary = InfiniteWorldGen.landmark_for_chunk(cx, cz, world_seed)
			if d.is_empty():
				continue
			var name1: String = LandmarkNames.get_name(cx, cz, world_seed)
			var name2: String = LandmarkNames.get_name(cx, cz, world_seed)
			assert_eq(name1, name2, "landmark name must be deterministic")
			assert_ne(name1, "", "landmark name must not be empty")
			return
	pending("no landmarks found for name test")

func test_landmark_name_starts_with_the() -> void:
	var world_seed: int = SEED
	for cx in range(-80, 80):
		for cz in range(-80, 80):
			var d: Dictionary = InfiniteWorldGen.landmark_for_chunk(cx, cz, world_seed)
			if d.is_empty():
				continue
			var name: String = LandmarkNames.get_name(cx, cz, world_seed)
			assert_true(name.begins_with("The "),
				"name should start with 'The ': got '%s'" % name)
			return
	pending("no landmarks found for name format test")

func test_name_from_id_parses_correctly() -> void:
	var world_seed: int = SEED
	for cx in range(-80, 80):
		for cz in range(-80, 80):
			var d: Dictionary = InfiniteWorldGen.landmark_for_chunk(cx, cz, world_seed)
			if d.is_empty():
				continue
			var lid: String = str(d.get("id", ""))
			var via_name: String = LandmarkNames.get_name(cx, cz, world_seed)
			var via_id: String = LandmarkNames.name_from_id(lid, world_seed)
			assert_eq(via_id, via_name,
				"name_from_id must match get_name for id '%s'" % lid)
			return
	pending("no landmarks found")

# ---------------------------------------------------------------------------
# Different seeds / positions produce different names
# ---------------------------------------------------------------------------

func test_different_positions_different_names() -> void:
	var world_seed: int = SEED
	var names: Array[String] = []
	var found: int = 0
	for cx in range(-100, 100):
		for cz in range(-100, 100):
			var d: Dictionary = InfiniteWorldGen.landmark_for_chunk(cx, cz, world_seed)
			if d.is_empty():
				continue
			names.append(LandmarkNames.get_name(cx, cz, world_seed))
			found += 1
			if found >= 5:
				break
		if found >= 5:
			break
	if found < 2:
		pending("fewer than 2 landmarks found")
		return
	var all_same: bool = true
	for i: int in range(1, names.size()):
		if names[i] != names[0]:
			all_same = false
			break
	assert_false(all_same, "different landmark positions should produce at least some different names")

# ---------------------------------------------------------------------------
# LandmarkMesh — builders return valid ArrayMesh
# ---------------------------------------------------------------------------

func test_landmark_mesh_obelisk_ring_non_null() -> void:
	var mesh: ArrayMesh = LandmarkMesh.build("obelisk_ring", BiomeDef.GRASSLANDS)
	assert_not_null(mesh)
	assert_gt(mesh.get_surface_count(), 0, "obelisk_ring mesh must have surfaces")

func test_landmark_mesh_stone_head_non_null() -> void:
	var mesh: ArrayMesh = LandmarkMesh.build("stone_head", BiomeDef.FOREST)
	assert_not_null(mesh)
	assert_gt(mesh.get_surface_count(), 0, "stone_head mesh must have surfaces")

func test_landmark_mesh_kneeling_colossus_non_null() -> void:
	var mesh: ArrayMesh = LandmarkMesh.build("kneeling_colossus", BiomeDef.DESERT)
	assert_not_null(mesh)
	assert_gt(mesh.get_surface_count(), 0, "kneeling_colossus mesh must have surfaces")

func test_landmark_mesh_shattered_spire_non_null() -> void:
	var mesh: ArrayMesh = LandmarkMesh.build("shattered_spire", BiomeDef.SCORCHED)
	assert_not_null(mesh)
	assert_gt(mesh.get_surface_count(), 0, "shattered_spire mesh must have surfaces")

func test_landmark_mesh_broken_arch_non_null() -> void:
	var mesh: ArrayMesh = LandmarkMesh.build("broken_arch", BiomeDef.MOUNTAINS)
	assert_not_null(mesh)
	assert_gt(mesh.get_surface_count(), 0, "broken_arch mesh must have surfaces")

func test_all_variants_have_positive_collision_size() -> void:
	var variants: Array[String] = ["obelisk_ring", "stone_head", "kneeling_colossus",
		"shattered_spire", "broken_arch"]
	for v: String in variants:
		var s: Vector3 = LandmarkMesh.collision_size(v)
		assert_gt(s.x, 0.0, "%s collision width must be positive" % v)
		assert_gt(s.y, 0.0, "%s collision height must be positive" % v)
		assert_gt(s.z, 0.0, "%s collision depth must be positive" % v)

# ---------------------------------------------------------------------------
# SaveManager migration — discovered_landmarks defaults to []
# ---------------------------------------------------------------------------

func test_save_migration_backfills_discovered_landmarks() -> void:
	var data: Dictionary = {"version": 38}
	SaveManager._apply_migrations(data)
	assert_true(data.has("discovered_landmarks"),
		"migration must add discovered_landmarks field")
	assert_eq(data["discovered_landmarks"], [],
		"migrated discovered_landmarks must be empty array")

func test_is_landmark_discovered_false_by_default() -> void:
	SaveManager.discovered_landmarks.clear()
	assert_false(SaveManager.is_landmark_discovered("landmark_5_3"),
		"undiscovered landmark must return false")

func test_mark_landmark_discovered_idempotent() -> void:
	SaveManager.discovered_landmarks.clear()
	SaveManager.discovered_landmarks.append("landmark_1_1")
	var size_before: int = SaveManager.discovered_landmarks.size()
	SaveManager.mark_landmark_discovered("landmark_1_1")
	assert_eq(SaveManager.discovered_landmarks.size(), size_before,
		"marking already-discovered landmark must not duplicate the entry")
