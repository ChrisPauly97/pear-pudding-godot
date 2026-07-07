## Unit tests for UiFx (TID-429): attach idempotency and safety, since the
## actual scale/click-sound behavior is tween/audio-driven and not practical
## to assert headlessly.
extends "res://tests/framework/test_case.gd"

const UiFx = preload("res://scenes/ui/UiFx.gd")

func test_attach_sets_meta_guard() -> void:
	var btn := Button.new()
	assert_false(btn.has_meta("_uifx_attached"))
	UiFx.attach(btn)
	assert_true(btn.has_meta("_uifx_attached"))
	btn.free()

func test_attach_is_idempotent() -> void:
	var btn := Button.new()
	UiFx.attach(btn)
	var first_count: int = btn.button_down.get_connections().size()
	UiFx.attach(btn)
	var second_count: int = btn.button_down.get_connections().size()
	assert_eq(first_count, second_count, "second attach() must not add duplicate connections")
	btn.free()

func test_attach_null_is_safe() -> void:
	UiFx.attach(null)  # must not crash
