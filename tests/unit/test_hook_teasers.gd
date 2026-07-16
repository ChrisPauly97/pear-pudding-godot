## Unit tests for GID-117 first-session hook teasers.
## Covers: TutorialRegistry soulbinding/cantrips entries, and the starter-deck
## facts the teaser triggers rely on (Skeleton Dig available on a fresh deck,
## Ghost Phase not; tier-1 undead_basic carries an uncaptured signature).
extends "res://tests/framework/test_case.gd"

const EnemyRegistry = preload("res://autoloads/EnemyRegistry.gd")
const TutorialRegistry = preload("res://game_logic/TutorialRegistry.gd")
const CantripManager = preload("res://game_logic/world/CantripManager.gd")


# ---------------------------------------------------------------------------
# TutorialRegistry — teaser entries exist
# ---------------------------------------------------------------------------

func test_tutorial_registry_soulbinding_exists() -> void:
	var entry: Dictionary = TutorialRegistry.get_entry("soulbinding")
	assert_false(entry.is_empty(), "soulbinding tutorial entry should exist")

func test_tutorial_registry_soulbinding_has_title_and_body() -> void:
	var entry: Dictionary = TutorialRegistry.get_entry("soulbinding")
	assert_ne(str(entry.get("title", "")), "")
	assert_ne(str(entry.get("body", "")), "")

func test_tutorial_registry_cantrips_exists() -> void:
	var entry: Dictionary = TutorialRegistry.get_entry("cantrips")
	assert_false(entry.is_empty(), "cantrips tutorial entry should exist")

func test_tutorial_registry_cantrips_has_title_and_body() -> void:
	var entry: Dictionary = TutorialRegistry.get_entry("cantrips")
	assert_ne(str(entry.get("title", "")), "")
	assert_ne(str(entry.get("body", "")), "")


# ---------------------------------------------------------------------------
# Starter-deck teaser preconditions (mirrors SaveManager.new_game deck)
# ---------------------------------------------------------------------------

func _starter_deck_ids() -> Array[String]:
	var ids: Array[String] = []
	for tid: String in ["ghost", "skeleton", "zombie", "ghoul"]:
		for _i: int in range(3):
			ids.append(tid)
	return ids

func test_starter_deck_unlocks_skeleton_dig() -> void:
	assert_true(CantripManager.is_available("skeleton_dig", _starter_deck_ids()),
		"fresh deck (9 Skeleton-family cards) should unlock Dig, so the cantrips teaser fires on first world entry")

func test_starter_deck_does_not_unlock_ghost_phase() -> void:
	assert_false(CantripManager.is_available("ghost_phase", _starter_deck_ids()),
		"fresh deck has only 3 Ghost-family cards — Phase stays locked (BID-050 context)")


# ---------------------------------------------------------------------------
# Tier-1 enemy carries a signature (soulbind teaser reachable in session one)
# ---------------------------------------------------------------------------

func test_undead_basic_has_signature_card() -> void:
	assert_ne(EnemyRegistry.get_signature_card("undead_basic"), "",
		"tier-1 undead_basic must carry a signature so the soulbind teaser is reachable early")

func test_undead_basic_has_capture_condition() -> void:
	assert_ne(EnemyRegistry.get_capture_condition("undead_basic"), "")
