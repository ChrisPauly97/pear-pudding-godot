## Unit tests for the PvP resume record (GID-102 / TID-372, extended by GID-115 /
## TID-434 to carry the draft-duel deck override — fixes BID-035). Mirrors
## test_scene_manager_state.gd's style: manipulate the live NetworkManager autoload
## directly, save/restore around each test to avoid cross-test pollution.
extends "res://tests/framework/test_case.gd"

var _saved_pvp_resume: Dictionary = {}

func before_each() -> void:
	_saved_pvp_resume = NetworkManager.get_pvp_resume().duplicate(true)

func after_each() -> void:
	NetworkManager.clear_pvp_resume()
	if not _saved_pvp_resume.is_empty():
		NetworkManager._pvp_resume = _saved_pvp_resume.duplicate(true)


func test_no_resume_by_default() -> void:
	NetworkManager.clear_pvp_resume()
	assert_false(NetworkManager.has_pvp_resume())


func test_set_pvp_resume_without_override_defaults_empty() -> void:
	NetworkManager.set_pvp_resume(1, [{"uid": "ghost_a_0"}], 0)
	assert_true(NetworkManager.has_pvp_resume())
	var rec: Dictionary = NetworkManager.get_pvp_resume()
	assert_eq((rec.get("local_deck_override", []) as Array), [])


func test_set_pvp_resume_carries_deck_override_through() -> void:
	var drafted: Array = [{"uid": "draft_tok_0_0", "template_id": "ghost"}]
	NetworkManager.set_pvp_resume(1, [{"uid": "opp_a_0"}], 0, drafted)
	var rec: Dictionary = NetworkManager.get_pvp_resume()
	assert_eq((rec.get("local_deck_override", []) as Array), drafted)


func test_set_pvp_resume_preserves_local_idx_and_ante() -> void:
	NetworkManager.set_pvp_resume(1, [], 50, [{"uid": "x"}])
	var rec: Dictionary = NetworkManager.get_pvp_resume()
	assert_eq(int(rec.get("local_idx", -99)), 1)
	assert_eq(int(rec.get("ante_coins", -99)), 50)


func test_clear_pvp_resume_removes_override_too() -> void:
	NetworkManager.set_pvp_resume(1, [], 0, [{"uid": "x"}])
	NetworkManager.clear_pvp_resume()
	assert_false(NetworkManager.has_pvp_resume())
	assert_true(NetworkManager.get_pvp_resume().is_empty())
