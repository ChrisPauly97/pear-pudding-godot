## Unit tests for BountyGen and SaveManager bounty fields (TID-188).
##
## Covers: determinism, day differentiation, seed differentiation, required fields,
## valid types and targets, reward ranges, SaveManager migration v27→v28, rollover logic.
extends "res://tests/framework/test_case.gd"

const BountyGen         = preload("res://game_logic/BountyGen.gd")
const SaveManagerScript = preload("res://autoloads/SaveManager.gd")

var _sm: Node

func before_each() -> void:
	_sm = SaveManagerScript.new()
	_sm._loaded = true
	_sm.world_seed = 42
	_sm.days_elapsed = 0

func after_each() -> void:
	_sm.free()

# ---------------------------------------------------------------------------
# BountyGen.generate_daily — determinism
# ---------------------------------------------------------------------------

func test_generate_daily_returns_three_bounties() -> void:
	var bounties: Array[Dictionary] = BountyGen.generate_daily(42, 5)
	assert_eq(bounties.size(), 3, "must return exactly 3 bounties")

func test_generate_daily_is_deterministic() -> void:
	var a: Array[Dictionary] = BountyGen.generate_daily(123, 5)
	var b: Array[Dictionary] = BountyGen.generate_daily(123, 5)
	assert_eq(a.size(), b.size())
	for i: int in range(a.size()):
		assert_eq(a[i]["id"], b[i]["id"], "id must be deterministic at index %d" % i)
		assert_eq(a[i]["type"], b[i]["type"], "type must be deterministic at index %d" % i)
		assert_eq(a[i]["target"], b[i]["target"], "target must be deterministic at index %d" % i)
		assert_eq(a[i]["count"], b[i]["count"], "count must be deterministic at index %d" % i)
		assert_eq(a[i]["reward"], b[i]["reward"], "reward must be deterministic at index %d" % i)

func test_different_days_produce_different_bounties() -> void:
	var day5: Array[Dictionary] = BountyGen.generate_daily(42, 5)
	var day6: Array[Dictionary] = BountyGen.generate_daily(42, 6)
	var any_diff: bool = false
	for i: int in range(day5.size()):
		if day5[i]["target"] != day6[i]["target"] or day5[i]["count"] != day6[i]["count"]:
			any_diff = true
			break
	assert_true(any_diff, "day 5 and day 6 bounties should differ in at least one field")

func test_different_seeds_produce_different_bounties() -> void:
	var s42: Array[Dictionary] = BountyGen.generate_daily(42, 5)
	var s99: Array[Dictionary] = BountyGen.generate_daily(99999, 5)
	var any_diff: bool = false
	for i: int in range(s42.size()):
		if s42[i]["target"] != s99[i]["target"] or s42[i]["count"] != s99[i]["count"]:
			any_diff = true
			break
	assert_true(any_diff, "different world seeds should produce different bounties")

# ---------------------------------------------------------------------------
# BountyGen — required fields and valid values
# ---------------------------------------------------------------------------

func test_each_bounty_has_required_fields() -> void:
	var bounties: Array[Dictionary] = BountyGen.generate_daily(42, 0)
	for i: int in range(bounties.size()):
		var b: Dictionary = bounties[i]
		assert_true(b.has("id"),     "bounty %d missing 'id'" % i)
		assert_true(b.has("type"),   "bounty %d missing 'type'" % i)
		assert_true(b.has("target"), "bounty %d missing 'target'" % i)
		assert_true(b.has("count"),  "bounty %d missing 'count'" % i)
		assert_true(b.has("reward"), "bounty %d missing 'reward'" % i)

func test_bounty_types_cover_all_three() -> void:
	var bounties: Array[Dictionary] = BountyGen.generate_daily(42, 0)
	var types: Array[String] = []
	for b: Dictionary in bounties:
		types.append(str(b["type"]))
	assert_has(types, "defeat_enemy_type")
	assert_has(types, "defeat_in_biome")
	assert_has(types, "open_chests")

func test_defeat_enemy_type_target_is_valid() -> void:
	for day: int in range(5):
		var bounties: Array[Dictionary] = BountyGen.generate_daily(42, day)
		for b: Dictionary in bounties:
			if str(b["type"]) == "defeat_enemy_type":
				assert_has(BountyGen.ENEMY_TYPE_IDS, str(b["target"]),
					"target must be a known enemy type on day %d" % day)

func test_defeat_in_biome_target_is_valid() -> void:
	for day: int in range(5):
		var bounties: Array[Dictionary] = BountyGen.generate_daily(42, day)
		for b: Dictionary in bounties:
			if str(b["type"]) == "defeat_in_biome":
				assert_has(BountyGen.BIOME_NAMES, str(b["target"]),
					"target must be a known biome on day %d" % day)

func test_open_chests_count_in_range() -> void:
	for day: int in range(10):
		var bounties: Array[Dictionary] = BountyGen.generate_daily(day * 7 + 1, day)
		for b: Dictionary in bounties:
			if str(b["type"]) == "open_chests":
				assert_between(int(b["count"]), 1, 3, "chest count must be 1–3")

func test_defeat_enemy_count_in_range() -> void:
	for day: int in range(10):
		var bounties: Array[Dictionary] = BountyGen.generate_daily(day * 3 + 5, day)
		for b: Dictionary in bounties:
			if str(b["type"]) == "defeat_enemy_type":
				assert_between(int(b["count"]), 2, 4, "enemy count must be 2–4")

func test_defeat_biome_count_in_range() -> void:
	for day: int in range(10):
		var bounties: Array[Dictionary] = BountyGen.generate_daily(day * 11 + 2, day)
		for b: Dictionary in bounties:
			if str(b["type"]) == "defeat_in_biome":
				assert_between(int(b["count"]), 3, 5, "biome count must be 3–5")

func test_chest_reward_is_multiple_of_30() -> void:
	for day: int in range(10):
		var bounties: Array[Dictionary] = BountyGen.generate_daily(day * 13 + 3, day)
		for b: Dictionary in bounties:
			if str(b["type"]) == "open_chests":
				assert_eq(int(b["reward"]) % 30, 0, "chest reward must be a multiple of 30")

func test_defeat_enemy_reward_above_minimum() -> void:
	for day: int in range(10):
		var bounties: Array[Dictionary] = BountyGen.generate_daily(day * 5 + 7, day)
		for b: Dictionary in bounties:
			if str(b["type"]) == "defeat_enemy_type":
				assert_gte(int(b["reward"]), 80, "defeat_enemy reward must be ≥ 80 (min: count=2,tier=1)")

func test_bounty_id_contains_day_index() -> void:
	var bounties: Array[Dictionary] = BountyGen.generate_daily(42, 77)
	for b: Dictionary in bounties:
		assert_true(str(b["id"]).contains("77"), "bounty id must embed the day index")

# ---------------------------------------------------------------------------
# SaveManager migration v27 → v28
# ---------------------------------------------------------------------------

func test_migration_adds_bounty_fields() -> void:
	var data: Dictionary = {"version": 27}
	SaveManagerScript._migrate_v27_to_v28(data)
	assert_true(data.has("bounty_day"),       "bounty_day must be added")
	assert_true(data.has("offered_bounties"), "offered_bounties must be added")
	assert_true(data.has("active_bounties"),  "active_bounties must be added")

func test_migration_default_bounty_day_is_zero() -> void:
	var data: Dictionary = {"version": 27}
	SaveManagerScript._migrate_v27_to_v28(data)
	assert_eq(data["bounty_day"], 0)

func test_migration_default_offered_bounties_is_empty() -> void:
	var data: Dictionary = {"version": 27}
	SaveManagerScript._migrate_v27_to_v28(data)
	assert_true((data["offered_bounties"] as Array).is_empty())

func test_migration_default_active_bounties_is_empty() -> void:
	var data: Dictionary = {"version": 27}
	SaveManagerScript._migrate_v27_to_v28(data)
	assert_true((data["active_bounties"] as Array).is_empty())

func test_migration_bumps_version_to_28() -> void:
	var data: Dictionary = {"version": 27}
	SaveManagerScript._migrate_v27_to_v28(data)
	assert_eq(data["version"], 28)

func test_migration_does_not_overwrite_existing_bounty_day() -> void:
	var data: Dictionary = {"version": 27, "bounty_day": 5}
	SaveManagerScript._migrate_v27_to_v28(data)
	assert_eq(data["bounty_day"], 5)

func test_apply_migrations_reaches_current_from_v27() -> void:
	var data: Dictionary = {"version": 27}
	SaveManagerScript._apply_migrations(data)
	assert_eq(data.get("version", 0), SaveManagerScript.CURRENT_SAVE_VERSION)
	assert_true(data.has("bounty_day"))
	assert_true(data.has("offered_bounties"))
	assert_true(data.has("active_bounties"))

# ---------------------------------------------------------------------------
# SaveManager — bounty field defaults and rollover logic
# ---------------------------------------------------------------------------

func test_bounty_day_starts_at_zero() -> void:
	assert_eq(_sm.bounty_day, 0)

func test_offered_bounties_starts_empty() -> void:
	assert_true(_sm.offered_bounties.is_empty())

func test_active_bounties_starts_empty() -> void:
	assert_true(_sm.active_bounties.is_empty())

func test_get_offered_bounties_populates_on_first_call() -> void:
	var offered: Array[Dictionary] = _sm.get_offered_bounties()
	assert_eq(offered.size(), 3, "first call must generate 3 offered bounties")

func test_get_offered_bounties_sets_bounty_day() -> void:
	_sm.days_elapsed = 7
	_sm.get_offered_bounties()
	assert_eq(_sm.bounty_day, 7)

func test_get_offered_bounties_adds_offered_at_day_field() -> void:
	_sm.days_elapsed = 3
	var offered: Array[Dictionary] = _sm.get_offered_bounties()
	for b: Dictionary in offered:
		assert_true(b.has("offered_at_day"), "each bounty must have offered_at_day")
		assert_eq(int(b["offered_at_day"]), 3)

func test_rollover_clears_offered_bounties() -> void:
	_sm.days_elapsed = 0
	_sm.get_offered_bounties()
	var first_target: String = str(_sm.offered_bounties[0].get("target", ""))

	_sm.days_elapsed = 1
	_sm.get_offered_bounties()
	# bounty_day should now match days_elapsed
	assert_eq(_sm.bounty_day, 1)
	# and offered_bounties regenerated (may differ from day 0)
	assert_eq(_sm.offered_bounties.size(), 3)

func test_rollover_preserves_active_bounties() -> void:
	_sm.days_elapsed = 0
	_sm.get_offered_bounties()
	_sm.active_bounties.append({"id": "test_bounty", "progress": 1, "claimed": false})

	_sm.days_elapsed = 1
	_sm.get_offered_bounties()
	assert_eq(_sm.active_bounties.size(), 1, "active bounties must persist across day rollover")

func test_no_double_refresh_same_day() -> void:
	_sm.days_elapsed = 5
	_sm.get_offered_bounties()
	var first_id: String = str(_sm.offered_bounties[0].get("id", ""))
	_sm.offered_bounties[0]["_marker"] = "touched"

	_sm.get_offered_bounties()
	assert_true(_sm.offered_bounties[0].has("_marker"), "should not regenerate on same day")

func test_increment_day_triggers_rollover() -> void:
	_sm.days_elapsed = 0
	_sm.get_offered_bounties()
	_sm.increment_day()
	assert_eq(_sm.bounty_day, 1, "bounty_day must update after increment_day")
	assert_eq(_sm.offered_bounties.size(), 3)
