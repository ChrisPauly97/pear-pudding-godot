## Unit tests for stylised screen transitions (GID-133 / TID-516).
## (The awaited cover/uncover sequence is exercised by spire_draft_smoke.)
extends "res://tests/framework/test_case.gd"

const _TM = preload("res://autoloads/TransitionManager.gd")


func test_wipe_rect_idle_state() -> void:
	# A fresh instance: the autoload's _ready has not run inside the unit runner.
	var tm: _TM = _TM.new()
	tm._ready()
	assert_almost_eq(tm.progress(), 0.0, 0.0001, "clear at rest")
	assert_false(tm._rect.visible, "no full-screen overlay drawn while idle")
	assert_eq(tm._rect.mouse_filter, Control.MOUSE_FILTER_IGNORE)
	assert_not_null(tm._mat.shader)
	tm.free()

func test_styles_and_duration() -> void:
	assert_ne(_TM.STYLE_WIPE, _TM.STYLE_BATTLE)
	assert_between(_TM.FADE_DURATION, 0.15, 0.5, "snappy enough to not feel like loading")
