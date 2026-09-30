extends Control

signal closed

const _UiUtil = preload("res://scenes/ui/UiUtil.gd")

const _CardRegistry = preload("res://autoloads/CardRegistry.gd")
const _CardFace = preload("res://scenes/ui/CardFace.gd")

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
var _card_face_bgs: Array[Panel] = []
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

	var title := _UiUtil.make_label("Pack Opening", int(_ref * 0.04), Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, root)

	var sub := _UiUtil.make_label("Tap each card to reveal", int(_ref * 0.022), Color(0.7, 0.7, 0.7),
			HORIZONTAL_ALIGNMENT_CENTER, root)

	var cards_row := _UiUtil.make_hbox(int(_vw * 0.03), root)
	cards_row.alignment = BoxContainer.ALIGNMENT_CENTER

	var card_h: float = _ref * 0.30
	var card_w: float = card_h * 0.65

	for i: int in range(_rolled_cards.size()):
		var slot := _make_card_slot(i, card_w, card_h)
		cards_row.add_child(slot)

	var btn_row := _UiUtil.make_hbox(int(_vw * 0.03), root)
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER

	_reveal_all_btn = _UiUtil.make_button("Reveal All", Vector2(_vw * 0.18, _ref * 0.065), int(_ref * 0.022),
			_on_reveal_all, btn_row)

	_done_btn = _UiUtil.make_button("Done", Vector2(_vw * 0.18, _ref * 0.065), int(_ref * 0.022), _on_done, btn_row)
	_done_btn.visible = false

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

	var back_lbl := _UiUtil.make_label("?", int(card_h * 0.28))
	back_lbl.set_anchors_preset(Control.PRESET_FULL_RECT)
	back_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	back_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	back.add_child(back_lbl)

	# Card face frame (magic-type frame, set on reveal; hidden until then).
	var face_bg := Panel.new()
	face_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	face_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	face_bg.visible = false
	visual.add_child(face_bg)

	# Card face content (labels, hidden until reveal).
	var face_content := VBoxContainer.new()
	face_content.set_anchors_preset(Control.PRESET_FULL_RECT)
	var inset: float = _CardFace.frame_style("", card_h).content_margin_left
	face_content.offset_left = inset
	face_content.offset_top = inset
	face_content.offset_right = -inset
	face_content.offset_bottom = -inset
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

	var rc: Color = _UiUtil.rarity_color(rarity)
	var card_h: float = _ref * 0.30
	_card_face_bgs[idx].add_theme_stylebox_override("panel",
			_CardFace.frame_style(str(tmpl.get("magic_type", "")), card_h))

	var face: VBoxContainer = _card_face_contents[idx]

	_UiUtil.make_label(rarity.to_upper(), int(_ref * 0.018), rc, HORIZONTAL_ALIGNMENT_CENTER, face)

	var illus: Texture2D = tmpl.get("illustration") as Texture2D
	if illus != null:
		var art := _CardFace.make_art(illus, card_h * 0.38)
		_CardFace.set_art_background(art, str(tmpl.get("magic_branch", "")), card_h)
		face.add_child(art)

	var name_lbl := _UiUtil.make_label(card_name, int(_ref * 0.022), Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, face)
	name_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	var stats := _UiUtil.make_hbox(int(_ref * 0.01), face)
	stats.alignment = BoxContainer.ALIGNMENT_CENTER
	var d: float = card_h * 0.17
	var fs: int = int(_ref * 0.02)
	stats.add_child(_CardFace.make_badge("cost", str(cost), d, fs))
	if str(tmpl.get("card_class", "minion")) != "spell":
		stats.add_child(_CardFace.make_badge("atk", str(atk), d, fs))
		stats.add_child(_CardFace.make_badge("hp", str(hp), d, fs))

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
