extends Control

signal closed

const _CardRegistry = preload("res://autoloads/CardRegistry.gd")

# Set before add_child() via SceneManager.
var _rolled_cards: Array[Dictionary] = []

var _vh: float = 0.0
var _vw: float = 0.0
var _ref: float = 0.0

# Per-slot state.
var _flipped: Array[bool] = []
var _card_wrappers: Array[Control] = []
var _visual_nodes: Array[Control] = []
var _card_backs: Array[ColorRect] = []
var _card_face_bgs: Array[ColorRect] = []
var _card_face_contents: Array[VBoxContainer] = []
var _tap_buttons: Array[Button] = []

var _reveal_all_btn: Button
var _done_btn: Button
var _all_revealed: bool = false

func _ready() -> void:
	mouse_filter = MOUSE_FILTER_STOP
	_vh = get_viewport().get_visible_rect().size.y
	_vw = get_viewport().get_visible_rect().size.x
	_ref = minf(_vh, _vw)

	for _i in range(_rolled_cards.size()):
		_flipped.append(false)

	_build_ui()

func _build_ui() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.0, 0.0, 0.0, 0.78)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var root := VBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.alignment = BoxContainer.ALIGNMENT_CENTER
	root.add_theme_constant_override("separation", int(_ref * 0.025))
	add_child(root)

	var title := Label.new()
	title.text = "Pack Opening"
	title.add_theme_font_size_override("font_size", int(_ref * 0.04))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(title)

	var sub := Label.new()
	sub.text = "Tap each card to reveal"
	sub.add_theme_font_size_override("font_size", int(_ref * 0.022))
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.modulate = Color(0.7, 0.7, 0.7)
	root.add_child(sub)

	var cards_row := HBoxContainer.new()
	cards_row.alignment = BoxContainer.ALIGNMENT_CENTER
	cards_row.add_theme_constant_override("separation", int(_vw * 0.03))
	root.add_child(cards_row)

	var card_h: float = _ref * 0.30
	var card_w: float = card_h * 0.65

	for i: int in range(_rolled_cards.size()):
		var slot := _make_card_slot(i, card_w, card_h)
		cards_row.add_child(slot)

	var btn_row := HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_row.add_theme_constant_override("separation", int(_vw * 0.03))
	root.add_child(btn_row)

	_reveal_all_btn = Button.new()
	_reveal_all_btn.text = "Reveal All"
	_reveal_all_btn.custom_minimum_size = Vector2(_vw * 0.18, _ref * 0.065)
	_reveal_all_btn.add_theme_font_size_override("font_size", int(_ref * 0.022))
	_reveal_all_btn.pressed.connect(_on_reveal_all)
	btn_row.add_child(_reveal_all_btn)

	_done_btn = Button.new()
	_done_btn.text = "Done"
	_done_btn.custom_minimum_size = Vector2(_vw * 0.18, _ref * 0.065)
	_done_btn.add_theme_font_size_override("font_size", int(_ref * 0.022))
	_done_btn.pressed.connect(_on_done)
	_done_btn.visible = false
	btn_row.add_child(_done_btn)

func _make_card_slot(idx: int, card_w: float, card_h: float) -> Control:
	var wrapper := Control.new()
	wrapper.custom_minimum_size = Vector2(card_w, card_h)

	# Inner visual node is scaled during the flip animation.
	var visual := Control.new()
	visual.set_anchors_preset(Control.PRESET_FULL_RECT)
	visual.pivot_offset = Vector2(card_w * 0.5, card_h * 0.5)
	wrapper.add_child(visual)

	# Card back.
	var back := ColorRect.new()
	back.color = Color(0.22, 0.22, 0.35)
	back.set_anchors_preset(Control.PRESET_FULL_RECT)
	visual.add_child(back)

	var back_lbl := Label.new()
	back_lbl.text = "?"
	back_lbl.add_theme_font_size_override("font_size", int(card_h * 0.28))
	back_lbl.set_anchors_preset(Control.PRESET_FULL_RECT)
	back_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	back_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	back.add_child(back_lbl)

	# Card face background (rarity colour, hidden until reveal).
	var face_bg := ColorRect.new()
	face_bg.color = Color(0.12, 0.12, 0.20)
	face_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	face_bg.visible = false
	visual.add_child(face_bg)

	# Card face content (labels, hidden until reveal).
	var face_content := VBoxContainer.new()
	face_content.set_anchors_preset(Control.PRESET_FULL_RECT)
	face_content.alignment = BoxContainer.ALIGNMENT_CENTER
	face_content.add_theme_constant_override("separation", int(card_h * 0.04))
	face_content.visible = false
	visual.add_child(face_content)

	# Invisible tap button on top of wrapper (not visual, so it doesn't scale).
	var tap_btn := Button.new()
	tap_btn.flat = true
	tap_btn.set_anchors_preset(Control.PRESET_FULL_RECT)
	tap_btn.pressed.connect(_on_card_tapped.bind(idx))
	wrapper.add_child(tap_btn)

	_card_wrappers.append(wrapper)
	_visual_nodes.append(visual)
	_card_backs.append(back)
	_card_face_bgs.append(face_bg)
	_card_face_contents.append(face_content)
	_tap_buttons.append(tap_btn)

	return wrapper

func _on_card_tapped(idx: int) -> void:
	if _flipped[idx]:
		return
	_flip_card(idx)

func _flip_card(idx: int) -> void:
	_flipped[idx] = true
	_tap_buttons[idx].disabled = true

	var visual: Control = _visual_nodes[idx]
	var tween := create_tween()
	tween.tween_property(visual, "scale:x", 0.0, 0.15)
	tween.tween_callback(func() -> void:
		_card_backs[idx].visible = false
		_populate_face(idx)
		_card_face_bgs[idx].visible = true
		_card_face_contents[idx].visible = true
	)
	tween.tween_property(visual, "scale:x", 1.0, 0.15)
	tween.tween_callback(func() -> void:
		_check_all_revealed()
	)

func _populate_face(idx: int) -> void:
	var card_data: Dictionary = _rolled_cards[idx]
	var rarity: String = str(card_data.get("rarity", "common"))
	var template_id: String = str(card_data.get("template_id", "ghost"))
	var atk: int = int(card_data.get("attack", 0))
	var hp: int = int(card_data.get("health", 0))
	var cost: int = int(card_data.get("cost", 1))

	var tmpl: Dictionary = _CardRegistry.get_template(template_id)
	var card_name: String = str(tmpl.get("name", template_id))

	# Add card to the player's collection.
	SceneManager.save_manager.grant_card_reward(template_id, rarity, atk, hp, cost)

	# Reset pity counter if a legendary was obtained.
	if rarity == "legendary":
		SceneManager.save_manager.reset_pity()

	# Set face background to a darkened version of the rarity colour.
	var rc: Color = _rarity_color(rarity)
	_card_face_bgs[idx].color = rc.darkened(0.75)

	var face: VBoxContainer = _card_face_contents[idx]

	var rarity_lbl := Label.new()
	rarity_lbl.text = rarity.to_upper()
	rarity_lbl.add_theme_font_size_override("font_size", int(_ref * 0.018))
	rarity_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rarity_lbl.modulate = rc
	face.add_child(rarity_lbl)

	var name_lbl := Label.new()
	name_lbl.text = card_name
	name_lbl.add_theme_font_size_override("font_size", int(_ref * 0.022))
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	face.add_child(name_lbl)

	var cost_lbl := Label.new()
	cost_lbl.text = "Cost: %d" % cost
	cost_lbl.add_theme_font_size_override("font_size", int(_ref * 0.018))
	cost_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	face.add_child(cost_lbl)

	var stats_lbl := Label.new()
	stats_lbl.text = "%d / %d" % [atk, hp]
	stats_lbl.add_theme_font_size_override("font_size", int(_ref * 0.025))
	stats_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	face.add_child(stats_lbl)

func _rarity_color(rarity: String) -> Color:
	match rarity:
		"common":    return Color(0.80, 0.80, 0.80)
		"rare":      return Color(0.20, 0.50, 1.00)
		"epic":      return Color(0.70, 0.20, 1.00)
		"legendary": return Color(1.00, 0.75, 0.00)
	return Color(0.80, 0.80, 0.80)

func _check_all_revealed() -> void:
	for f: bool in _flipped:
		if not f:
			return
	_all_revealed = true
	_reveal_all_btn.visible = false
	_done_btn.visible = true

func _on_reveal_all() -> void:
	for i: int in range(_rolled_cards.size()):
		if _flipped[i]:
			continue
		_flipped[i] = true
		_tap_buttons[i].disabled = true
		# Instant reveal without animation.
		_card_backs[i].visible = false
		_populate_face(i)
		_card_face_bgs[i].visible = true
		_card_face_contents[i].visible = true
		_visual_nodes[i].scale = Vector2.ONE
	_reveal_all_btn.visible = false
	_done_btn.visible = true
	_all_revealed = true

func _on_done() -> void:
	closed.emit()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		if _all_revealed:
			_on_done()
		get_viewport().set_input_as_handled()
