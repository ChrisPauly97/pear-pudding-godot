## Unit tests for HUD action icons (GID-132 / TID-510).
extends "res://tests/framework/test_case.gd"

const HI = preload("res://scenes/ui/HudIcons.gd")


func test_every_icon_loads() -> void:
	for id: Variant in HI.ids():
		assert_not_null(HI.icon_for(str(id)), str(id))
	assert_null(HI.icon_for("no_such_action"))

func test_core_hud_actions_have_icons() -> void:
	for id: String in ["interact", "pause", "menu_hub", "mount", "cantrip_ghost_phase", "cantrip_skeleton_dig"]:
		assert_true(HI.has_icon(id), id)

func test_apply_sets_icon_and_icon_only_labels() -> void:
	var b := Button.new()
	b.text = "II"
	HI.apply(b, "pause", 32)
	assert_not_null(b.icon)
	assert_eq(b.text, "", "stand-in glyph replaced by the icon")
	var m := Button.new()
	m.text = "Mount"
	HI.apply(m, "mount", 32)
	assert_eq(m.text, "Mount", "labelled actions keep their text")
	var n := Button.new()
	HI.apply(n, "unknown", 32)
	assert_null(n.icon)
	b.free()
	m.free()
	n.free()

func test_icon_licence_present() -> void:
	assert_true(FileAccess.file_exists("res://assets/icons/hud/LICENSE-game-icons.txt"))
