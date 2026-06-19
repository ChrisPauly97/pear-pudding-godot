extends "res://scenes/ui/BaseOverlay.gd"

const CardRegistry = preload("res://autoloads/CardRegistry.gd")
const WeaponRegistry = preload("res://autoloads/WeaponRegistry.gd")
const PackDefs = preload("res://game_logic/PackDefs.gd")
const GardenDefs = preload("res://game_logic/GardenDefs.gd")
const WeaponData = preload("res://data/WeaponData.gd")
const CardInspectOverlay = preload("res://scenes/battle/CardInspectOverlay.gd")
const CardInstance = preload("res://game_logic/battle/CardInstance.gd")
const LongPressDetector = preload("res://scenes/ui/LongPressDetector.gd")
const _UiUtil = preload("res://scenes/ui/UiUtil.gd")

const CARD_PRICE: int = 15
const SEED_PRICE: int = 30

# Traveling merchant mode — set before add_child() via .set() in SceneManager.
var _custom_stock: Array[String] = []   # if non-empty, only show these cards
var _custom_price: int = 0              # 0 = use CARD_PRICE
var _custom_title: String = ""          # "" = use default title

# Town gratitude discount: set by SceneManager from current_map before add_child().
var town_name: String = ""

var _coin_label: Label
var _title_lbl: Label
var _shop_list: VBoxContainer
var _shop_scroll: ScrollContainer
var _inspect_overlay: Control = null

func _ready() -> void:
	super._ready()
	_build_ui()
	_refresh()

func _build_ui() -> void:
	_build_backdrop(0.78)
	var panel_w: float = minf(_vw * 0.90, _vh * 0.70)
	var panel_h: float = _vh * 0.82
	var outer := _build_centered_panel(panel_w, panel_h)
	var root_vbox := _build_margin_vbox(outer, 0.015, 0.012)

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
	_shop_scroll = ScrollContainer.new()
	var scroll: ScrollContainer = _shop_scroll
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
	var saved_scroll: int = _shop_scroll.scroll_vertical if _shop_scroll else 0
	for child in _shop_list.get_children():
		child.queue_free()

	var coins: int = SceneManager.save_manager.coins
	_coin_label.text = "Your coins: %d" % coins

	var discounted: bool = town_name != "" and SceneManager.save_manager.is_town_discounted(town_name)

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

	# ---- Packs section ---------------------------------------------------
	_shop_list.add_child(_make_section_header("— Packs —"))
	for pack_id: String in PackDefs.get_all_pack_ids():
		var pack_def: Dictionary = PackDefs.get_pack(pack_id)
		if pack_def.is_empty():
			continue
		_shop_list.add_child(_make_pack_row(pack_id, pack_def, coins))

	# ---- Cards section ---------------------------------------------------
	var card_header: String = "— Cards (20% off — Town Discount) —" if discounted else "— Cards —"
	_shop_list.add_child(_make_section_header(card_header))

	var effective_card_price: int = int(CARD_PRICE * 0.8) if discounted else CARD_PRICE
	var unlocked_ach: Array[String] = SceneManager.save_manager.unlocked_achievements
	for id: String in CardRegistry.get_all_ids():
		var tmpl: Dictionary = CardRegistry.get_template(id)
		if tmpl.is_empty():
			continue
		if not CardRegistry.is_unlocked(id, unlocked_ach):
			continue
		var row := _make_card_row(id, tmpl, coins, effective_card_price)
		_shop_list.add_child(row)

	# ---- Weapons section -------------------------------------------------
	var weapon_header: String = "— Weapons (20% off) —" if discounted else "— Weapons —"
	_shop_list.add_child(_make_section_header(weapon_header))

	var owned_w: Array[String] = SceneManager.save_manager.get_owned_by_slot("weapon")
	var any_weapon := false
	for wid: String in WeaponRegistry.get_all_ids():
		if wid == "rusty_dagger" or owned_w.has(wid):
			continue
		var weapon: WeaponData = WeaponRegistry.get_weapon(wid)
		if weapon == null:
			continue
		var price: int = _weapon_price(weapon)
		if discounted:
			price = int(price * 0.8)
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
	_add_equipment_section("armor", SceneManager.save_manager.owned_armor, coins, discounted)

	# ---- Rings section ---------------------------------------------------
	_shop_list.add_child(_make_section_header("— Rings —"))
	_add_equipment_section("ring", SceneManager.save_manager.owned_rings, coins, discounted)

	# ---- Trinkets section ------------------------------------------------
	_shop_list.add_child(_make_section_header("— Trinkets —"))
	_add_equipment_section("trinket", SceneManager.save_manager.owned_trinkets, coins, discounted)

	# ---- Seeds section ---------------------------------------------------
	_shop_list.add_child(_make_section_header("— Seeds —"))
	for seed_id: String in GardenDefs.SEEDS:
		var seed_data: Dictionary = GardenDefs.SEEDS[seed_id]
		var row := _make_seed_row(seed_id, seed_data, coins)
		_shop_list.add_child(row)

	if _shop_scroll and saved_scroll > 0:
		_shop_scroll.scroll_vertical = saved_scroll

func _add_equipment_section(slot: String, owned: Array[String], coins: int, discounted: bool = false) -> void:
	var any_item := false
	for eid: String in WeaponRegistry.get_by_slot(slot):
		if owned.has(eid):
			continue
		var weapon: WeaponData = WeaponRegistry.get_weapon(eid)
		if weapon == null:
			continue
		var price: int = _weapon_price(weapon)
		if discounted:
			price = int(price * 0.8)
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
	info_lbl.text = "%s  —  %s" % [weapon.display_name, _UiUtil.effect_summary(weapon.battle_effect_type, weapon.battle_effect_value, weapon.injected_card_count, weapon.injected_card_id)]
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

	# Owned count
	var owned_count: int = 0
	for inst: Dictionary in SceneManager.save_manager.owned_cards:
		if str(inst.get("template_id", "")) == id:
			owned_count += 1
	var own_lbl := Label.new()
	own_lbl.text = "own: %d" % owned_count
	own_lbl.add_theme_font_size_override("font_size", int(_vh * 0.020))
	own_lbl.modulate = Color(0.65, 0.65, 0.65)
	row.add_child(own_lbl)

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
	info_lbl.text = "%s  —  %s" % [weapon.display_name, _UiUtil.effect_summary(weapon.battle_effect_type, weapon.battle_effect_value, weapon.injected_card_count, weapon.injected_card_id)]
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

func _make_pack_row(pack_id: String, pack_def: Dictionary, coins: int) -> VBoxContainer:
	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", int(_vh * 0.004))

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", int(_vw * 0.008))

	var pack_name: String = str(pack_def.get("name", pack_id))
	var price: int = int(pack_def.get("price", 0))

	var info_lbl := Label.new()
	info_lbl.text = "%s  — 3 cards" % pack_name
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
	buy_btn.pressed.connect(_on_buy_pack.bind(pack_id, price))
	row.add_child(buy_btn)

	outer.add_child(row)

	# Pity hint below the row.
	var pity: int = SceneManager.save_manager.packs_since_legendary
	if pity > 0:
		var remaining: int = PackDefs.PITY_THRESHOLD - pity
		var pity_lbl := Label.new()
		if remaining > 0:
			pity_lbl.text = "Legendary guaranteed in %d more packs" % remaining
		else:
			pity_lbl.text = "Pity active — next pack guaranteed legendary!"
		pity_lbl.add_theme_font_size_override("font_size", int(_vh * 0.018))
		pity_lbl.modulate = Color(0.7, 0.7, 0.7)
		pity_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		outer.add_child(pity_lbl)

	return outer

func _on_buy_pack(pack_id: String, price: int) -> void:
	var sm := SceneManager.save_manager
	if sm.coins < price:
		return
	sm.add_coins(-price)
	sm.increment_pity()
	var rolled: Array[Dictionary] = PackDefs.roll_pack(pack_id, sm.packs_since_legendary)
	if sm.packs_since_legendary >= PackDefs.PITY_THRESHOLD:
		sm.reset_pity()
	GameBus.pack_purchased.emit(pack_id, rolled)

func _make_seed_row(seed_id: String, seed_data: Dictionary, coins: int) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", int(_vw * 0.008))

	var sm := SceneManager.save_manager
	var owned_count: int = int(sm.seeds.get(seed_id, 0))

	var info_lbl := Label.new()
	info_lbl.text = "%s  —  own: %d" % [str(seed_data.get("display_name", seed_id)), owned_count]
	info_lbl.add_theme_font_size_override("font_size", int(_vh * 0.022))
	info_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(info_lbl)

	var price_lbl := Label.new()
	price_lbl.text = "%d coins" % SEED_PRICE
	price_lbl.add_theme_font_size_override("font_size", int(_vh * 0.022))
	price_lbl.modulate = Color(1.0, 0.85, 0.1) if coins >= SEED_PRICE else Color(0.9, 0.3, 0.3)
	row.add_child(price_lbl)

	var buy_btn := Button.new()
	buy_btn.text = "Buy"
	buy_btn.custom_minimum_size = Vector2(_vw * 0.08, _vh * 0.065)
	buy_btn.add_theme_font_size_override("font_size", int(_vh * 0.022))
	buy_btn.disabled = coins < SEED_PRICE
	buy_btn.pressed.connect(_on_buy_seed.bind(seed_id))
	row.add_child(buy_btn)

	return row

func _on_buy_seed(seed_id: String) -> void:
	var sm := SceneManager.save_manager
	if sm.coins < SEED_PRICE:
		return
	sm.add_coins(-SEED_PRICE)
	sm.add_seeds(seed_id, 1)
	_refresh()

func _on_close() -> void:
	closed.emit()
