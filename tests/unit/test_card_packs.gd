## Unit tests for GID-050: Card Packs & Pack Opening (TID-185, TID-186, TID-187).
##
## Covers: pack definitions, roll_pack counts/templates, guaranteed_min_rarity,
## pity counter logic, save migration, SaveManager pity helpers.
extends "res://tests/framework/test_case.gd"

const PackDefs        = preload("res://game_logic/PackDefs.gd")
const SaveManagerScript = preload("res://autoloads/SaveManager.gd")
const CardRegistry    = preload("res://autoloads/CardRegistry.gd")

var _sm: Node
# CardRegistry can't load .tres files in headless; skip roll tests if empty.
var _registry_ok: bool = false

func before_all() -> void:
	_registry_ok = CardRegistry.get_all_ids().size() > 0

func before_each() -> void:
	_sm = SaveManagerScript.new()
	_sm._loaded = true

func after_each() -> void:
	_sm.free()

# ---------------------------------------------------------------------------
# PackDefs: pack table
# ---------------------------------------------------------------------------

func test_standard_pack_exists() -> void:
	var pack: Dictionary = PackDefs.get_pack("standard_pack")
	assert_false(pack.is_empty(), "standard_pack must be defined")

func test_premium_pack_exists() -> void:
	var pack: Dictionary = PackDefs.get_pack("premium_pack")
	assert_false(pack.is_empty(), "premium_pack must be defined")

func test_get_all_pack_ids_returns_two_packs() -> void:
	assert_eq(PackDefs.get_all_pack_ids().size(), 2, "should have exactly 2 pack types")

func test_standard_pack_price_is_120() -> void:
	assert_eq(int(PackDefs.get_pack("standard_pack").get("price", 0)), 120)

func test_premium_pack_price_is_300() -> void:
	assert_eq(int(PackDefs.get_pack("premium_pack").get("price", 0)), 300)

func test_pack_card_count_is_3() -> void:
	assert_eq(int(PackDefs.get_pack("standard_pack").get("card_count", 0)), 3)

func test_unknown_pack_returns_empty() -> void:
	assert_true(PackDefs.get_pack("nonexistent_pack").is_empty())

# ---------------------------------------------------------------------------
# PackDefs: roll_pack — basic shape
# ---------------------------------------------------------------------------

func test_roll_standard_pack_returns_3_cards() -> void:
	if not _registry_ok:
		pending("CardRegistry unavailable in headless — skipping roll test")
		return
	var rolled: Array[Dictionary] = PackDefs.roll_pack("standard_pack", 0)
	assert_eq(rolled.size(), 3, "standard pack must yield 3 cards")

func test_roll_premium_pack_returns_3_cards() -> void:
	if not _registry_ok:
		pending("CardRegistry unavailable in headless — skipping roll test")
		return
	var rolled: Array[Dictionary] = PackDefs.roll_pack("premium_pack", 0)
	assert_eq(rolled.size(), 3, "premium pack must yield 3 cards")

func test_roll_unknown_pack_returns_empty() -> void:
	var rolled: Array[Dictionary] = PackDefs.roll_pack("nonexistent_pack", 0)
	assert_eq(rolled.size(), 0, "unknown pack must return []")

func test_rolled_cards_have_required_keys() -> void:
	if not _registry_ok:
		pending("CardRegistry unavailable in headless — skipping roll test")
		return
	var rolled: Array[Dictionary] = PackDefs.roll_pack("standard_pack", 0)
	for card: Dictionary in rolled:
		assert_true(card.has("template_id"), "card dict must have template_id")
		assert_true(card.has("rarity"), "card dict must have rarity")
		assert_true(card.has("attack"), "card dict must have attack")
		assert_true(card.has("health"), "card dict must have health")
		assert_true(card.has("cost"), "card dict must have cost")

func test_rolled_template_ids_are_known_cards() -> void:
	if not _registry_ok:
		pending("CardRegistry unavailable in headless — skipping roll test")
		return
	var known_ids: Array[String] = CardRegistry.get_all_ids()
	var rolled: Array[Dictionary] = PackDefs.roll_pack("standard_pack", 0)
	for card: Dictionary in rolled:
		var tid: String = str(card.get("template_id", ""))
		assert_has(known_ids, tid, "template_id '%s' must exist in CardRegistry" % tid)

func test_rolled_template_ids_are_craftable() -> void:
	if not _registry_ok:
		pending("CardRegistry unavailable in headless — skipping roll test")
		return
	var rolled: Array[Dictionary] = PackDefs.roll_pack("standard_pack", 0)
	for card: Dictionary in rolled:
		var tid: String = str(card.get("template_id", ""))
		assert_true(CardRegistry.is_craftable(tid), "pack should only yield craftable cards, got '%s'" % tid)

func test_rolled_rarity_is_valid() -> void:
	if not _registry_ok:
		pending("CardRegistry unavailable in headless — skipping roll test")
		return
	var valid: Array[String] = ["common", "rare", "epic", "legendary"]
	var rolled: Array[Dictionary] = PackDefs.roll_pack("standard_pack", 0)
	for card: Dictionary in rolled:
		assert_has(valid, str(card.get("rarity", "")), "rarity must be one of the valid values")

# ---------------------------------------------------------------------------
# PackDefs: guaranteed_min_rarity (Premium pack)
# ---------------------------------------------------------------------------

func test_premium_slot1_always_at_least_rare() -> void:
	if not _registry_ok:
		pending("CardRegistry unavailable in headless — skipping roll test")
		return
	var rarity_order: Array[String] = ["common", "rare", "epic", "legendary"]
	var min_idx: int = rarity_order.find("rare")
	for i: int in range(30):
		var rolled: Array[Dictionary] = PackDefs.roll_pack("premium_pack", 0)
		var slot1_rarity: String = str(rolled[1].get("rarity", "common"))
		var slot1_idx: int = rarity_order.find(slot1_rarity)
		assert_gte(slot1_idx, min_idx,
				"premium pack slot 1 must be rare or better (roll %d, got '%s')" % [i, slot1_rarity])

func test_standard_pack_has_no_min_rarity_guarantee() -> void:
	# Standard pack has no guaranteed_min_rarity field.
	var pack: Dictionary = PackDefs.get_pack("standard_pack")
	assert_false(pack.has("guaranteed_min_rarity"), "standard pack should have no guarantee")

# ---------------------------------------------------------------------------
# PackDefs: pity counter
# ---------------------------------------------------------------------------

func test_pity_fires_exactly_at_threshold() -> void:
	if not _registry_ok:
		pending("CardRegistry unavailable in headless — skipping roll test")
		return
	var rolled: Array[Dictionary] = PackDefs.roll_pack("standard_pack", PackDefs.PITY_THRESHOLD)
	assert_eq(rolled.size(), 3, "must still return 3 cards")
	assert_eq(str(rolled[2].get("rarity", "")), "legendary",
			"last slot must be legendary when current_pity == PITY_THRESHOLD")

func test_pity_does_not_fire_one_below_threshold() -> void:
	if not _registry_ok:
		pending("CardRegistry unavailable in headless — skipping roll test")
		return
	# Standard tier has 0% legendary weight — if pity doesn't fire, last slot won't be legendary.
	# We run 10 rolls to confirm count is always 3 and pity doesn't incorrectly trigger.
	for _i: int in range(10):
		var rolled: Array[Dictionary] = PackDefs.roll_pack("standard_pack", PackDefs.PITY_THRESHOLD - 1)
		assert_eq(rolled.size(), 3, "must return 3 cards even below threshold")
		assert_ne(str(rolled[2].get("rarity", "")), "legendary",
				"tier-1 last slot must not be legendary below pity threshold")

func test_pity_threshold_constant_is_20() -> void:
	assert_eq(PackDefs.PITY_THRESHOLD, 20)

func test_pity_overrides_premium_guarantee_with_legendary() -> void:
	if not _registry_ok:
		pending("CardRegistry unavailable in headless — skipping roll test")
		return
	# When pity fires on a premium pack, last slot becomes legendary (>= rare).
	var rolled: Array[Dictionary] = PackDefs.roll_pack("premium_pack", PackDefs.PITY_THRESHOLD)
	assert_eq(rolled.size(), 3, "premium + pity must still give 3 cards")
	assert_eq(str(rolled[2].get("rarity", "")), "legendary",
			"pity must force last slot to legendary on premium pack too")
	# Slot 1 still respects its guarantee.
	var rarity_order: Array[String] = ["common", "rare", "epic", "legendary"]
	var slot1_rarity: String = str(rolled[1].get("rarity", "common"))
	assert_gte(rarity_order.find(slot1_rarity), rarity_order.find("rare"),
			"slot 1 must still be at least rare")

# ---------------------------------------------------------------------------
# SaveManager: pity counter fields and helpers
# ---------------------------------------------------------------------------

func test_packs_since_legendary_starts_at_zero() -> void:
	assert_eq(_sm.packs_since_legendary, 0)

func test_increment_pity_increases_counter() -> void:
	_sm.increment_pity()
	assert_eq(_sm.packs_since_legendary, 1)

func test_increment_pity_accumulates() -> void:
	_sm.increment_pity()
	_sm.increment_pity()
	_sm.increment_pity()
	assert_eq(_sm.packs_since_legendary, 3)

func test_reset_pity_zeroes_counter() -> void:
	_sm.packs_since_legendary = 15
	_sm.reset_pity()
	assert_eq(_sm.packs_since_legendary, 0)

func test_reset_pity_on_zero_is_noop() -> void:
	_sm.reset_pity()
	assert_eq(_sm.packs_since_legendary, 0)

# ---------------------------------------------------------------------------
# SaveManager migration v24 → v25
# ---------------------------------------------------------------------------

func test_migration_v24_to_v25_adds_field() -> void:
	var data: Dictionary = {"version": 24}
	SaveManagerScript._migrate_v24_to_v25(data)
	assert_true(data.has("packs_since_legendary"), "migration must add packs_since_legendary")

func test_migration_v24_to_v25_defaults_to_zero() -> void:
	var data: Dictionary = {"version": 24}
	SaveManagerScript._migrate_v24_to_v25(data)
	assert_eq(data["packs_since_legendary"], 0)

func test_migration_v24_to_v25_bumps_version() -> void:
	var data: Dictionary = {"version": 24}
	SaveManagerScript._migrate_v24_to_v25(data)
	assert_eq(data["version"], 25)

func test_migration_v24_to_v25_preserves_existing_value() -> void:
	var data: Dictionary = {"version": 24, "packs_since_legendary": 12}
	SaveManagerScript._migrate_v24_to_v25(data)
	assert_eq(data["packs_since_legendary"], 12, "existing value must not be overwritten")

func test_apply_migrations_reaches_v25_from_v24() -> void:
	var data: Dictionary = {"version": 24}
	SaveManagerScript._apply_migrations(data)
	assert_eq(data.get("version", 0), SaveManagerScript.CURRENT_SAVE_VERSION)
	assert_true(data.has("packs_since_legendary"))

func test_apply_migrations_reaches_v25_from_zero() -> void:
	var data: Dictionary = {"version": 0}
	SaveManagerScript._apply_migrations(data)
	assert_eq(data.get("version", 0), SaveManagerScript.CURRENT_SAVE_VERSION)
	assert_true(data.has("packs_since_legendary"))
