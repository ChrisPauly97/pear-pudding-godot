## Unit tests for SaveManager persistence logic (TID-305 / GID-085).
##
## Tests _apply_migrations (static), dirty-flag lifecycle, and the
## corrupt-file fallback in _read_save_json.  All tests work at the
## pure-data level — no disk I/O beyond the corrupt-file assertion.
extends "res://tests/framework/test_case.gd"

const SaveManagerScript = preload("res://autoloads/SaveManager.gd")

# ---------------------------------------------------------------------------
# _apply_migrations — v0 dict fills all fields
# ---------------------------------------------------------------------------

func test_v0_migration_sets_version_to_current() -> void:
	var data: Dictionary = {}
	SaveManagerScript._apply_migrations(data)
	assert_eq(int(data.get("version", -1)), SaveManagerScript.CURRENT_SAVE_VERSION)

func test_v0_migration_adds_world_seed() -> void:
	var data: Dictionary = {}
	SaveManagerScript._apply_migrations(data)
	assert_true(data.has("world_seed"))
	assert_eq(int(data["world_seed"]), 42)

func test_v0_migration_adds_story_flags() -> void:
	var data: Dictionary = {}
	SaveManagerScript._apply_migrations(data)
	assert_true(data.has("story_flags"))
	assert_true(data["story_flags"] is Dictionary)

func test_v0_migration_adds_spire_run() -> void:
	var data: Dictionary = {}
	SaveManagerScript._apply_migrations(data)
	assert_true(data.has("spire_run"))
	var sr = data["spire_run"]
	assert_true(sr is Dictionary)
	assert_false(bool((sr as Dictionary).get("active", true)))

func test_v0_migration_adds_collected_mana_wells() -> void:
	var data: Dictionary = {}
	SaveManagerScript._apply_migrations(data)
	assert_true(data.has("collected_mana_wells"))
	assert_true(data["collected_mana_wells"] is Array)

func test_v0_migration_adds_garden_plots() -> void:
	var data: Dictionary = {}
	SaveManagerScript._apply_migrations(data)
	assert_true(data.has("garden_plots"))
	var gp: Array = data["garden_plots"]
	assert_eq(gp.size(), 3)

# ---------------------------------------------------------------------------
# _apply_migrations — v1 dict promotes string card IDs to instance dicts
# ---------------------------------------------------------------------------

func test_v1_migration_promotes_owned_cards_to_dicts() -> void:
	var data: Dictionary = {
		"version": 1,
		"owned_cards": ["ghost", "skeleton"],
		"player_deck": ["ghost"],
	}
	SaveManagerScript._apply_migrations(data)
	var owned: Array = data.get("owned_cards", [])
	assert_gt(owned.size(), 0)
	assert_true(owned[0] is Dictionary)

func test_v1_migration_instance_has_uid_key() -> void:
	var data: Dictionary = {
		"version": 1,
		"owned_cards": ["ghost"],
		"player_deck": ["ghost"],
	}
	SaveManagerScript._apply_migrations(data)
	var owned: Array = data.get("owned_cards", [])
	assert_true((owned[0] as Dictionary).has("uid"))

func test_v1_migration_player_deck_becomes_uid_array() -> void:
	var data: Dictionary = {
		"version": 1,
		"owned_cards": ["ghost"],
		"player_deck": ["ghost"],
	}
	SaveManagerScript._apply_migrations(data)
	var deck: Array = data.get("player_deck", [])
	assert_gt(deck.size(), 0)
	assert_true(deck[0] is String)

# ---------------------------------------------------------------------------
# _apply_migrations — partial version preserves existing fields
# ---------------------------------------------------------------------------

func test_partial_v5_migration_preserves_equipped_weapon() -> void:
	# v5 introduces "equipped_weapon"; if already present, must not be overwritten.
	var data: Dictionary = {
		"version": 5,
		"equipped_weapon": "iron_sword",
		"player_deck": [],
		"owned_cards": [],
	}
	SaveManagerScript._apply_migrations(data)
	# Field was present, migration should leave it alone.
	assert_eq(str(data.get("equipped_weapon", "")), "iron_sword")

func test_partial_v12_migration_fills_xp_when_absent() -> void:
	# v12 introduces xp/level/skill_points/unlocked_skills.
	var data: Dictionary = {"version": 11, "player_deck": [], "owned_cards": []}
	SaveManagerScript._apply_migrations(data)
	assert_true(data.has("xp"))
	assert_eq(int(data["xp"]), 0)

# ---------------------------------------------------------------------------
# Dirty-flag lifecycle
# ---------------------------------------------------------------------------

func test_update_position_sets_dirty_flag() -> void:
	var prev_dirty: bool = SaveManager._dirty
	SaveManager._dirty = false
	SaveManager._loaded = true
	SaveManager.update_position("test_map", 1.0, 2.0)
	var is_dirty: bool = SaveManager._dirty
	SaveManager._dirty = prev_dirty  # restore
	assert_true(is_dirty)

func test_flush_if_dirty_does_nothing_when_not_loaded() -> void:
	var prev_loaded: bool = SaveManager._loaded
	var prev_dirty: bool = SaveManager._dirty
	SaveManager._loaded = false
	SaveManager._dirty = true
	SaveManager._flush_if_dirty()
	var still_dirty: bool = SaveManager._dirty
	SaveManager._loaded = prev_loaded
	SaveManager._dirty = prev_dirty  # restore
	assert_true(still_dirty)

func test_flush_if_dirty_does_nothing_when_not_dirty() -> void:
	var prev_loaded: bool = SaveManager._loaded
	var prev_dirty: bool = SaveManager._dirty
	SaveManager._loaded = true
	SaveManager._dirty = false
	SaveManager._flush_if_dirty()
	var still_not_dirty: bool = not SaveManager._dirty
	SaveManager._loaded = prev_loaded
	SaveManager._dirty = prev_dirty
	assert_true(still_not_dirty)

# ---------------------------------------------------------------------------
# ensure_coop_deck — transient deck seeding for cold co-op (GID-092 / TID-335)
# ---------------------------------------------------------------------------

func _snapshot_deck_state() -> Dictionary:
	return {
		"owned": SaveManager.owned_cards.duplicate(true),
		"deck": SaveManager.player_deck.duplicate(true),
		"index": SaveManager._uid_index.duplicate(true),
		"loaded": SaveManager._loaded,
		"dirty": SaveManager._dirty,
	}

func _restore_deck_state(s: Dictionary) -> void:
	SaveManager.owned_cards = s["owned"]
	SaveManager.player_deck = s["deck"]
	SaveManager._uid_index = s["index"]
	SaveManager._loaded = s["loaded"]
	SaveManager._dirty = s["dirty"]

func test_ensure_coop_deck_seeds_when_empty_and_not_loaded() -> void:
	var snap: Dictionary = _snapshot_deck_state()
	SaveManager._loaded = false
	SaveManager.owned_cards = []
	SaveManager._uid_index = {}
	SaveManager.player_deck = []
	SaveManager.ensure_coop_deck()
	var n: int = SaveManager.get_deck_instances().size()
	_restore_deck_state(snap)
	assert_true(n >= IsoConst.DECK_MIN)

func test_ensure_coop_deck_does_not_mark_loaded() -> void:
	var snap: Dictionary = _snapshot_deck_state()
	SaveManager._loaded = false
	SaveManager.owned_cards = []
	SaveManager._uid_index = {}
	SaveManager.player_deck = []
	SaveManager.ensure_coop_deck()
	var still_unloaded: bool = not SaveManager._loaded
	_restore_deck_state(snap)
	assert_true(still_unloaded)

func test_ensure_coop_deck_noop_when_game_loaded() -> void:
	var snap: Dictionary = _snapshot_deck_state()
	SaveManager._loaded = true
	SaveManager.owned_cards = []
	SaveManager._uid_index = {}
	SaveManager.player_deck = []
	SaveManager.ensure_coop_deck()
	var n: int = SaveManager.player_deck.size()
	_restore_deck_state(snap)
	assert_eq(n, 0)

# ---------------------------------------------------------------------------
# Corrupt-file fallback in _read_save_json
# ---------------------------------------------------------------------------

func test_corrupt_json_returns_null() -> void:
	var path: String = "user://test_corrupt_sm_305.json"
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f:
		f.store_string("{not valid json !!!")
		f = null
	var result = SaveManager._read_save_json(path)
	DirAccess.remove_absolute(path)
	assert_null(result)

func test_missing_file_returns_null() -> void:
	var result = SaveManager._read_save_json("user://nonexistent_sm_305.json")
	assert_null(result)

func test_hmac_mismatch_returns_null() -> void:
	# Write a payload-wrapped JSON with a bad HMAC.
	var path: String = "user://test_bad_hmac_sm_305.json"
	var inner: String = JSON.stringify({"version": 1, "coins": 999})
	var outer: String = JSON.stringify({"hmac": "aabbccddee", "payload": inner})
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f:
		f.store_string(outer)
		f = null
	var result = SaveManager._read_save_json(path)
	DirAccess.remove_absolute(path)
	assert_null(result)

func test_valid_unwrapped_json_is_parsed() -> void:
	# SaveManager also accepts plain (non-HMAC-wrapped) dicts for backward compat.
	var path: String = "user://test_plain_sm_305.json"
	var payload: Dictionary = {"version": 1, "coins": 50}
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(payload))
		f = null
	var result = SaveManager._read_save_json(path)
	DirAccess.remove_absolute(path)
	assert_not_null(result)
	assert_true(result is Dictionary)
	assert_eq(int((result as Dictionary).get("coins", -1)), 50)

# ---------------------------------------------------------------------------
# PERSISTED_FIELDS table (the single source of truth for save/load)
# ---------------------------------------------------------------------------

## The table drives save/load through set()/get(), which fail silently on a
## typo'd name — this test is what turns that back into a hard error.
func test_every_persisted_field_is_a_real_property() -> void:
	var sm := SaveManagerScript.new()
	var declared: Dictionary = {}
	for prop: Dictionary in sm.get_property_list():
		declared[str(prop["name"])] = true
	for key: String in SaveManagerScript.PERSISTED_FIELDS:
		assert_true(declared.has(key), "PERSISTED_FIELDS key '%s' is not a SaveManager property" % key)

## A field written by save() but never restored (or the reverse) is the exact
## bug the table exists to prevent; assert the walk covers both directions.
func test_collect_save_data_covers_every_persisted_field() -> void:
	var sm := SaveManagerScript.new()
	sm._loaded = true
	var data: Dictionary = sm._collect_save_data()
	for key: String in SaveManagerScript.PERSISTED_FIELDS:
		assert_true(data.has(key), "save output is missing '%s'" % key)

## Round-trips every field through _collect_save_data -> JSON -> _restore_field
## so a default whose type disagrees with its property shows up here.
func test_save_load_round_trips_every_field() -> void:
	var writer := SaveManagerScript.new()
	writer._loaded = true
	writer.coins = 1234
	writer.current_map = "dungeon_7"
	writer.player_x = 12.5
	writer.is_mounted = true
	writer.story_flags = {"met_isfig": true}
	writer.activated_waystones.assign(["ws_a", "ws_b"])
	writer.bag_size = 27
	var json: Dictionary = JSON.parse_string(JSON.stringify(writer._collect_save_data()))

	var reader := SaveManagerScript.new()
	for key: String in SaveManagerScript.PERSISTED_FIELDS:
		reader._restore_field(json, key, SaveManagerScript.PERSISTED_FIELDS[key])
	reader._restore_derived_fields(json)
	assert_eq(reader.coins, 1234)
	assert_eq(reader.current_map, "dungeon_7")
	assert_eq(reader.player_x, 12.5)
	assert_true(reader.is_mounted)
	assert_true(bool(reader.story_flags.get("met_isfig", false)))
	assert_eq(reader.activated_waystones.size(), 2)
	assert_eq(reader.activated_waystones[1], "ws_b")
	assert_eq(reader.bag_size, 27)

## A save with no entry for a field must leave the property at its declared
## default rather than at whatever the previous slot held.
func test_restore_field_falls_back_to_table_default() -> void:
	var sm := SaveManagerScript.new()
	sm.coins = 999
	sm.weather = {"id": "storm"}
	for key: String in SaveManagerScript.PERSISTED_FIELDS:
		sm._restore_field({}, key, SaveManagerScript.PERSISTED_FIELDS[key])
	assert_eq(sm.coins, 0)
	assert_eq(str(sm.weather.get("id", "unset")), "")

## The const defaults are read-only; a shallow hand-off would make the restored
## member read-only too and crash the first writer to touch it.
func test_dictionary_default_is_writable_after_restore() -> void:
	var sm := SaveManagerScript.new()
	sm._restore_field({}, "story_flags", SaveManagerScript.PERSISTED_FIELDS["story_flags"])
	sm.story_flags["chapter_1"] = true
	assert_true(bool(sm.story_flags.get("chapter_1", false)))
	sm._restore_field({}, "garden_plots", SaveManagerScript.PERSISTED_FIELDS["garden_plots"])
	(sm.garden_plots[0] as Dictionary)["seed"] = "pear"
	assert_eq(str((sm.garden_plots[0] as Dictionary).get("seed", "")), "pear")
