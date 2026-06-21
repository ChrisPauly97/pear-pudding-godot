extends "res://scenes/ui/BaseOverlay.gd"

const _UiUtil = preload("res://scenes/ui/UiUtil.gd")
const _InventoryScenePacked := preload("res://scenes/ui/InventoryScene.tscn")

const _TABS: Array[String] = ["deck", "character", "skills", "journal"]
const _TAB_LABELS: Dictionary = {
	"deck":      "Deck / Bag",
	"character": "Character",
	"skills":    "Skills",
	"journal":   "Journal",
}

var _current_tab: String = "deck"
var _content_area: Control
var _tab_buttons: Dictionary = {}  # tab_id -> Button
var _active_page: Node = null

func _ready() -> void:
	super._ready()
	_build_ui()

func _build_ui() -> void:
	_build_backdrop(0.78, false)

	var is_portrait: bool = _vw < _vh
	var panel_w: float = _vw * 0.97 if is_portrait else _vw * 0.92
	var panel_h: float = _vh * 0.94 if is_portrait else _vh * 0.90
	var panel := _build_centered_panel(panel_w, panel_h)
	var style := _make_dark_glass_style()
	panel.add_theme_stylebox_override("panel", style)

	var outer_vbox := VBoxContainer.new()
	outer_vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	outer_vbox.add_theme_constant_override("separation", 0)
	panel.add_child(outer_vbox)

	# ---- Tab bar ----
	var tab_row := HBoxContainer.new()
	tab_row.custom_minimum_size = Vector2(0.0, _ref * 0.072)
	tab_row.add_theme_constant_override("separation", int(_ref * 0.004))
	outer_vbox.add_child(tab_row)

	for tab_id: String in _TABS:
		var btn := Button.new()
		btn.text = _TAB_LABELS[tab_id]
		btn.custom_minimum_size = Vector2(_ref * 0.20, _ref * 0.065)
		btn.add_theme_font_size_override("font_size", int(_ref * 0.022))
		btn.pressed.connect(show_tab.bind(tab_id))
		tab_row.add_child(btn)
		_tab_buttons[tab_id] = btn

	# Spacer pushes close button to the right.
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tab_row.add_child(spacer)

	var close_btn := Button.new()
	close_btn.text = "Close"
	close_btn.custom_minimum_size = Vector2(_ref * 0.15, _ref * 0.065)
	close_btn.add_theme_font_size_override("font_size", int(_ref * 0.022))
	close_btn.pressed.connect(_close)
	tab_row.add_child(close_btn)

	# ---- Content area ----
	var content_wrapper := PanelContainer.new()
	content_wrapper.size_flags_vertical = Control.SIZE_EXPAND_FILL
	outer_vbox.add_child(content_wrapper)
	_content_area = content_wrapper

## Opens the hub on a specific tab. May be called before or after _ready().
func show_tab(tab_id: String) -> void:
	if not tab_id in _TAB_LABELS:
		tab_id = "deck"
	_current_tab = tab_id
	_update_tab_highlights()
	if _content_area != null:
		_load_tab_content(tab_id)

func _load_tab_content(tab_id: String) -> void:
	if _active_page != null and is_instance_valid(_active_page):
		_active_page.queue_free()
		_active_page = null

	for child: Node in _content_area.get_children():
		child.queue_free()

	match tab_id:
		"deck":
			var inv: Node = _InventoryScenePacked.instantiate()
			inv.set("hub_mode", true)
			_content_area.add_child(inv)
			_active_page = inv
		_:
			var lbl := Label.new()
			lbl.text = _TAB_LABELS.get(tab_id, tab_id) + "\n\nFull integration coming soon."
			lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			lbl.set_anchors_preset(Control.PRESET_FULL_RECT)
			lbl.add_theme_font_size_override("font_size", int(_ref * 0.028))
			_content_area.add_child(lbl)
			_active_page = lbl

func _update_tab_highlights() -> void:
	for tab_id: String in _tab_buttons:
		var btn: Button = _tab_buttons[tab_id]
		btn.disabled = (tab_id == _current_tab)

func _close() -> void:
	closed.emit()
	queue_free()
