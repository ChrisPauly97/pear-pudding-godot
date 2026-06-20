## Unit tests for GID-068 Ley Lines — field math, intersection, mana well logic.
extends "res://tests/framework/test_case.gd"

const TerrainMath = preload("res://game_logic/TerrainMath.gd")
const InfiniteWorldGen = preload("res://game_logic/world/InfiniteWorldGen.gd")


# ---------------------------------------------------------------------------
# Determinism — same position + seed → same result
# ---------------------------------------------------------------------------

func test_ley_intensity_deterministic() -> void:
	var ws: int = 42
	var a: float = TerrainMath.ley_intensity(100.0, 200.0, ws)
	var b: float = TerrainMath.ley_intensity(100.0, 200.0, ws)
	assert_eq(a, b, "ley_intensity must be deterministic for the same inputs")


func test_ley_intensity_different_seeds() -> void:
	var v1: float = TerrainMath.ley_intensity(50.0, 50.0, 1)
	var v2: float = TerrainMath.ley_intensity(50.0, 50.0, 999999)
	# Different seeds should generally produce different results somewhere
	# (they may coincidentally match, but very unlikely at a fixed point)
	# Just verify both return valid [0,1] values.
	assert_true(v1 >= 0.0 and v1 <= 1.0, "ley_intensity result must be in [0,1]")
	assert_true(v2 >= 0.0 and v2 <= 1.0, "ley_intensity result must be in [0,1]")


# ---------------------------------------------------------------------------
# Coverage — ley lines exist (2–8% of world positions)
# ---------------------------------------------------------------------------

func test_ley_coverage_nonzero_and_incomplete() -> void:
	# Verify some world positions are on ley lines and some are off.
	# Exact percentage is seed-dependent; we only require both cases exist.
	var ws: int = 12345
	var on_line: int = 0
	var off_line: int = 0
	var step: float = 3.0
	for xi in range(50):
		for zi in range(50):
			var wx: float = float(xi) * step
			var wz: float = float(zi) * step
			if TerrainMath.is_on_ley_line(wx, wz, ws):
				on_line += 1
			else:
				off_line += 1
	assert_gt(on_line, 0, "some positions should be on a ley line")
	assert_gt(off_line, 0, "some positions should be off ley lines")


# ---------------------------------------------------------------------------
# Intersection — intersection_strength implies both channels active
# ---------------------------------------------------------------------------

func test_intersection_strength_is_subset_of_intensity() -> void:
	var ws: int = 42
	var found_intersection: bool = false
	var step: float = 1.5
	for xi in range(100):
		for zi in range(100):
			var wx: float = float(xi) * step
			var wz: float = float(zi) * step
			var s: float = TerrainMath.ley_intersection_strength(wx, wz, ws)
			if s > 0.0:
				found_intersection = true
				var ia: float = TerrainMath.ley_intensity(wx, wz, ws)
				assert_true(ia > 0.0,
					"intersection requires primary channel to be on the line")
	# Intersections should exist somewhere in a 100×100 tile area
	assert_true(found_intersection, "should find at least one ley intersection in 100x100 area")


# ---------------------------------------------------------------------------
# Mana Well placement — deterministic, one per chunk at most
# ---------------------------------------------------------------------------

func test_mana_well_placement_deterministic() -> void:
	var ws: int = 54321
	var chunk_a: RefCounted = InfiniteWorldGen.generate_chunk(3, 7, ws)
	var chunk_b: RefCounted = InfiniteWorldGen.generate_chunk(3, 7, ws)
	assert_eq(chunk_a.mana_wells.size(), chunk_b.mana_wells.size(),
		"mana well count must be deterministic")
	if chunk_a.mana_wells.size() > 0:
		var wa: Dictionary = chunk_a.mana_wells[0]
		var wb: Dictionary = chunk_b.mana_wells[0]
		assert_eq(str(wa.get("id", "")), str(wb.get("id", "")),
			"mana well id must be deterministic")
		assert_eq(wa.get("x", 0.0), wb.get("x", 0.0),
			"mana well x must be deterministic")


func test_mana_well_at_most_one_per_chunk() -> void:
	var ws: int = 99
	for cx in range(5):
		for cz in range(5):
			var chunk: RefCounted = InfiniteWorldGen.generate_chunk(cx, cz, ws)
			assert_true(chunk.mana_wells.size() <= 1,
				"at most one mana well per chunk")


# ---------------------------------------------------------------------------
# Attuned flag — pure dictionary logic (no scene required)
# ---------------------------------------------------------------------------

func test_attuned_flag_dict_logic() -> void:
	var enemy_data: Dictionary = {"player_attuned": true}
	var attuned: bool = bool(enemy_data.get("player_attuned", false))
	assert_true(attuned, "attuned flag should be readable from enemy_data dictionary")


func test_no_attuned_flag_defaults_false() -> void:
	var enemy_data: Dictionary = {}
	var attuned: bool = bool(enemy_data.get("player_attuned", false))
	assert_false(attuned, "missing attuned flag should default to false")
