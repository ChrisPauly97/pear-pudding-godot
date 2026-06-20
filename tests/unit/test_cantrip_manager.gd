## Unit tests for GID-065 CantripManager — deck-derived cantrip availability and cooldowns.
extends "res://tests/framework/test_case.gd"

const CantripManager = preload("res://game_logic/world/CantripManager.gd")


# ---------------------------------------------------------------------------
# Ghost Phase availability
# ---------------------------------------------------------------------------

func test_ghost_phase_not_available_empty_deck() -> void:
	var ids: Array[String] = []
	assert_false(CantripManager.is_available("ghost_phase", ids))

func test_ghost_phase_not_available_3_ghost_cards() -> void:
	var ids: Array[String] = ["ghost", "ghost", "ghost", "skeleton"]
	assert_false(CantripManager.is_available("ghost_phase", ids))

func test_ghost_phase_available_4_ghost_cards() -> void:
	var ids: Array[String] = ["ghost", "ghost", "ghost", "ghost"]
	assert_true(CantripManager.is_available("ghost_phase", ids))

func test_ghost_phase_available_with_mixed_family() -> void:
	var ids: Array[String] = ["ghost", "dusk_wraith", "shrouded_wraith", "surge_spirit", "skeleton"]
	assert_true(CantripManager.is_available("ghost_phase", ids))

func test_ghost_phase_not_available_wrong_family() -> void:
	var ids: Array[String] = ["skeleton", "skeleton", "skeleton", "skeleton"]
	assert_false(CantripManager.is_available("ghost_phase", ids))


# ---------------------------------------------------------------------------
# Skeleton Dig availability
# ---------------------------------------------------------------------------

func test_skeleton_dig_not_available_3_skeleton_cards() -> void:
	var ids: Array[String] = ["skeleton", "skeleton", "zombie", "ghost"]
	assert_false(CantripManager.is_available("skeleton_dig", ids))

func test_skeleton_dig_available_4_skeleton_family_cards() -> void:
	var ids: Array[String] = ["skeleton", "zombie", "ghoul", "blitz_ghoul"]
	assert_true(CantripManager.is_available("skeleton_dig", ids))

func test_skeleton_dig_available_iron_revenant() -> void:
	var ids: Array[String] = ["skeleton", "zombie", "ghoul", "iron_revenant", "ghost"]
	assert_true(CantripManager.is_available("skeleton_dig", ids))


# ---------------------------------------------------------------------------
# available_cantrips
# ---------------------------------------------------------------------------

func test_available_cantrips_empty_deck() -> void:
	var ids: Array[String] = []
	var cantrips: Array[String] = CantripManager.available_cantrips(ids)
	assert_eq(cantrips.size(), 0)

func test_available_cantrips_returns_ghost_only() -> void:
	var ids: Array[String] = ["ghost", "ghost", "ghost", "ghost"]
	var cantrips: Array[String] = CantripManager.available_cantrips(ids)
	assert_eq(cantrips.size(), 1)
	assert_true(cantrips.has("ghost_phase"))

func test_available_cantrips_returns_both() -> void:
	var ids: Array[String] = ["ghost", "ghost", "ghost", "ghost", "skeleton", "zombie", "ghoul", "blitz_ghoul"]
	var cantrips: Array[String] = CantripManager.available_cantrips(ids)
	assert_eq(cantrips.size(), 2)
	assert_true(cantrips.has("ghost_phase"))
	assert_true(cantrips.has("skeleton_dig"))


# ---------------------------------------------------------------------------
# Thresholds and cooldowns
# ---------------------------------------------------------------------------

func test_get_threshold_ghost_phase() -> void:
	assert_eq(CantripManager.get_threshold("ghost_phase"), 4)

func test_get_threshold_skeleton_dig() -> void:
	assert_eq(CantripManager.get_threshold("skeleton_dig"), 4)

func test_get_cooldown_ghost_phase_positive() -> void:
	assert_gt(CantripManager.get_cooldown("ghost_phase"), 0.0)

func test_get_cooldown_skeleton_dig_positive() -> void:
	assert_gt(CantripManager.get_cooldown("skeleton_dig"), 0.0)


# ---------------------------------------------------------------------------
# Cooldown logic
# ---------------------------------------------------------------------------

func test_not_on_cooldown_when_no_entry() -> void:
	var cooldowns: Dictionary = {}
	assert_false(CantripManager.is_on_cooldown("ghost_phase", cooldowns, 1000.0))

func test_on_cooldown_when_expiry_in_future() -> void:
	var cooldowns: Dictionary = {"ghost_phase": 2000.0}
	assert_true(CantripManager.is_on_cooldown("ghost_phase", cooldowns, 1000.0))

func test_not_on_cooldown_when_expiry_in_past() -> void:
	var cooldowns: Dictionary = {"ghost_phase": 500.0}
	assert_false(CantripManager.is_on_cooldown("ghost_phase", cooldowns, 1000.0))

func test_not_on_cooldown_at_exact_expiry() -> void:
	var cooldowns: Dictionary = {"ghost_phase": 1000.0}
	assert_false(CantripManager.is_on_cooldown("ghost_phase", cooldowns, 1000.0))

func test_cooldown_remaining_zero_when_not_on_cooldown() -> void:
	var cooldowns: Dictionary = {}
	assert_eq(CantripManager.cooldown_remaining("ghost_phase", cooldowns, 1000.0), 0)

func test_cooldown_remaining_positive_when_on_cooldown() -> void:
	var cooldowns: Dictionary = {"ghost_phase": 1010.0}
	assert_gt(CantripManager.cooldown_remaining("ghost_phase", cooldowns, 1000.0), 0)
