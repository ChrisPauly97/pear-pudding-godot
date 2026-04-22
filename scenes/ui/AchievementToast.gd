extends CanvasLayer

const AchievementRegistry = preload("res://game_logic/AchievementRegistry.gd")

var _queue: Array[String] = []
var _panel: Control = null
var _label_title: Label = null
var _label_desc: Label = null
var _tween: Tween = null
var _busy: bool = false
var _vh: float = 0.0
var _vw: float = 0.0

func _ready() -> void:
	layer = 200
	_vh = get_viewport().get_visible_rect().size.y
	_vw = get_viewport().get_visible_rect().size.x
	_build_panel()
	GameBus.achievement_unlocked.connect(_on_achievement_unlocked)

func _build_panel() -> void:
	var panel_w: float = _vw * 0.32
	var panel_h: float = _vh * 0.10
	var margin: float = _vh * 0.02

	_panel = PanelContainer.new()
	_panel.custom_minimum_size = Vector2(panel_w, panel_h)
	_panel.size = Vector2(panel_w, panel_h)
	_panel.position = Vector2(_vw + 10.0, margin)
	add_child(_panel)

	var inner := MarginContainer.new()
	inner.add_theme_constant_override("margin_left",   int(_vw * 0.01))
	inner.add_theme_constant_override("margin_right",  int(_vw * 0.01))
	inner.add_theme_constant_override("margin_top",    int(_vh * 0.008))
	inner.add_theme_constant_override("margin_bottom", int(_vh * 0.008))
	_panel.add_child(inner)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", int(_vh * 0.004))
	inner.add_child(vbox)

	var header_row := HBoxContainer.new()
	header_row.add_theme_constant_override("separation", int(_vw * 0.006))
	vbox.add_child(header_row)

	var icon_lbl := Label.new()
	icon_lbl.text = "Achievement!"
	icon_lbl.add_theme_font_size_override("font_size", int(_vh * 0.018))
	icon_lbl.modulate = Color(1.0, 0.85, 0.2)
	header_row.add_child(icon_lbl)

	_label_title = Label.new()
	_label_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_label_title.add_theme_font_size_override("font_size", int(_vh * 0.022))
	_label_title.text = ""
	vbox.add_child(_label_title)

	_label_desc = Label.new()
	_label_desc.add_theme_font_size_override("font_size", int(_vh * 0.017))
	_label_desc.modulate = Color(0.8, 0.8, 0.8)
	_label_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label_desc.text = ""
	vbox.add_child(_label_desc)

func _on_achievement_unlocked(achievement_id: String) -> void:
	_queue.append(achievement_id)
	if not _busy:
		_show_next()

func _show_next() -> void:
	if _queue.is_empty():
		_busy = false
		return
	_busy = true
	var aid: String = _queue.pop_front()
	var a: Dictionary = AchievementRegistry.get_achievement(aid)
	_label_title.text = str(a.get("name", aid))
	_label_desc.text = str(a.get("description", ""))

	var panel_w: float = _vw * 0.32
	var margin: float = _vh * 0.02
	var target_x: float = _vw - panel_w - margin

	if _tween:
		_tween.kill()
	_panel.position.x = _vw + 10.0
	_panel.position.y = margin

	_tween = create_tween()
	_tween.tween_property(_panel, "position:x", target_x, 0.3).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUART)
	_tween.tween_interval(3.0)
	_tween.tween_property(_panel, "position:x", _vw + 10.0, 0.3).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUART)
	_tween.tween_callback(_show_next)
