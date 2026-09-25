## Unit tests for the project UI theme (GID-131 / TID-507).
extends "res://tests/framework/test_case.gd"

const UT = preload("res://scenes/ui/UiTheme.gd")


func test_theme_styles_core_controls() -> void:
	var t: Theme = UT.build()
	for type: String in ["Button", "OptionButton"]:
		for state: String in ["normal", "hover", "pressed", "disabled", "focus"]:
			assert_true(t.has_stylebox(state, type), "%s/%s" % [type, state])
	for type: String in ["Panel", "PanelContainer", "PopupMenu"]:
		assert_true(t.has_stylebox("panel", type), type)
	assert_true(t.has_color("font_color", "Label"))
	var sb: StyleBoxFlat = t.get_stylebox("panel", "PanelContainer") as StyleBoxFlat
	assert_eq(sb.corner_radius_top_left, UT.PANEL_RADIUS)

func test_installed_theme_reaches_controls_under_a_canvas_layer() -> void:
	UT.install()
	var cl := CanvasLayer.new()
	var b := Button.new()
	cl.add_child(b)
	(Engine.get_main_loop() as SceneTree).root.add_child(cl)
	var sb: StyleBoxFlat = b.get_theme_stylebox("normal") as StyleBoxFlat
	assert_not_null(sb)
	if sb != null:
		assert_eq(sb.bg_color, UT.BUTTON_BG)
	cl.free()
