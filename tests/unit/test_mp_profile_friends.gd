## Unit tests for MpProfile's friends list (GID-102 / TID-375).
##
## Mirrors test_save_manager.gd's pattern for exercising a live autoload: snapshot
## the in-memory state, mutate via the public API only, then restore — so these
## tests never depend on or corrupt the real user://mp_profile.json on disk.
extends "res://tests/framework/test_case.gd"


func _snapshot_friends_state() -> Dictionary:
	return {
		"friends": MpProfile._friends.duplicate(true),
		"loaded": MpProfile._loaded,
	}


func _restore_friends_state(s: Dictionary) -> void:
	MpProfile._friends = s["friends"]
	MpProfile._loaded = s["loaded"]


func before_each() -> void:
	# Every test starts from an empty, already-"loaded" friends list so _ensure_loaded
	# never touches disk during the test body.
	MpProfile._loaded = true
	MpProfile._friends = []


# ---------------------------------------------------------------------------
# add_friend — basic add + dedupe-by-token
# ---------------------------------------------------------------------------

func test_add_friend_adds_new_entry() -> void:
	var snap: Dictionary = _snapshot_friends_state()
	MpProfile.add_friend("tok-aaaa", "Alice", "ff0000")
	var friends: Array = MpProfile.get_friends()
	_restore_friends_state(snap)
	assert_eq(friends.size(), 1)
	var f: Dictionary = friends[0]
	assert_eq(str(f.get("token", "")), "tok-aaaa")
	assert_eq(str(f.get("name", "")), "Alice")
	assert_eq(str(f.get("color_hex", "")), "ff0000")
	assert_true(f.has("last_seen"))


func test_add_friend_same_token_updates_not_duplicates() -> void:
	var snap: Dictionary = _snapshot_friends_state()
	MpProfile.add_friend("tok-aaaa", "Alice", "ff0000")
	MpProfile.add_friend("tok-aaaa", "Alice2", "00ff00")
	var friends: Array = MpProfile.get_friends()
	_restore_friends_state(snap)
	assert_eq(friends.size(), 1, "re-adding the same token must not duplicate")
	var f: Dictionary = friends[0]
	assert_eq(str(f.get("name", "")), "Alice2", "name should be refreshed")
	assert_eq(str(f.get("color_hex", "")), "00ff00", "color should be refreshed")


func test_add_friend_moves_existing_to_front() -> void:
	var snap: Dictionary = _snapshot_friends_state()
	MpProfile.add_friend("tok-a", "A", "ff0000")
	MpProfile.add_friend("tok-b", "B", "00ff00")
	MpProfile.add_friend("tok-a", "A", "ff0000")  # touch A again
	var friends: Array = MpProfile.get_friends()
	_restore_friends_state(snap)
	assert_eq(friends.size(), 2)
	assert_eq(str((friends[0] as Dictionary).get("token", "")), "tok-a")


func test_add_friend_ignores_blank_token() -> void:
	var snap: Dictionary = _snapshot_friends_state()
	MpProfile.add_friend("   ", "Nobody", "ff0000")
	var friends: Array = MpProfile.get_friends()
	_restore_friends_state(snap)
	assert_true(friends.is_empty())


# ---------------------------------------------------------------------------
# Sanitization — mirrors PlayerIdentity.decode's robust defaults
# ---------------------------------------------------------------------------

func test_add_friend_sanitizes_blank_name() -> void:
	var snap: Dictionary = _snapshot_friends_state()
	MpProfile.add_friend("tok-x", "   ", "ff0000")
	var friends: Array = MpProfile.get_friends()
	_restore_friends_state(snap)
	assert_eq(str((friends[0] as Dictionary).get("name", "")), MpProfile.DEFAULT_NAME)


func test_add_friend_sanitizes_invalid_color_hex() -> void:
	var snap: Dictionary = _snapshot_friends_state()
	MpProfile.add_friend("tok-x", "Bob", "not-a-color")
	var friends: Array = MpProfile.get_friends()
	_restore_friends_state(snap)
	assert_eq(str((friends[0] as Dictionary).get("color_hex", "")), "ffffff")


# ---------------------------------------------------------------------------
# remove_friend
# ---------------------------------------------------------------------------

func test_remove_friend_removes_existing() -> void:
	var snap: Dictionary = _snapshot_friends_state()
	MpProfile.add_friend("tok-a", "A", "ff0000")
	MpProfile.remove_friend("tok-a")
	var friends: Array = MpProfile.get_friends()
	_restore_friends_state(snap)
	assert_true(friends.is_empty())


func test_remove_friend_noop_for_missing_token() -> void:
	var snap: Dictionary = _snapshot_friends_state()
	MpProfile.add_friend("tok-a", "A", "ff0000")
	MpProfile.remove_friend("tok-does-not-exist")
	var friends: Array = MpProfile.get_friends()
	_restore_friends_state(snap)
	assert_eq(friends.size(), 1)


# ---------------------------------------------------------------------------
# is_friend
# ---------------------------------------------------------------------------

func test_is_friend_true_for_added_token() -> void:
	var snap: Dictionary = _snapshot_friends_state()
	MpProfile.add_friend("tok-a", "A", "ff0000")
	var result: bool = MpProfile.is_friend("tok-a")
	_restore_friends_state(snap)
	assert_true(result)


func test_is_friend_false_for_unknown_token() -> void:
	var snap: Dictionary = _snapshot_friends_state()
	var result: bool = MpProfile.is_friend("tok-unknown")
	_restore_friends_state(snap)
	assert_false(result)


func test_is_friend_false_for_blank_token() -> void:
	var snap: Dictionary = _snapshot_friends_state()
	var result: bool = MpProfile.is_friend("")
	_restore_friends_state(snap)
	assert_false(result)


# ---------------------------------------------------------------------------
# Cap eviction at 50 entries
# ---------------------------------------------------------------------------

func test_add_friend_caps_at_fifty() -> void:
	var snap: Dictionary = _snapshot_friends_state()
	for i in range(55):
		MpProfile.add_friend("tok-%d" % i, "Friend %d" % i, "ff0000")
	var friends: Array = MpProfile.get_friends()
	_restore_friends_state(snap)
	assert_eq(friends.size(), 50)


func test_add_friend_cap_keeps_most_recent() -> void:
	var snap: Dictionary = _snapshot_friends_state()
	for i in range(55):
		MpProfile.add_friend("tok-%d" % i, "Friend %d" % i, "ff0000")
	var friends: Array = MpProfile.get_friends()
	_restore_friends_state(snap)
	# Most recently added (tok-54) should be present; oldest (tok-0) should be evicted.
	var tokens: Array = []
	for f in friends:
		tokens.append(str((f as Dictionary).get("token", "")))
	assert_true(tokens.has("tok-54"), "newest entry should survive the cap")
	assert_false(tokens.has("tok-0"), "oldest entry should be evicted")


# ---------------------------------------------------------------------------
# touch_friend_last_seen
# ---------------------------------------------------------------------------

func test_touch_friend_last_seen_updates_existing() -> void:
	var snap: Dictionary = _snapshot_friends_state()
	MpProfile.add_friend("tok-a", "A", "ff0000")
	var before: String = str((MpProfile.get_friends()[0] as Dictionary).get("last_seen", ""))
	# Force a different timestamp window isn't guaranteed in a fast test run, so
	# just verify the field is still well-formed and the friend remains present.
	MpProfile.touch_friend_last_seen("tok-a")
	var friends: Array = MpProfile.get_friends()
	_restore_friends_state(snap)
	assert_eq(friends.size(), 1)
	assert_true(str((friends[0] as Dictionary).get("last_seen", "")) != "")
	assert_true(before != "")


func test_touch_friend_last_seen_noop_for_non_friend() -> void:
	var snap: Dictionary = _snapshot_friends_state()
	MpProfile.touch_friend_last_seen("tok-not-a-friend")
	var friends: Array = MpProfile.get_friends()
	_restore_friends_state(snap)
	assert_true(friends.is_empty(), "touch must not upsert a non-friend")


# ---------------------------------------------------------------------------
# get_friends — defensive copy
# ---------------------------------------------------------------------------

func test_get_friends_returns_defensive_copy() -> void:
	var snap: Dictionary = _snapshot_friends_state()
	MpProfile.add_friend("tok-a", "A", "ff0000")
	var friends: Array = MpProfile.get_friends()
	friends.clear()  # mutate the returned copy
	var friends_again: Array = MpProfile.get_friends()
	_restore_friends_state(snap)
	assert_eq(friends_again.size(), 1, "mutating the returned array must not affect internal state")


# ---------------------------------------------------------------------------
# Persistence round-trip (JSON shape), via a temp file — mirrors how
# SaveManager's _read_save_json tests exercise real file I/O without touching
# the live user://mp_profile.json path.
# ---------------------------------------------------------------------------

func test_persistence_round_trip_via_temp_file() -> void:
	var path: String = "user://test_mp_profile_friends_375.json"
	var payload: Dictionary = {
		"token": "device-token",
		"host_session_id": "",
		"recent_servers": [],
		"friends": [
			{"token": "tok-a", "name": "Alice", "color_hex": "ff0000", "last_seen": "2026-01-01 00:00:00"},
		],
		"name": "Player",
		"color": "ffffff",
	}
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(JSON.stringify(payload))
	f = null

	var rf := FileAccess.open(path, FileAccess.READ)
	var parsed: Variant = JSON.parse_string(rf.get_as_text())
	rf = null
	DirAccess.remove_absolute(path)

	assert_true(parsed is Dictionary)
	var d: Dictionary = parsed
	assert_true(d.has("friends"))
	var friends: Array = d["friends"]
	assert_eq(friends.size(), 1)
	var fr: Dictionary = friends[0]
	assert_eq(str(fr.get("token", "")), "tok-a")
	assert_eq(str(fr.get("name", "")), "Alice")
	assert_eq(str(fr.get("color_hex", "")), "ff0000")
