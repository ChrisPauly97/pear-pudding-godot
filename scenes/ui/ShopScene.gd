extends Control

signal closed

const CardRegistry = preload("res://autoloads/CardRegistry.gd")

const CARD_PRICE: int = 15

var _vh: float = 0.0
var _vw: float = 0.0
var _coin_label: Label
var _shop_list: VBoxContainer

func _ready() -> void:
	mouse_filter = MOUSE_FILTER_STOP
	_vh = get_viewport().get_visible_rect().size.y
	_vw = get_viewport().get_visible_rect().size.x
	_build_ui()
	_refresh()

func _build_ui() -> void:
	# Dark backdrop
	var bg := ColorRect.new()
	bg.color = Color(0.0, 0.0, 0.0, 0.78)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	# Centred panel — portrait-aware width so it doesn't overflow narrow screens.
	# Both custom_minimum_size AND size must be set: PanelContainer expands to fit
	# children unless size is pinned explicitly, which would collapse the inner
	# ScrollContainer (SIZE_EXPAND_FILL has no finite height to expand into).
	var outer := PanelContainer.new()
	var panel_w: float = minf(_vw * 0.90, _vh * 0.70)
	var panel_h: float = _vh * 0.82
	outer.custom_minimum_size = Vector2(panel_w, panel_h)
	outer.size = Vector2(panel_w, panel_h)
	outer.position = Vector2((_vw - panel_w) * 0.5, (_vh - panel_h) * 0.5)
	add_child(outer)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left",   int(_vw * 0.015))
	margin.add_theme_constant_override("margin_right",  int(_vw * 0.015))
	margin.add_theme_constant_override("margin_top",    int(_vh * 0.015))
	margin.add_theme_constant_override("margin_bottom", int(_vh * 0.015))
	outer.add_child(margin)

	var root_vbox := VBoxContainer.new()
	root_vbox.add_theme_constant_override("separation", int(_vh * 0.012))
	margin.add_child(root_vbox)

	# Title
	var title := Label.new()
	title.text = "Merchant's Wares"
	title.add_theme_font_size_override("font_size", int(_vh * 0.032))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root_vbox.add_child(title)

	# Coin display
	_coin_label = Label.new()
	_coin_label.add_theme_font_size_override("font_size", int(_vh * 0.024))
	_coin_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_coin_label.modulate = Color(1.0, 0.85, 0.1)
	root_vbox.add_child(_coin_label)

	# Scrollable card list — minimum height prevents collapse if layout resolution
	# fails to distribute the panel's height to SIZE_EXPAND_FILL children.
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size = Vector2(0.0, _vh * 0.30)
	root_vbox.add_child(scroll)

	_shop_list = VBoxContainer.new()
	_shop_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_shop_list.add_theme_constant_override("separation", int(_vh * 0.008))
	scroll.add_child(_shop_list)

	# Close button
	var close_btn := Button.new()
	close_btn.text = "Leave Shop"
	close_btn.custom_minimum_size = Vector2(_vw * 0.12, _vh * 0.055)
	close_btn.add_theme_font_size_override("font_size", int(_vh * 0.02))
	close_btn.pressed.connect(_on_close)
	var btn_wrapper := CenterContainer.new()
	btn_wrapper.add_child(close_btn)
	root_vbox.add_child(btn_wrapper)

func _refresh() -> void:
	for child in _shop_list.get_children():
		child.queue_free()

	var coins: int = SceneManager.save_manager.coins
	_coin_label.text = "Your coins: %d" % coins

	for id: String in CardRegistry.get_all_ids():
		var tmpl: Dictionary = CardRegistry.get_template(id)
		if tmpl.is_empty():
			continue
		var row := _make_row(id, tmpl, coins)
		_shop_list.add_child(row)

func _make_row(id: String, tmpl: Dictionary, coins: int) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", int(_vw * 0.008))

	# Colour swatch
	var swatch := ColorRect.new()
	var card_color: Color = tmpl.get("color", Color(0.3, 0.3, 0.35))
	swatch.color = card_color
	swatch.custom_minimum_size = Vector2(_vh * 0.03, _vh * 0.03)
	row.add_child(swatch)

	# Card name + stats
	var name_str: String = tmpl.get("name", id)
	var cost: int = tmpl.get("cost", 0)
	var atk: int  = tmpl.get("attack", 0)
	var hp: int   = tmpl.get("health", 0)
	var info_lbl := Label.new()
	info_lbl.text = "%s   cost %d  %d/%d" % [name_str, cost, atk, hp]
	info_lbl.add_theme_font_size_override("font_size", int(_vh * 0.019))
	info_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(info_lbl)

	# Price label
	var price_lbl := Label.new()
	price_lbl.text = "%d coins" % CARD_PRICE
	price_lbl.add_theme_font_size_override("font_size", int(_vh * 0.019))
	price_lbl.modulate = Color(1.0, 0.85, 0.1)
	row.add_child(price_lbl)

	# Buy button
	var buy_btn := Button.new()
	buy_btn.text = "Buy"
	buy_btn.custom_minimum_size = Vector2(_vw * 0.08, _vh * 0.05)
	buy_btn.add_theme_font_size_override("font_size", int(_vh * 0.019))
	buy_btn.disabled = coins < CARD_PRICE
	buy_btn.pressed.connect(_on_buy.bind(id, buy_btn))
	row.add_child(buy_btn)

	return row

func _on_buy(card_id: String, btn: Button) -> void:
	var sm := SceneManager.save_manager
	if sm.coins < CARD_PRICE:
		return
	sm.add_coins(-CARD_PRICE)
	var ids: Array[String] = [card_id]
	sm.add_cards_to_deck(ids)
	_refresh()

func _on_close() -> void:
	closed.emit()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_on_close()
		get_viewport().set_input_as_handled()
