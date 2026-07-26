extends "res://scenes/ui/BaseOverlay.gd"
const _UiUtil = preload("res://scenes/ui/UiUtil.gd")

signal gambit_chosen(gambit_id: String)

const Gambits = preload("res://game_logic/battle/Gambits.gd")

var _auto_skip_check: CheckBox = null

func _ready() -> void:
	super._ready()
	_build_backdrop(0.65)
	var panel_w: float = minf(_vw * 0.85, _vh * 0.95)
	var panel := _build_centered_panel(panel_w, 0)
	panel.custom_minimum_size.x = panel_w
	var style: StyleBoxFlat = _make_dark_glass_style()
	panel.add_theme_stylebox_override("panel", style)

	var vbox: VBoxContainer = _build_margin_vbox(panel, 0.025, 0.018)

	var title := _UiUtil.make_label("Choose a Gambit (optional)", int(_vh * 0.032), Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, vbox)

	var sub := _UiUtil.make_label("Accept a handicap for better rewards — or skip for a normal fight.", int(_vh * 0.020), Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, vbox)
	sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	vbox.add_child(HSeparator.new())

	for gid: String in Gambits.ALL.keys():
		var gdata: Dictionary = Gambits.ALL[gid]
		var gname: String = str(gdata.get("name", gid))
		var gdesc: String = str(gdata.get("desc", ""))
		var gmult: float = float(gdata.get("multiplier", 1.0))
		var btn := _UiUtil.make_button("%s — %s  (×%.1f coins & rarity)" % [gname, gdesc, gmult], Vector2(panel_w * 0.85, _vh * 0.065), int(_vh * 0.020))
		btn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		var captured_gid: String = gid
		btn.pressed.connect(func() -> void: _pick(captured_gid))
		vbox.add_child(btn)

	vbox.add_child(HSeparator.new())

	var no_btn := _UiUtil.make_button("No Gambit  —  Normal Battle", Vector2(panel_w * 0.85, _vh * 0.065), int(_vh * 0.024), func() -> void: _pick(""), vbox)

	_auto_skip_check = CheckBox.new()
	_auto_skip_check.text = "Don't ask again (always skip gambits)"
	_auto_skip_check.add_theme_font_size_override("font_size", int(_vh * 0.018))
	vbox.add_child(_auto_skip_check)

func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		_pick("")
		get_viewport().set_input_as_handled()

func _pick(gambit_id: String) -> void:
	if _auto_skip_check != null and _auto_skip_check.button_pressed:
		SceneManager.save_manager.set_setting("auto_skip_gambits", true)
		SceneManager.save_manager.save()
	gambit_chosen.emit(gambit_id)
