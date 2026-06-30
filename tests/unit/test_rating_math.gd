## Unit tests for RatingMath (GID-102 / TID-370) — the pure ELO ladder math:
## expected-score symmetry & bounds, win raises / loss lowers, symmetric zero-sum-ish
## deltas at equal rating, placement K vs settled K, and the floor clamp. Mirrors
## test_pvp_protocol.gd (pure, scene-free).
extends "res://tests/framework/test_case.gd"

const RatingMath = preload("res://game_logic/net/RatingMath.gd")


# ---------------------------------------------------------------------------
# expected_score
# ---------------------------------------------------------------------------

func test_expected_score_equal_ratings_is_half() -> void:
	assert_almost_eq(RatingMath.expected_score(1000, 1000), 0.5)


func test_expected_score_is_symmetric() -> void:
	# expected(a,b) + expected(b,a) == 1 for any pair.
	var ea: float = RatingMath.expected_score(1200, 900)
	var eb: float = RatingMath.expected_score(900, 1200)
	assert_almost_eq(ea + eb, 1.0)


func test_expected_score_favors_higher_rating() -> void:
	assert_gt(RatingMath.expected_score(1400, 1000), 0.5)
	assert_lt(RatingMath.expected_score(1000, 1400), 0.5)


func test_expected_score_within_unit_interval() -> void:
	var e: float = RatingMath.expected_score(3000, 100)
	assert_between(e, 0.0, 1.0)


# ---------------------------------------------------------------------------
# updated — direction
# ---------------------------------------------------------------------------

func test_win_raises_rating() -> void:
	var r: int = RatingMath.updated(1000, 1000, 1.0, RatingMath.PLACEMENT_GAMES)
	assert_gt(r, 1000)


func test_loss_lowers_rating() -> void:
	var r: int = RatingMath.updated(1000, 1000, 0.0, RatingMath.PLACEMENT_GAMES)
	assert_lt(r, 1000)


func test_equal_rating_win_gains_half_k() -> void:
	# At equal rating expected is 0.5, so a settled-K win gains round(K_BASE * 0.5).
	var r: int = RatingMath.updated(1000, 1000, 1.0, RatingMath.PLACEMENT_GAMES)
	assert_eq(r, 1000 + int(round(RatingMath.K_BASE * 0.5)))


func test_beating_stronger_opponent_gains_more_than_beating_weaker() -> void:
	var upset: int = RatingMath.updated(1000, 1400, 1.0, RatingMath.PLACEMENT_GAMES)
	var expected_win: int = RatingMath.updated(1000, 600, 1.0, RatingMath.PLACEMENT_GAMES)
	assert_gt(upset - 1000, expected_win - 1000)


# ---------------------------------------------------------------------------
# updated — zero-sum-ish symmetry at equal rating
# ---------------------------------------------------------------------------

func test_equal_rating_deltas_are_symmetric() -> void:
	# Winner's gain equals loser's loss when both are at the same rating + games.
	var g: int = RatingMath.PLACEMENT_GAMES
	var winner: int = RatingMath.updated(1000, 1000, 1.0, g)
	var loser: int = RatingMath.updated(1000, 1000, 0.0, g)
	assert_eq(winner - 1000, 1000 - loser)


# ---------------------------------------------------------------------------
# k_factor — placement window
# ---------------------------------------------------------------------------

func test_placement_k_is_higher_than_settled_k() -> void:
	assert_eq(RatingMath.k_factor(0), RatingMath.K_PLACEMENT)
	assert_eq(RatingMath.k_factor(RatingMath.PLACEMENT_GAMES - 1), RatingMath.K_PLACEMENT)
	assert_eq(RatingMath.k_factor(RatingMath.PLACEMENT_GAMES), RatingMath.K_BASE)
	assert_gt(RatingMath.K_PLACEMENT, RatingMath.K_BASE)


func test_placement_win_moves_more_than_settled_win() -> void:
	var placement: int = RatingMath.updated(1000, 1000, 1.0, 0)
	var settled: int = RatingMath.updated(1000, 1000, 1.0, RatingMath.PLACEMENT_GAMES)
	assert_gt(placement - 1000, settled - 1000)


# ---------------------------------------------------------------------------
# clamp / floor
# ---------------------------------------------------------------------------

func test_rating_never_drops_below_floor() -> void:
	var r: int = RatingMath.MIN_RATING
	# Repeated losses against a far-stronger opponent stay clamped at the floor.
	for i in range(50):
		r = RatingMath.updated(r, 3000, 0.0, RatingMath.PLACEMENT_GAMES)
	assert_gte(r, RatingMath.MIN_RATING)


func test_clamp_rating_floors_low_values() -> void:
	assert_eq(RatingMath.clamp_rating(-100), RatingMath.MIN_RATING)
	assert_eq(RatingMath.clamp_rating(2500), 2500)


func test_start_rating_constant() -> void:
	assert_eq(RatingMath.START_RATING, 1000)


# ---------------------------------------------------------------------------
# updated — draw (reserved 0.5 score)
# ---------------------------------------------------------------------------

func test_draw_against_equal_is_no_change() -> void:
	var r: int = RatingMath.updated(1000, 1000, 0.5, RatingMath.PLACEMENT_GAMES)
	assert_eq(r, 1000)
