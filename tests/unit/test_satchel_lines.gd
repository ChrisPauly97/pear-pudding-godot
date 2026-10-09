## SatchelLines (GID-180 / TID-743): companion grumbles + bag fullness steps.
extends "res://tests/framework/test_case.gd"

const SatchelLines = preload("res://game_logic/inventory/SatchelLines.gd")


func test_lines_rotate_and_fill_card_name() -> void:
	assert_ne(SatchelLines.line("full", "maiteln", 0), SatchelLines.line("full", "maiteln", 1))
	assert_true(SatchelLines.line("mailbox", "", 0, "Ghost").begins_with("Ghost"))
	assert_true(SatchelLines.line("mailbox", "maiteln", 3, "Ghost").contains("Ghost"))


func test_unknown_companion_falls_back_to_satchel() -> void:
	assert_eq(SatchelLines.line("full", "nobody", 0), SatchelLines.line("full", "", 0))
	assert_eq(SatchelLines.line("nope", "", 0), "")


func test_fullness_steps() -> void:
	assert_eq(SatchelLines.fullness(10, 60), 0)
	assert_eq(SatchelLines.fullness(45, 60), 1)
	assert_eq(SatchelLines.fullness(55, 60), 2)
	assert_eq(SatchelLines.fullness(60, 60), 3)
	assert_eq(SatchelLines.fullness(0, 0), 3)
