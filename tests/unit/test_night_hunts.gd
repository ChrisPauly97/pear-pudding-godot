## Unit tests for GID-055 Night Hunts.
## Covers: spectral enemy data in EnemyRegistry, night-window predicate math,
## drop boost flag, and TutorialRegistry night_hunts entry.
extends "res://tests/framework/test_case.gd"

const EnemyRegistry = preload("res://autoloads/EnemyRegistry.gd")
const TutorialRegistry = preload("res://game_logic/TutorialRegistry.gd")


# ---------------------------------------------------------------------------
# Night-window predicate (pure math — mirrors WorldScene._is_night)
# ---------------------------------------------------------------------------

func _is_night(time_of_day: float) -> bool:
	return sin((time_of_day - 0.25) * TAU) < 0.0

func test_is_night_at_midnight() -> void:
	assert_true(_is_night(0.0))

func test_is_night_before_sunrise() -> void:
	assert_true(_is_night(0.2))

func test_is_not_night_at_sunrise() -> void:
	assert_false(_is_night(0.25))

func test_is_not_night_at_noon() -> void:
	assert_false(_is_night(0.5))

func test_is_night_after_sunset() -> void:
	assert_true(_is_night(0.8))

func test_is_night_near_end_of_day() -> void:
	assert_true(_is_night(0.99))


# ---------------------------------------------------------------------------
# EnemyRegistry — spectral enemies exist
# ---------------------------------------------------------------------------

func test_spectre_wisp_deck_not_empty() -> void:
	var deck: Array[String] = EnemyRegistry.get_deck("spectre_wisp")
	assert_gt(deck.size(), 0, "spectre_wisp should have a deck")

func test_spectre_haunt_deck_not_empty() -> void:
	var deck: Array[String] = EnemyRegistry.get_deck("spectre_haunt")
	assert_gt(deck.size(), 0, "spectre_haunt should have a deck")

func test_spectre_dread_deck_not_empty() -> void:
	var deck: Array[String] = EnemyRegistry.get_deck("spectre_dread")
	assert_gt(deck.size(), 0, "spectre_dread should have a deck")

func test_spectre_wisp_tier_is_1() -> void:
	assert_eq(EnemyRegistry.get_difficulty_tier("spectre_wisp"), 1)

func test_spectre_haunt_tier_is_2() -> void:
	assert_eq(EnemyRegistry.get_difficulty_tier("spectre_haunt"), 2)

func test_spectre_dread_tier_is_3() -> void:
	assert_eq(EnemyRegistry.get_difficulty_tier("spectre_dread"), 3)

func test_spectre_wisp_coin_reward() -> void:
	assert_eq(EnemyRegistry.get_coin_reward("spectre_wisp"), 8)

func test_spectre_haunt_coin_reward() -> void:
	assert_eq(EnemyRegistry.get_coin_reward("spectre_haunt"), 12)

func test_spectre_dread_coin_reward() -> void:
	assert_eq(EnemyRegistry.get_coin_reward("spectre_dread"), 18)

func test_spectre_wisp_not_boss() -> void:
	assert_false(EnemyRegistry.is_boss("spectre_wisp"))

func test_spectre_is_tracking() -> void:
	assert_true(EnemyRegistry.is_tracking("spectre_wisp"))
	assert_true(EnemyRegistry.is_tracking("spectre_haunt"))
	assert_true(EnemyRegistry.is_tracking("spectre_dread"))


# ---------------------------------------------------------------------------
# Night drop boost flag
# ---------------------------------------------------------------------------

func test_spectre_wisp_has_night_drop_boost() -> void:
	assert_true(EnemyRegistry.get_night_drop_boost("spectre_wisp"))

func test_spectre_haunt_has_night_drop_boost() -> void:
	assert_true(EnemyRegistry.get_night_drop_boost("spectre_haunt"))

func test_spectre_dread_has_night_drop_boost() -> void:
	assert_true(EnemyRegistry.get_night_drop_boost("spectre_dread"))

func test_regular_enemy_no_night_drop_boost() -> void:
	assert_false(EnemyRegistry.get_night_drop_boost("undead_basic"))
	assert_false(EnemyRegistry.get_night_drop_boost("ghoul_pack"))


# ---------------------------------------------------------------------------
# Drop tier capping: boost raises tier by 1 but caps at 4
# ---------------------------------------------------------------------------

func test_drop_tier_boost_spectre_dread_stays_at_3_then_boosted_to_4() -> void:
	var base_tier: int = EnemyRegistry.get_difficulty_tier("spectre_dread")
	var boosted: int = mini(base_tier + 1, 4)
	assert_eq(base_tier, 3)
	assert_eq(boosted, 4)

func test_drop_tier_boost_cap_at_4() -> void:
	var boosted: int = mini(4 + 1, 4)
	assert_eq(boosted, 4)


# ---------------------------------------------------------------------------
# TutorialRegistry — night_hunts entry exists
# ---------------------------------------------------------------------------

func test_tutorial_registry_night_hunts_exists() -> void:
	var entry: Dictionary = TutorialRegistry.get_entry("night_hunts")
	assert_false(entry.is_empty(), "night_hunts tutorial entry should exist")

func test_tutorial_registry_night_hunts_has_title() -> void:
	var entry: Dictionary = TutorialRegistry.get_entry("night_hunts")
	assert_true(entry.has("title"))
	assert_ne(str(entry.get("title", "")), "")

func test_tutorial_registry_night_hunts_has_body() -> void:
	var entry: Dictionary = TutorialRegistry.get_entry("night_hunts")
	assert_true(entry.has("body"))
	assert_ne(str(entry.get("body", "")), "")
