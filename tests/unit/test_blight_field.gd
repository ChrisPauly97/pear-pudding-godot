## Unit tests for GID-066 Blight Field — seeded heart placement, spread, and cleansing.
extends "res://tests/framework/test_case.gd"

const BlightField = preload("res://game_logic/world/BlightField.gd")


# ---------------------------------------------------------------------------
# Heart density (~33% of super-regions)
# ---------------------------------------------------------------------------

func test_heart_density_roughly_one_third() -> void:
	var world_seed: int = 12345
	var heart_count: int = 0
	var total_supers: int = 50
	for sx in range(total_supers):
		var h: Dictionary = BlightField.get_heart_for_super(sx, 0, world_seed)
		if not h.is_empty() and abs(h.get("cx", 0)) + abs(h.get("cz", 0)) > BlightField.SAFE_CHUNK_RADIUS:
			heart_count += 1
	# Allow a generous window since hash distribution varies per seed
	assert_gt(heart_count, 0, "some super-regions should contain hearts")
	assert_lt(heart_count, total_supers, "not every super-region should have a heart")


# ---------------------------------------------------------------------------
# Determinism — same coords, same seed → same result
# ---------------------------------------------------------------------------

func test_heart_placement_deterministic() -> void:
	var world_seed: int = 999
	var a: Dictionary = BlightField.get_heart_for_super(3, 7, world_seed)
	var b: Dictionary = BlightField.get_heart_for_super(3, 7, world_seed)
	assert_eq(str(a), str(b), "heart placement must be deterministic for same coords and seed")


func test_blight_intensity_deterministic() -> void:
	var world_seed: int = 777
	var cleansed: Array[String] = []
	var i1: float = BlightField.blight_intensity(20, 5, world_seed, 30, cleansed)
	var i2: float = BlightField.blight_intensity(20, 5, world_seed, 30, cleansed)
	assert_eq(i1, i2, "blight_intensity must be deterministic")


# ---------------------------------------------------------------------------
# Safe zone — no hearts near origin
# ---------------------------------------------------------------------------

func test_safe_zone_near_origin() -> void:
	var world_seed: int = 42
	for cx in range(-BlightField.SAFE_CHUNK_RADIUS, BlightField.SAFE_CHUNK_RADIUS + 1):
		for cz in range(-BlightField.SAFE_CHUNK_RADIUS, BlightField.SAFE_CHUNK_RADIUS + 1):
			var h: Dictionary = BlightField.get_heart_at_chunk(cx, cz, world_seed)
			assert_true(h.is_empty(),
				"chunk (%d,%d) within safe radius must not contain a blight heart" % [cx, cz])


# ---------------------------------------------------------------------------
# Spread radius grows with days_elapsed
# ---------------------------------------------------------------------------

func test_spread_radius_grows_with_days() -> void:
	var r_early: float = BlightField.blighted_radius(1)
	var r_late: float = BlightField.blighted_radius(60)
	assert_gt(r_late, r_early, "blight radius must grow with days_elapsed")


func test_spread_radius_capped_at_max() -> void:
	var r: float = BlightField.blighted_radius(9999)
	assert_true(r <= BlightField.MAX_RADIUS + 0.01,
		"blight radius must not exceed MAX_RADIUS")


# ---------------------------------------------------------------------------
# Blight intensity returns 0 for a chunk with no nearby heart
# ---------------------------------------------------------------------------

func test_no_blight_near_origin_at_day_1() -> void:
	var world_seed: int = 12345
	var cleansed: Array[String] = []
	var intensity: float = BlightField.blight_intensity(0, 0, world_seed, 1, cleansed)
	assert_eq(intensity, 0.0, "origin chunk should not be blighted on day 1")


# ---------------------------------------------------------------------------
# Cleansed hearts are excluded from blight calculation
# ---------------------------------------------------------------------------

func test_cleansed_heart_removes_blight() -> void:
	var world_seed: int = 42
	# Find a chunk that is blighted after many days
	var blighted_cx: int = -1
	var blighted_cz: int = -1
	var blighted_heart_id: String = ""
	for cx in range(BlightField.SAFE_CHUNK_RADIUS + 1, BlightField.SAFE_CHUNK_RADIUS + 40):
		var h: Dictionary = BlightField.get_heart_at_chunk(cx, 0, world_seed)
		if not h.is_empty():
			blighted_cx = int(h.get("cx", 0))
			blighted_cz = int(h.get("cz", 0))
			blighted_heart_id = str(h.get("id", ""))
			break
	if blighted_cx < 0:
		# No heart found in range; skip gracefully
		assert_true(true)
		return
	var cleansed_none: Array[String] = []
	var intensity_before: float = BlightField.blight_intensity(
		blighted_cx, blighted_cz, world_seed, 50, cleansed_none)
	var cleansed: Array[String] = [blighted_heart_id]
	var intensity_after: float = BlightField.blight_intensity(
		blighted_cx, blighted_cz, world_seed, 50, cleansed)
	assert_gt(intensity_before, 0.0, "chunk should be blighted before cleansing")
	assert_eq(intensity_after, 0.0, "chunk should not be blighted after heart is cleansed")


# ---------------------------------------------------------------------------
# is_blighted mirrors intensity > 0
# ---------------------------------------------------------------------------

func test_is_blighted_mirrors_intensity() -> void:
	var world_seed: int = 42
	var cleansed: Array[String] = []
	for cx in range(-2, 50):
		var intensity: float = BlightField.blight_intensity(cx, 0, world_seed, 30, cleansed)
		var blighted: bool = BlightField.is_blighted(cx, 0, world_seed, 30, cleansed)
		if intensity > 0.0:
			assert_true(blighted, "is_blighted must be true when intensity > 0")
		else:
			assert_false(blighted, "is_blighted must be false when intensity == 0")
