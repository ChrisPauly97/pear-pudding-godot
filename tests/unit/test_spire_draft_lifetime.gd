## Unit tests for the Endless Spire draft's "is a pick still owed?" predicate.
##
## Background — the bug this guards: _spire_battle_won called _restore_world()
## and then, on the very next line, parented the SpireDraftScene to
## get_tree().current_scene. But _restore_world defers the scene swap behind
## TransitionManager's 0.2 s fade, so current_scene was still the battle overlay
## that _finish_battle had just queue_free()d — the draft became its child and
## died with it at the end of the frame. The player cleared a floor, never saw a
## draft, and the run carried on with the same deck ("stuck in the dungeon").
##
## The post-victory flow itself needs a live SceneTree (the unit runner drives
## tests from SceneTree._initialize, where SceneManager.get_tree() is still
## null), so it lives in tests/spire_draft_smoke.gd. What is testable here is the
## predicate both the fix and the exit-door guard hang off.
extends "res://tests/framework/test_case.gd"

var _saved_draft_overlay: Variant = null

func before_each() -> void:
	_saved_draft_overlay = SceneManager._spire_draft_overlay

func after_each() -> void:
	SceneManager._spire_draft_overlay = _saved_draft_overlay

func test_draft_open_is_false_when_no_overlay() -> void:
	SceneManager._spire_draft_overlay = null
	assert_false(SceneManager.is_spire_draft_open())

func test_draft_open_is_true_for_a_live_overlay() -> void:
	var overlay := Node.new()
	SceneManager._spire_draft_overlay = overlay
	assert_true(SceneManager.is_spire_draft_open())
	SceneManager._spire_draft_overlay = null
	overlay.free()

func test_draft_open_is_false_for_a_freed_overlay() -> void:
	# A plain `!= null` check reports true for a freed instance and then errors on
	# the next method call — this must go through is_instance_valid.
	var stale := Node.new()
	SceneManager._spire_draft_overlay = stale
	stale.free()
	assert_false(SceneManager.is_spire_draft_open(), "a freed overlay must not count as open")
	SceneManager._spire_draft_overlay = null
