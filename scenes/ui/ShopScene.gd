extends Control

signal closed

const CardRegistry = preload("res://autoloads/CardRegistry.gd")
const WeaponRegistry = preload("res://autoloads/WeaponRegistry.gd")
const WeaponData = preload("res://data/WeaponData.gd")
const CardInspectOverlay = preload("res://scenes/battle/CardInspectOverlay.gd")
const CardInstance = preload("res://game_logic/battle/CardInstance.gd")
const LongPressDetector = preload("res://scenes/ui/LongPressDetector.gd")

const CARD_PRICE: int = 15

# Traveling merchant mode — set before add_child() via .set() in SceneManager.
var _custom_stock: Array[String] = []   # if non-empty, only show these cards
var _custom_price: int = 0              # 0 = use CARD_PRICE
var _custom_title: String = ""          # "" = use default title

var _vh: float = 0.0
var _vw: float = 0.0
var _coin_label: Label
var _title_lbl: Label
var _shop_list: VBoxContainer
var _inspect_overlay: Control = null

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
	_title_lbl = Label.new()
	_title_lbl.text = _custom_title if _custom_title != "" else "Merchant's Wares"
	_title_lbl.add_theme_font_size_override("font_size", int(_vh * 0.032))
	_title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root_vbox.add_child(_title_lbl)

	# Coin display
	_coin_label = Label.new()
	_coin_label.add_theme_font_size_override("font_size", int(_vh * 0.024))
	_coin_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_coin_label.modulate = Color(1.0, 0.85, 0.1)
	root_vbox.add_child(_coin_label)

	# Scrollable list
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
	close_btn.custom_minimum_size = Vector2(_vw * 0.12, _vh * 0.065)
	close_btn.add_theme_font_size_override("font_size", int(_vh * 0.022))
	close_btn.pressed.connect(_on_close)
	var btn_wrapper := CenterContainer.new()
	btn_wrapper.add_child(close_btn)
	root_vbox.add_child(btn_wrapper)

func _refresh() -> void:
	for child in _shop_list.get_children():
		child.queue_free()

	var coins: int = SceneManager.save_manager.coins
	_coin_label.text = "Your coins: %d" % coins

	# Traveling merchant: show only custom stock at premium price, no weapons.
	if not _custom_stock.is_empty():
		var price: int = _custom_price if _custom_price > 0 else CARD_PRICE
		_shop_list.add_child(_make_section_header("— Rare Wares —"))
		for id: String in _custom_stock:
			var tmpl: Dictionary = CardRegistry.get_template(id)
			if tmpl.is_empty():
				continue
			var row := _make_card_row(id, tmpl, coins, price)
			_shop_list.add_child(row)
		return

	# ---- Cards section ---------------------------------------------------
	_shop_list.add_child(_make_section_header("— Cards —"))

	var unlocked_ach: Array[String] = SceneManager.save_manager.unlocked_achievements
	for id: String in CardRegistry.get_all_ids():
		var tmpl: Dictionary = CardRegistry.get_template(id)
		if tmpl.is_empty():
			continue
		if not CardRegistry.is_unlocked(id, unlocked_ach):
			continue
		var row := _make_card_row(id, tmpl, coins)
		_shop_list.add_child(row)

	# ---- Weapons section -------------------------------------------------
	_shop_list.add_child(_make_section_header("— Weapons —"))

	var owned_w: Array[String] = SceneManager.save_manager.owned_weapons
	var any_weapon := false
	for wid: String in WeaponRegistry.get_all_ids():
		if wid == "rusty_dagger" or owned_w.has(wid):
			continue
		var weapon: WeaponData = WeaponRegistry.get_weapon(wid)
		if weapon == null:
			continue
		var price: int = _weapon_price(weapon)
		var row := _make_weapon_row(wid, weapon, price, coins)
		_shop_list.add_child(row)
		any_weapon = true

	if not any_weapon:
		var none_lbl := Label.new()
		none_lbl.text = "No weapons available."
		none_lbl.add_theme_font_size_override("font_size", int(_vh * 0.022))
		none_lbl.modulate = Color(0.6, 0.6, 0.6)
		none_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_shop_list.add_child(none_lbl)

	# ---- Armor section ---------------------------------------------------
	_shop_list.add_child(_make_section_header("— Armor —"))
	_add_equipment_section("armor", SceneManager.save_manager.owned_armor, coins)

	# ---- Rings section ---------------------------------------------------
	_shop_list.add_child(_make_section_header("— Rings —"))
	_add_equipment_section("ring", SceneManager.save_manager.owned_rings, coins)

	# ---- Trinkets section ------------------------------------------------
	_shop_list.add_child(_make_section_header("— Trinkets —"))
	_add_equipment_section("trinket", SceneManager.save_manager.owned_trinkets, coins)

func _add_equipment_section(slot: String, owned: Array[String], coins: int) -> void:
	var any_item := false
	for eid: String in WeaponRegistry.get_by_slot(slot):
		if owned.has(eid):
			continue
		var weapon: WeaponData = WeaponRegistry.get_weapon(eid)
		if weapon == null:
			continue
		var price: int = _weapon_price(weapon)
		var row := _make_equipment_row(eid, weapon, price, coins)
		_shop_list.add_child(row)
		any_item = true
	if not any_item:
		var none_lbl := Label.new()
		none_lbl.text = "No %s available." % slot
		none_lbl.add_theme_font_size_override("font_size", int(_vh * 0.022))
		none_lbl.modulate = Color(0.6, 0.6, 0.6)
		none_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_shop_list.add_child(none_lbl)

func _make_equipment_row(eid: String, weapon: WeaponData, price: int, coins: int) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", int(_vw * 0.008))

	var info_lbl := Label.new()
	info_lbl.text = "%s  —  %s" % [weapon.display_name, _weapon_effect_summary(weapon)]
	info_lbl.add_theme_font_size_override("font_size", int(_vh * 0.022))
	info_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(info_lbl)

	var price_lbl := Label.new()
	price_lbl.text = "%d coins" % price
	price_lbl.add_theme_font_size_override("font_size", int(_vh * 0.022))
	price_lbl.modulate = Color(1.0, 0.85, 0.1) if coins >= price else Color(0.9, 0.3, 0.3)
	row.add_child(price_lbl)

	var buy_btn := Button.new()
	buy_btn.text = "Buy"
	buy_btn.custom_minimum_size = Vector2(_vw * 0.08, _vh * 0.065)
	buy_btn.add_theme_font_size_override("font_size", int(_vh * 0.022))
	buy_btn.disabled = coins < price
	buy_btn.pressed.connect(_on_buy_equipment.bind(eid, weapon.slot, price))
	row.add_child(buy_btn)

	return row

func _make_section_header(text: String) -> Label:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", int(_vh * 0.022))
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.modulate = Color(0.75, 0.85, 1.0)
	return lbl

func _weapon_price(weapon: WeaponData) -> int:
	match weapon.battle_effect_type:
		"deck_inject":
			return 35 + weapon.injected_card_count * 5
		"starting_mana":
			return weapon.battle_effect_value * 30
		"starting_hp":
			return weapon.battle_effect_value * 5
		"passive_atk":
			return weapon.battle_effect_value * 25
	return 50

func _make_card_row(id: String, tmpl: Dictionary, coins: int,
		price: int = CARD_PRICE) -> HBoxContainer:
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
	info_lbl.add_theme_font_size_override("font_size", int(_vh * 0.022))
	info_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(info_lbl)

	# Price label
	var price_lbl := Label.new()
	price_lbl.text = "%d coins" % price
	price_lbl.add_theme_font_size_override("font_size", int(_vh * 0.022))
	price_lbl.modulate = Color(1.0, 0.85, 0.1) if coins >= price else Color(0.9, 0.3, 0.3)
	row.add_child(price_lbl)

	# Buy button
	var buy_btn := Button.new()
	buy_btn.text = "Buy"
	buy_btn.custom_minimum_size = Vector2(_vw * 0.08, _vh * 0.065)
	buy_btn.add_theme_font_size_override("font_size", int(_vh * 0.022))
	buy_btn.disabled = coins < price
	buy_btn.pressed.connect(_on_buy_card.bind(id, price))
	row.add_child(buy_btn)

	var lpd := LongPressDetector.new()
	row.add_child(lpd)
	lpd.long_pressed.connect(func() -> void: _show_inspect(id))

	return row

func _make_weapon_row(wid: String, weapon: WeaponData, price: int, coins: int) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", int(_vw * 0.008))

	# Name + effect
	var info_lbl := Label.new()
	info_lbl.text = "%s  —  %s" % [weapon.display_name, _weapon_effect_summary(weapon)]
	info_lbl.add_theme_font_size_override("font_size", int(_vh * 0.022))
	info_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(info_lbl)

	# Price label
	var price_lbl := Label.new()
	price_lbl.text = "%d coins" % price
	price_lbl.add_theme_font_size_override("font_size", int(_vh * 0.022))
	price_lbl.modulate = Color(1.0, 0.85, 0.1) if coins >= price else Color(0.9, 0.3, 0.3)
	row.add_child(price_lbl)

	# Buy button
	var buy_btn := Button.new()
	buy_btn.text = "Buy"
	buy_btn.custom_minimum_size = Vector2(_vw * 0.08, _vh * 0.065)
	buy_btn.add_theme_font_size_override("font_size", int(_vh * 0.022))
	buy_btn.disabled = coins < price
	buy_btn.pressed.connect(_on_buy_weapon.bind(wid, price))
	row.add_child(buy_btn)

	return row

func _weapon_effect_summary(weapon: WeaponData) -> String:
	match weapon.battle_effect_type:
		"deck_inject":
			return "Inject %d× %s" % [weapon.injected_card_count, weapon.injected_card_id]
		"starting_mana":
			return "+%d mana" % weapon.battle_effect_value
		"starting_hp":
			return "+%d HP" % weapon.battle_effect_value
		"passive_atk":
			return "+%d ATK" % weapon.battle_effect_value
	return weapon.battle_effect_type

func _on_buy_card(card_id: String, price: int = CARD_PRICE) -> void:
	var sm := SceneManager.save_manager
	if sm.coins < price:
		return
	sm.add_coins(-price)
	var ids: Array[String] = [card_id]
	sm.add_cards_to_deck(ids)
	_refresh()

func _on_buy_weapon(weapon_id: String, price: int) -> void:
	var sm := SceneManager.save_manager
	if sm.coins < price:
		return
	sm.add_coins(-price)
	sm.add_weapon(weapon_id)
	_refresh()

func _on_buy_equipment(item_id: String, slot: String, price: int) -> void:
	var sm := SceneManager.save_manager
	if sm.coins < price:
		return
	sm.add_coins(-price)
	sm.add_equipment(item_id, slot)
	_refresh()

func _show_inspect(card_id: String) -> void:
	if _inspect_overlay != null and is_instance_valid(_inspect_overlay):
		return
	var tmpl: Dictionary = CardRegistry.get_template(card_id)
	if tmpl.is_empty():
		return
	var card: CardInstance = CardInstance.new(tmpl)
	var overlay := CardInspectOverlay.new()
	add_child(overlay)
	move_child(overlay, get_child_count() - 1)
	overlay.show_card(card)
	overlay.closed.connect(func() -> void: _inspect_overlay = null)
	_inspect_overlay = overlay

func _on_close() -> void:
	closed.emit()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_on_close()
		get_viewport().set_input_as_handled()
