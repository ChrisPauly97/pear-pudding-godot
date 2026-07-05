extends "res://scenes/ui/BaseOverlay.gd"

## Mailbox overlay (TID-413) — lists SaveManager.mailbox_cards (overflow rewards
## that couldn't fit in the bag) with Claim / Claim All / Sell / Scrap actions.
## Tile + detail-popup pattern duplicated from InventoryScene.gd (see TID-413
## research notes) since the two scenes' action sets diverge (Claim vs.
## Add-to-deck/Combine/Rename).

const CardRegistry  = preload("res://autoloads/CardRegistry.gd")
const _UiUtil       = preload("res://scenes/ui/UiUtil.gd")

var _grid_scroll: ScrollContainer
var _grid: GridContainer
var _count_label: Label
var _claim_all_btn: Button
var _detail_popup: PopupPanel = null

func _ready() -> void:
	super._ready()
	_build_ui()
	_refresh()

func _build_ui() -> void:
	_build_backdrop(0.78, true)
	var is_portrait: bool = _vw < _vh
	var panel_w: float = _vw * 0.92 if is_portrait else _vw * 0.62
	var panel_h: float = _vh * 0.85 if is_portrait else _vh * 0.78
	var outer := _build_centered_panel(panel_w, panel_h)
	outer.add_theme_stylebox_override("panel", _make_dark_glass_style())
	var wrapper := _build_margin_vbox(outer, 0.015, 0.010)

	var header := HBoxContainer.new()
	wrapper.add_child(header)

	var title_lbl := Label.new()
	title_lbl.text = "Mailbox"
	title_lbl.add_theme_font_size_override("font_size", int(_ref * 0.03))
	title_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title_lbl)

	var close_btn := Button.new()
	close_btn.text = "Close  [C]" if not OS.has_feature("android") else "Close"
	close_btn.custom_minimum_size = Vector2(_ref * 0.14, _ref * 0.065)
	close_btn.add_theme_font_size_override("font_size", int(_ref * 0.022))
	close_btn.pressed.connect(_close)
	header.add_child(close_btn)

	_count_label = Label.new()
	_count_label.add_theme_font_size_override("font_size", int(_ref * 0.020))
	_count_label.modulate = Color(0.8, 0.8, 0.8)
	wrapper.add_child(_count_label)

	_claim_all_btn = Button.new()
	_claim_all_btn.text = "Claim All"
	_claim_all_btn.custom_minimum_size = Vector2(_ref * 0.18, _ref * 0.06)
	_claim_all_btn.add_theme_font_size_override("font_size", int(_ref * 0.020))
	_claim_all_btn.pressed.connect(_on_claim_all)
	wrapper.add_child(_claim_all_btn)

	_grid_scroll = ScrollContainer.new()
	_grid_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	wrapper.add_child(_grid_scroll)
	attach_drag_scroll(_grid_scroll)

	_grid = GridContainer.new()
	_grid.add_theme_constant_override("h_separation", int(_ref * 0.010))
	_grid.add_theme_constant_override("v_separation", int(_ref * 0.010))
	_grid_scroll.add_child(_grid)

func _refresh() -> void:
	_hide_detail()
	for child in _grid.get_children():
		child.queue_free()
	var sm := SceneManager.save_manager
	var instances: Array[Dictionary] = sm.get_mailbox_instances()
	_count_label.text = "%d card%s waiting" % [instances.size(), "" if instances.size() == 1 else "s"]
	_claim_all_btn.disabled = instances.is_empty()

	if instances.is_empty():
		var empty_lbl := Label.new()
		empty_lbl.text = "Mailbox is empty"
		empty_lbl.add_theme_font_size_override("font_size", int(_ref * 0.022))
		empty_lbl.modulate = Color(0.6, 0.6, 0.6)
		empty_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_grid.add_child(empty_lbl)
		return

	var sorted: Array[Dictionary] = instances.duplicate()
	sorted.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var ta: String = str(a.get("template_id", ""))
		var tb: String = str(b.get("template_id", ""))
		if ta != tb:
			return ta < tb
		var ra: int = IsoConst.RARITY_ORDER.find(str(a.get("rarity", "common")))
		var rb: int = IsoConst.RARITY_ORDER.find(str(b.get("rarity", "common")))
		return ra > rb
	)

	var tile_size: float = _ref * 0.11
	var cols: int = maxi(1, int(_grid_scroll.size.x / (tile_size + _ref * 0.01)))
	_grid.columns = cols if cols > 1 else 4
	for inst: Dictionary in sorted:
		_grid.add_child(_make_card_tile(inst))

func _make_card_tile(inst: Dictionary) -> Control:
	var uid: String    = str(inst.get("uid", ""))
	var tid: String    = str(inst.get("template_id", ""))
	var rarity: String = str(inst.get("rarity", "common"))
	var face: String = "dark" if CardRegistry.is_dark_aligned() else "light"
	var tmpl: Dictionary  = CardRegistry.get_template_for_face(tid, face)
	var card_color: Color = tmpl.get("color", Color(0.3, 0.3, 0.35))

	var tile_size: float = _ref * 0.11
	var cube := Button.new()
	cube.custom_minimum_size = Vector2(tile_size, tile_size)
	cube.focus_mode = Control.FOCUS_NONE

	var sb := StyleBoxFlat.new()
	sb.bg_color = card_color
	sb.border_color = _UiUtil.rarity_color(rarity)
	sb.set_border_width_all(maxi(2, int(_ref * 0.006)))
	sb.set_corner_radius_all(int(_ref * 0.012))
	cube.add_theme_stylebox_override("normal", sb)
	cube.add_theme_stylebox_override("hover", sb)
	cube.add_theme_stylebox_override("pressed", sb)
	cube.add_theme_stylebox_override("focus", sb)

	var badge_lbl := Label.new()
	badge_lbl.text = _UiUtil.rarity_badge(rarity)
	badge_lbl.add_theme_font_size_override("font_size", int(_ref * 0.016))
	badge_lbl.modulate = _UiUtil.rarity_color(rarity)
	badge_lbl.set_anchors_preset(Control.PRESET_TOP_LEFT)
	badge_lbl.position = Vector2(_ref * 0.006, _ref * 0.004)
	cube.add_child(badge_lbl)

	cube.pressed.connect(func() -> void: _show_instance_detail(inst, cube))
	return cube

func _hide_detail() -> void:
	if _detail_popup != null and is_instance_valid(_detail_popup):
		_detail_popup.queue_free()
	_detail_popup = null

func _show_instance_detail(inst: Dictionary, anchor: Control) -> void:
	_hide_detail()

	var uid: String    = str(inst.get("uid", ""))
	var tid: String    = str(inst.get("template_id", ""))
	var rarity: String = str(inst.get("rarity", "common"))
	var face: String = "dark" if CardRegistry.is_dark_aligned() else "light"
	var tmpl: Dictionary  = CardRegistry.get_template_for_face(tid, face)
	var card_name: String = tmpl.get("name", tid)

	var rolled_atk: int  = int(inst.get("attack", int(tmpl.get("attack", 0))))
	var rolled_hp: int   = int(inst.get("health", int(tmpl.get("health", 0))))
	var rolled_cost: int = int(inst.get("cost",   int(tmpl.get("cost",   0))))

	var popup := PopupPanel.new()
	add_child(popup)
	_detail_popup = popup

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", int(_ref * 0.008))
	vb.custom_minimum_size = Vector2(_ref * 0.32, 0)
	popup.add_child(vb)

	var title_row := HBoxContainer.new()
	title_row.add_theme_constant_override("separation", int(_ref * 0.006))
	vb.add_child(title_row)

	var name_lbl := Label.new()
	name_lbl.text = card_name
	name_lbl.add_theme_font_size_override("font_size", int(_ref * 0.024))
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_row.add_child(name_lbl)

	var badge_lbl := Label.new()
	badge_lbl.text = _UiUtil.rarity_badge(rarity)
	badge_lbl.add_theme_font_size_override("font_size", int(_ref * 0.022))
	badge_lbl.modulate = _UiUtil.rarity_color(rarity)
	title_row.add_child(badge_lbl)

	var stats_lbl := Label.new()
	stats_lbl.text = "Cost %d  ATK %d  HP %d" % [rolled_cost, rolled_atk, rolled_hp]
	stats_lbl.add_theme_font_size_override("font_size", int(_ref * 0.022))
	stats_lbl.modulate = _UiUtil.rarity_color(rarity).lerp(Color(0.85, 0.85, 0.85), 0.55)
	vb.add_child(stats_lbl)

	var cfg: Dictionary = IsoConst.RARITY_CONFIG.get(rarity, {})
	var sell_gold: int  = int(cfg.get("sell_gold", 0))
	var scrap_ess: int  = int(cfg.get("scrap_essence", 0))

	var action_row := HBoxContainer.new()
	action_row.add_theme_constant_override("separation", int(_ref * 0.006))
	vb.add_child(action_row)

	var claim_btn := Button.new()
	claim_btn.text = "Claim"
	claim_btn.custom_minimum_size = Vector2(_ref * 0.12, _ref * 0.06)
	claim_btn.add_theme_font_size_override("font_size", int(_ref * 0.020))
	claim_btn.modulate = Color(0.5, 1.0, 0.5)
	claim_btn.pressed.connect(func() -> void:
		if SceneManager.save_manager.is_bag_full():
			GameBus.hud_message_requested.emit("Bag is full — sell or scrap cards to make room.")
			return
		SceneManager.save_manager.claim_mailbox_card(uid)
		_hide_detail()
		_refresh())
	action_row.add_child(claim_btn)

	var sell_btn := Button.new()
	sell_btn.text = "Sell +%dg" % sell_gold
	sell_btn.custom_minimum_size = Vector2(_ref * 0.14, _ref * 0.06)
	sell_btn.add_theme_font_size_override("font_size", int(_ref * 0.020))
	sell_btn.modulate = Color(1.0, 0.9, 0.3)
	sell_btn.pressed.connect(func() -> void:
		SceneManager.save_manager.sell_mailbox_card(uid)
		_hide_detail()
		_refresh())
	action_row.add_child(sell_btn)

	var scrap_btn := Button.new()
	scrap_btn.text = "Scrap +%de" % scrap_ess
	scrap_btn.custom_minimum_size = Vector2(_ref * 0.14, _ref * 0.06)
	scrap_btn.add_theme_font_size_override("font_size", int(_ref * 0.020))
	scrap_btn.modulate = Color(0.5, 0.85, 1.0)
	scrap_btn.pressed.connect(func() -> void:
		SceneManager.save_manager.scrap_mailbox_card(uid)
		_hide_detail()
		_refresh())
	action_row.add_child(scrap_btn)

	popup.popup(Rect2i(anchor.get_screen_transform().origin as Vector2i, Vector2i(int(_ref * 0.32), 0)))

func _on_claim_all() -> void:
	var claimed: int = SceneManager.save_manager.claim_all_mailbox_cards()
	if claimed == 0 and not SceneManager.save_manager.get_mailbox_instances().is_empty():
		GameBus.hud_message_requested.emit("Bag is full — sell or scrap cards to make room.")
	_refresh()
