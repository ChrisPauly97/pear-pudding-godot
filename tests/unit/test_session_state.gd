## Unit tests for SessionState (GID-095 / TID-345) — the pure persistent-session
## model: to_dict/from_dict round-trip, member lookup/create by token, the migration
## scaffold, and starter-character seeding. Mirrors test_player_identity.gd.
extends "res://tests/framework/test_case.gd"

const SessionState = preload("res://game_logic/net/SessionState.gd")


func _make_populated() -> SessionState:
	var s := SessionState.new()
	s.session_id = "world_abc"
	s.display_name = "Maiteln's World"
	s.current_map = "madrian"
	s.world_seed = 1234
	s.time_of_day = 0.6
	s.days_elapsed = 3
	s.defeated_enemies = ["enemy_1", "enemy_2"]
	s.opened_chests = ["chest_7"]
	s.story_flags = {"chapter1_left_madrian": true}
	s.ensure_member("tokenA", "Saimtar")
	return s


# ---------------------------------------------------------------------------
# to_dict / from_dict round-trip
# ---------------------------------------------------------------------------

func test_round_trip_preserves_identity_and_world() -> void:
	var s := _make_populated()
	var restored := SessionState.from_dict(s.to_dict())
	assert_eq(restored.session_id, "world_abc")
	assert_eq(restored.display_name, "Maiteln's World")
	assert_eq(restored.current_map, "madrian")
	assert_eq(restored.world_seed, 1234)
	assert_almost_eq(restored.time_of_day, 0.6)
	assert_eq(restored.days_elapsed, 3)


func test_round_trip_preserves_world_progress_collections() -> void:
	var s := _make_populated()
	var restored := SessionState.from_dict(s.to_dict())
	assert_has(restored.defeated_enemies, "enemy_1")
	assert_has(restored.defeated_enemies, "enemy_2")
	assert_has(restored.opened_chests, "chest_7")
	assert_true(restored.story_flags.get("chapter1_left_madrian", false))


func test_round_trip_preserves_members() -> void:
	var s := _make_populated()
	var restored := SessionState.from_dict(s.to_dict())
	assert_true(restored.has_member("tokenA"))
	var rec: Dictionary = restored.get_member("tokenA")
	assert_eq(str(rec.get("display_name", "")), "Saimtar")


func test_to_dict_stamps_current_version() -> void:
	var s := SessionState.new()
	assert_eq(int(s.to_dict().get("version", -1)), SessionState.CURRENT_SESSION_VERSION)


# ---------------------------------------------------------------------------
# Member roster
# ---------------------------------------------------------------------------

func test_has_member_false_for_unknown_token() -> void:
	var s := SessionState.new()
	assert_false(s.has_member("nope"))
	assert_false(s.has_member(""))


func test_get_member_returns_empty_for_unknown() -> void:
	var s := SessionState.new()
	assert_true(s.get_member("nope").is_empty())


func test_ensure_member_creates_on_miss() -> void:
	var s := SessionState.new()
	assert_false(s.has_member("tok"))
	var rec: Dictionary = s.ensure_member("tok", "Ada")
	assert_true(s.has_member("tok"))
	assert_eq(str(rec.get("token", "")), "tok")
	assert_eq(str(rec.get("display_name", "")), "Ada")


func test_ensure_member_resumes_on_hit_without_resetting_progress() -> void:
	var s := SessionState.new()
	s.ensure_member("tok", "Ada")
	# Mutate the stored record (simulate progress), then ensure again.
	var rec: Dictionary = s.get_member("tok")
	rec["coins"] = 9999
	s.update_member("tok", rec)
	var again: Dictionary = s.ensure_member("tok", "Ada Renamed")
	assert_eq(int(again.get("coins", 0)), 9999, "resume must not wipe progress")
	assert_eq(str(again.get("display_name", "")), "Ada Renamed", "name refreshes on resume")


func test_update_member_replaces_record() -> void:
	var s := SessionState.new()
	s.ensure_member("tok", "Ada")
	s.update_member("tok", {"token": "tok", "coins": 42})
	assert_eq(int(s.get_member("tok").get("coins", 0)), 42)


func test_update_member_ignores_blank_token() -> void:
	var s := SessionState.new()
	s.update_member("", {"coins": 1})
	assert_false(s.has_member(""))


# ---------------------------------------------------------------------------
# Starter character seeding
# ---------------------------------------------------------------------------

func test_starter_has_full_deck() -> void:
	var rec: Dictionary = SessionState.make_starter_character("tok", "Ada")
	var deck: Array = rec.get("player_deck", [])
	var owned: Array = rec.get("owned_cards", [])
	assert_eq(deck.size(), 12)
	assert_eq(owned.size(), 12)


func test_starter_seeds_coins_and_defaults() -> void:
	var rec: Dictionary = SessionState.make_starter_character("tok", "Ada")
	assert_gt(int(rec.get("coins", 0)), 0)
	assert_eq(int(rec.get("level", 0)), 1)
	assert_eq(str(rec.get("magic_type", "x")), "")


func test_starter_uids_are_token_salted_and_unique() -> void:
	var a: Dictionary = SessionState.make_starter_character("tokA", "A")
	var b: Dictionary = SessionState.make_starter_character("tokB", "B")
	var a_uids: Dictionary = {}
	for inst in a.get("owned_cards", []):
		a_uids[str(inst.get("uid", ""))] = true
	# No UID collides between two different members' starter decks.
	for inst in b.get("owned_cards", []):
		assert_false(a_uids.has(str(inst.get("uid", ""))),
			"starter UIDs must not collide across members")


func test_starter_deck_uids_reference_owned_cards() -> void:
	var rec: Dictionary = SessionState.make_starter_character("tok", "Ada")
	var owned_uids: Dictionary = {}
	for inst in rec.get("owned_cards", []):
		owned_uids[str(inst.get("uid", ""))] = true
	for uid in rec.get("player_deck", []):
		assert_true(owned_uids.has(str(uid)), "deck UID must exist in owned_cards")


# ---------------------------------------------------------------------------
# Migration scaffold
# ---------------------------------------------------------------------------

func test_from_dict_versionless_is_upgraded() -> void:
	# A legacy dict with no version still loads and is stamped to the current version.
	var data: Dictionary = {"session_id": "old", "members": {}}
	var s := SessionState.from_dict(data)
	assert_eq(s.session_id, "old")
	assert_eq(int(s.to_dict().get("version", -1)), SessionState.CURRENT_SESSION_VERSION)


func test_from_dict_tolerates_garbage_fields() -> void:
	# Wrong-typed fields must not crash; they fall back to safe defaults.
	var data: Dictionary = {
		"session_id": "g", "members": "not-a-dict",
		"defeated_enemies": "nope", "story_flags": 7,
	}
	var s := SessionState.from_dict(data)
	assert_true(s.members.is_empty())
	assert_true(s.defeated_enemies.is_empty())
	assert_true(s.story_flags.is_empty())


# ---------------------------------------------------------------------------
# PvP champion record (GID-101 / TID-368)
# ---------------------------------------------------------------------------

func test_starter_has_pvp_fields_zeroed() -> void:
	var rec: Dictionary = SessionState.make_starter_character("tok", "Ada")
	assert_eq(int(rec.get("pvp_wins", -1)), 0)
	assert_eq(int(rec.get("pvp_losses", -1)), 0)
	assert_eq(int(rec.get("pvp_streak", -1)), 0)
	assert_eq(int(rec.get("pvp_best_streak", -1)), 0)


func test_round_trip_preserves_pvp_stats() -> void:
	var s := SessionState.new()
	s.ensure_member("tok", "Ada")
	var rec: Dictionary = s.get_member("tok")
	rec["pvp_wins"] = 5
	rec["pvp_losses"] = 2
	rec["pvp_streak"] = 3
	rec["pvp_best_streak"] = 4
	s.update_member("tok", rec)
	var restored := SessionState.from_dict(s.to_dict())
	var r: Dictionary = restored.get_member("tok")
	assert_eq(int(r.get("pvp_wins", -1)), 5)
	assert_eq(int(r.get("pvp_losses", -1)), 2)
	assert_eq(int(r.get("pvp_streak", -1)), 3)
	assert_eq(int(r.get("pvp_best_streak", -1)), 4)


func test_migration_v2_adds_party_bounties() -> void:
	var data: Dictionary = {"version": 1, "session_id": "old", "members": {}}
	var s := SessionState.from_dict(data)
	assert_true(s.party_bounties is Array)
	assert_eq(int(s.to_dict().get("version", -1)), SessionState.CURRENT_SESSION_VERSION)


func test_migration_v3_backfills_pvp_stats_on_existing_members() -> void:
	# Simulate a v2 session with a member that has no pvp fields.
	var data: Dictionary = {
		"version": 2,
		"session_id": "old",
		"party_bounties": [],
		"members": {
			"tokA": {
				"token": "tokA",
				"display_name": "Ada",
				"coins": 500,
			}
		}
	}
	var s := SessionState.from_dict(data)
	var rec: Dictionary = s.get_member("tokA")
	assert_eq(int(rec.get("pvp_wins", -1)), 0, "pvp_wins backfilled to 0")
	assert_eq(int(rec.get("pvp_losses", -1)), 0, "pvp_losses backfilled to 0")
	assert_eq(int(rec.get("pvp_streak", -1)), 0, "pvp_streak backfilled to 0")
	assert_eq(int(rec.get("pvp_best_streak", -1)), 0, "pvp_best_streak backfilled to 0")
	assert_eq(int(rec.get("coins", 0)), 500, "existing fields preserved")


# ---------------------------------------------------------------------------
# PvP ranked rating (GID-102 / TID-370)
# ---------------------------------------------------------------------------

func test_starter_has_rating_fields_defaulted() -> void:
	var rec: Dictionary = SessionState.make_starter_character("tok", "Ada")
	assert_eq(int(rec.get("pvp_rating", -1)), 1000)
	assert_eq(int(rec.get("pvp_games", -1)), 0)


func test_round_trip_preserves_rating_fields() -> void:
	var s := SessionState.new()
	s.ensure_member("tok", "Ada")
	var rec: Dictionary = s.get_member("tok")
	rec["pvp_rating"] = 1234
	rec["pvp_games"] = 17
	s.update_member("tok", rec)
	var restored := SessionState.from_dict(s.to_dict())
	var r: Dictionary = restored.get_member("tok")
	assert_eq(int(r.get("pvp_rating", -1)), 1234)
	assert_eq(int(r.get("pvp_games", -1)), 17)


func test_migration_v4_backfills_rating_on_existing_members() -> void:
	# A v3 session with a member that predates the rating fields.
	var data: Dictionary = {
		"version": 3,
		"session_id": "old",
		"party_bounties": [],
		"members": {
			"tokA": {
				"token": "tokA", "display_name": "Ada", "coins": 500,
				"pvp_wins": 4, "pvp_losses": 1, "pvp_streak": 2, "pvp_best_streak": 3,
			}
		}
	}
	var s := SessionState.from_dict(data)
	var rec: Dictionary = s.get_member("tokA")
	assert_eq(int(rec.get("pvp_rating", -1)), 1000, "pvp_rating backfilled to 1000")
	assert_eq(int(rec.get("pvp_games", -1)), 0, "pvp_games backfilled to 0")
	assert_eq(int(rec.get("pvp_wins", 0)), 4, "existing pvp fields preserved")
	assert_eq(int(s.to_dict().get("version", -1)), SessionState.CURRENT_SESSION_VERSION)


# ---------------------------------------------------------------------------
# Derived leaderboard (GID-102 / TID-370)
# ---------------------------------------------------------------------------

func test_leaderboard_sorts_by_rating_desc() -> void:
	var s := SessionState.new()
	for entry in [["a", "A", 1100], ["b", "B", 1500], ["c", "C", 900]]:
		s.ensure_member(entry[0], entry[1])
		var rec: Dictionary = s.get_member(entry[0])
		rec["pvp_rating"] = entry[2]
		s.update_member(entry[0], rec)
	var lb: Array = s.get_leaderboard()
	assert_eq(lb.size(), 3)
	assert_eq(str(lb[0]["token"]), "b", "highest rating first")
	assert_eq(str(lb[1]["token"]), "a")
	assert_eq(str(lb[2]["token"]), "c", "lowest rating last")
	assert_eq(int(lb[0]["rating"]), 1500)


func test_leaderboard_respects_limit() -> void:
	var s := SessionState.new()
	for i in range(5):
		s.ensure_member("tok%d" % i, "P%d" % i)
	var lb: Array = s.get_leaderboard(2)
	assert_eq(lb.size(), 2)


func test_leaderboard_includes_name_and_record() -> void:
	var s := SessionState.new()
	s.ensure_member("tok", "Ada")
	var rec: Dictionary = s.get_member("tok")
	rec["pvp_wins"] = 7
	rec["pvp_losses"] = 3
	s.update_member("tok", rec)
	var row: Dictionary = s.get_leaderboard()[0]
	assert_eq(str(row["name"]), "Ada")
	assert_eq(int(row["wins"]), 7)
	assert_eq(int(row["losses"]), 3)


func test_leaderboard_empty_for_no_members() -> void:
	var s := SessionState.new()
	assert_true(s.get_leaderboard().is_empty())


# ---------------------------------------------------------------------------
# Party bounties (GID-101 / TID-369)
# ---------------------------------------------------------------------------

func test_party_bounties_defaults_to_empty_array() -> void:
	var s := SessionState.new()
	assert_true(s.party_bounties is Array)
	assert_true(s.party_bounties.is_empty())


func test_party_bounties_round_trip() -> void:
	var s := SessionState.new()
	s.party_bounties = [
		{"id": "b1", "type": "kill", "target": "skeleton", "count": 5, "progress": 2,
		 "contributors": ["tokA"], "completed": false},
	]
	var restored := SessionState.from_dict(s.to_dict())
	assert_eq(restored.party_bounties.size(), 1)
	var b: Dictionary = restored.party_bounties[0]
	assert_eq(str(b.get("id", "")), "b1")
	assert_eq(int(b.get("progress", -1)), 2)
	assert_false(bool(b.get("completed", true)))


func test_party_bounties_garbage_field_returns_empty_array() -> void:
	var data: Dictionary = {
		"version": SessionState.CURRENT_SESSION_VERSION,
		"party_bounties": "not-an-array",
	}
	var s := SessionState.from_dict(data)
	assert_true(s.party_bounties.is_empty())


# ---------------------------------------------------------------------------
# Shared party stash (GID-102 / TID-376)
# ---------------------------------------------------------------------------

func test_stash_defaults_to_empty_cards_and_zero_coins() -> void:
	var s := SessionState.new()
	assert_true(s.stash.get("cards", null) is Array)
	assert_true((s.stash["cards"] as Array).is_empty())
	assert_eq(int(s.stash.get("coins", -1)), 0)


func test_stash_round_trip_preserves_cards_and_coins() -> void:
	var s := SessionState.new()
	s.stash = {
		"cards": [{"uid": "ghost_stash_0", "template_id": "ghost", "rarity": "common"}],
		"coins": 250,
	}
	var restored := SessionState.from_dict(s.to_dict())
	assert_eq(int(restored.stash.get("coins", -1)), 250)
	var cards: Array = restored.stash.get("cards", [])
	assert_eq(cards.size(), 1)
	assert_eq(str((cards[0] as Dictionary).get("uid", "")), "ghost_stash_0")


func test_stash_garbage_field_falls_back_to_empty_defaults() -> void:
	var data: Dictionary = {
		"version": SessionState.CURRENT_SESSION_VERSION,
		"stash": "not-a-dict",
	}
	var s := SessionState.from_dict(data)
	assert_true((s.stash.get("cards", null) as Array).is_empty())
	assert_eq(int(s.stash.get("coins", -1)), 0)


func test_stash_garbage_cards_field_falls_back_to_empty_array() -> void:
	var data: Dictionary = {
		"version": SessionState.CURRENT_SESSION_VERSION,
		"stash": {"cards": "not-an-array", "coins": 40},
	}
	var s := SessionState.from_dict(data)
	assert_true((s.stash.get("cards", null) as Array).is_empty())
	assert_eq(int(s.stash.get("coins", -1)), 40)


func test_migration_v4_backfills_missing_stash() -> void:
	# Simulate a v3 session file that predates the stash field entirely.
	var data: Dictionary = {
		"version": 3,
		"session_id": "old",
		"party_bounties": [],
		"members": {},
	}
	var s := SessionState.from_dict(data)
	assert_true(s.stash.get("cards", null) is Array)
	assert_true((s.stash["cards"] as Array).is_empty())
	assert_eq(int(s.stash.get("coins", -1)), 0)
	assert_eq(int(s.to_dict().get("version", -1)), SessionState.CURRENT_SESSION_VERSION)


func test_from_dict_versionless_still_gets_stash_default() -> void:
	# A very old dict with no version and no stash key at all.
	var data: Dictionary = {"session_id": "ancient", "members": {}}
	var s := SessionState.from_dict(data)
	assert_true((s.stash.get("cards", null) as Array).is_empty())
	assert_eq(int(s.stash.get("coins", -1)), 0)
