extends "res://scenes/ui/CardBrowserOverlay.gd"

const CardRegistry = preload("res://autoloads/CardRegistry.gd")
const EnemyRegistry = preload("res://autoloads/EnemyRegistry.gd")
const WeaponRegistry = preload("res://autoloads/WeaponRegistry.gd")
const PackDefs = preload("res://game_logic/PackDefs.gd")
const GardenDefs = preload("res://game_logic/GardenDefs.gd")
const WeaponData = preload("res://data/WeaponData.gd")
const LongPressDetector = preload("res://scenes/ui/LongPressDetector.gd")
const _CardDropUtil = preload("res://game_logic/CardDropUtil.gd")

const CARD_PRICE: int = 15
const SEED_PRICE: int = 30

# Traveling merchant mode — set before add_child() via .set() in SceneManager.
var _custom_stock: Array[String] = []   # if non-empty, only show these cards
var _custom_price: int = 0              # 0 = use CARD_PRICE
var _custom_title: String = ""          # "" = use default title

# Town gratitude discount: set by SceneManager from current_map before add_child().
var town_name: String = ""

# Rarity selected for the cards section (session state).
var _shop_card_rarity: String = "common"

var _coin_label: Label
var _title_lbl: Label
var _shop_list: VBoxContainer
var _shop_scroll: ScrollContainer

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
	_title_lbl = _UiUtil.make_label(_custom_title if _custom_title != "" else "Merchant's Wares", int(_ref * 0.032), Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, root_vbox)

	# Coin display
	_coin_label = Label.new()
	_coin_label.add_theme_font_size_override("font_size", int(_ref * 0.024))
	_coin_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_coin_label.modulate = Color(1.0, 0.85, 0.1)
	root_vbox.add_child(_coin_label)

	# Scrollable list
	_shop_scroll = ScrollContainer.new()
	var scroll: ScrollContainer = _shop_scroll
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size = Vector2(0.0, _ref * 0.30)
	root_vbox.add_child(scroll)
	attach_drag_scroll(scroll)

	_shop_list = _UiUtil.make_vbox(int(_ref * 0.008), scroll)
	_shop_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	# Close button
	var close_btn := _UiUtil.make_button("Leave Shop", Vector2(_vw * 0.12, _ref * 0.065), int(_ref * 0.022), _on_close)
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

	# Rarity selector: 4 connected boxes [C][R][E][L]
	_shop_list.add_child(_make_card_rarity_selector())

	var base_price: int = int(CARD_PRICE * 0.8) if discounted else CARD_PRICE
	var rarity_cfg: Dictionary = IsoConst.RARITY_CONFIG.get(_shop_card_rarity, {})
	var rarity_ess: int = int(rarity_cfg.get("craft_essence", 10))
	var effective_card_price: int = int(base_price * rarity_ess / 10)
	effective_card_price = maxi(base_price, effective_card_price)

	var unlocked_ach: Array[String] = SceneManager.save_manager.unlocked_achievements
	var _sig_ids: Array[String] = EnemyRegistry.get_all_signature_card_ids()
	for id: String in CardRegistry.get_all_ids():
		if _sig_ids.has(id):
			continue
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
		var none_lbl := _UiUtil.make_label("No weapons available.", int(_ref * 0.022), Color(0.6, 0.6, 0.6), HORIZONTAL_ALIGNMENT_CENTER, _shop_list)

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
		var none_lbl := _UiUtil.make_label("No %s available." % slot, int(_ref * 0.022), Color(0.6, 0.6, 0.6), HORIZONTAL_ALIGNMENT_CENTER, _shop_list)

func _make_equipment_row(eid: String, weapon: WeaponData, price: int, coins: int) -> HBoxContainer:
	var row := _UiUtil.make_hbox(int(_vw * 0.008))

	var info_lbl := _UiUtil.make_label("%s  —  %s" % [weapon.display_name, _UiUtil.effect_summary(weapon.battle_effect_type, weapon.battle_effect_value, weapon.injected_card_count, weapon.injected_card_id)], int(_ref * 0.022), Color.WHITE, HORIZONTAL_ALIGNMENT_LEFT, row)
	info_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var price_lbl := _UiUtil.make_label("%d coins" % price, int(_ref * 0.022), Color(1.0, 0.85, 0.1) if coins >= price else Color(0.9, 0.3, 0.3), HORIZONTAL_ALIGNMENT_LEFT, row)

	var buy_btn := _UiUtil.make_button("Buy", Vector2(_vw * 0.08, _ref * 0.065), int(_ref * 0.022))
	buy_btn.disabled = coins < price
	# Scroll-safe (GID-120 / TID-454): never buy from a scroll gesture's release.
	_UiUtil.bind_scroll_safe_press(buy_btn, _on_buy_equipment.bind(eid, weapon.slot, price), _shop_scroll)
	row.add_child(buy_btn)

	return row

func _make_card_rarity_selector() -> HBoxContainer:
	var row := _UiUtil.make_hbox(1)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	for rarity: String in IsoConst.RARITY_ORDER:
		var cfg: Dictionary = IsoConst.RARITY_CONFIG.get(rarity, {})
		var ess: int = int(cfg.get("craft_essence", 10))
		var base: int = CARD_PRICE
		var rarity_price: int = maxi(base, int(base * ess / 10))
		var btn := _UiUtil.make_button("%s  %dg" % [_UiUtil.rarity_badge(rarity), rarity_price], Vector2(_ref * 0.16, _ref * 0.058), int(_ref * 0.020))
		if rarity == _shop_card_rarity:
			btn.modulate = _UiUtil.rarity_color(rarity)
		else:
			btn.modulate = Color(0.50, 0.50, 0.50)
		btn.pressed.connect(func() -> void:
			_shop_card_rarity = rarity
			_refresh())
		row.add_child(btn)
	return row

func _make_section_header(text: String) -> Label:
	var lbl := _UiUtil.make_label(text, int(_ref * 0.022), Color(0.75, 0.85, 1.0), HORIZONTAL_ALIGNMENT_CENTER)
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
	var row := _UiUtil.make_hbox(int(_vw * 0.008))

	# Colour swatch
	var swatch := ColorRect.new()
	var card_color: Color = tmpl.get("color", Color(0.3, 0.3, 0.35))
	swatch.color = card_color
	swatch.custom_minimum_size = Vector2(_ref * 0.03, _ref * 0.03)
	row.add_child(swatch)

	# Card name + stats
	var name_str: String = tmpl.get("name", id)
	var cost: int = tmpl.get("cost", 0)
	var atk: int  = tmpl.get("attack", 0)
	var hp: int   = tmpl.get("health", 0)
	var info_lbl := _UiUtil.make_label("%s   cost %d  %d/%d" % [name_str, cost, atk, hp], int(_ref * 0.022), Color.WHITE, HORIZONTAL_ALIGNMENT_LEFT, row)
	info_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	# Owned count
	var owned_count: int = 0
	for inst: Dictionary in SceneManager.save_manager.owned_cards:
		if str(inst.get("template_id", "")) == id:
			owned_count += 1
	var own_lbl := _UiUtil.make_label("own: %d" % owned_count, int(_ref * 0.020), Color(0.65, 0.65, 0.65), HORIZONTAL_ALIGNMENT_LEFT, row)

	# Price label
	var price_lbl := _UiUtil.make_label("%d coins" % price, int(_ref * 0.022), Color(1.0, 0.85, 0.1) if coins >= price else Color(0.9, 0.3, 0.3), HORIZONTAL_ALIGNMENT_LEFT, row)

	# Buy button
	var buy_btn := _UiUtil.make_button("Buy", Vector2(_vw * 0.08, _ref * 0.065), int(_ref * 0.022))
	buy_btn.disabled = coins < price
	# Scroll-safe (GID-120 / TID-454): never buy from a scroll gesture's release.
	_UiUtil.bind_scroll_safe_press(buy_btn, _on_buy_card.bind(id, price), _shop_scroll)
	row.add_child(buy_btn)

	var lpd := LongPressDetector.new()
	row.add_child(lpd)
	lpd.long_pressed.connect(func() -> void: _show_inspect(id))

	return row

func _make_weapon_row(wid: String, weapon: WeaponData, price: int, coins: int) -> HBoxContainer:
	var row := _UiUtil.make_hbox(int(_vw * 0.008))

	# Name + effect
	var info_lbl := _UiUtil.make_label("%s  —  %s" % [weapon.display_name, _UiUtil.effect_summary(weapon.battle_effect_type, weapon.battle_effect_value, weapon.injected_card_count, weapon.injected_card_id)], int(_ref * 0.022), Color.WHITE, HORIZONTAL_ALIGNMENT_LEFT, row)
	info_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	# Price label
	var price_lbl := _UiUtil.make_label("%d coins" % price, int(_ref * 0.022), Color(1.0, 0.85, 0.1) if coins >= price else Color(0.9, 0.3, 0.3), HORIZONTAL_ALIGNMENT_LEFT, row)

	# Buy button
	var buy_btn := _UiUtil.make_button("Buy", Vector2(_vw * 0.08, _ref * 0.065), int(_ref * 0.022), _on_buy_weapon.bind(wid, price), row)
	buy_btn.disabled = coins < price

	return row

func _on_buy_card(card_id: String, price: int = CARD_PRICE) -> void:
	var sm := SceneManager.save_manager
	if sm.coins < price:
		return
	sm.add_coins(-price)
	var stats: Dictionary = _CardDropUtil.roll_stats(card_id, _shop_card_rarity)
	sm.add_card_instance(card_id, _shop_card_rarity,
		int(stats.get("attack", -1)),
		int(stats.get("health", -1)),
		int(stats.get("cost", -1)))
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

func _make_pack_row(pack_id: String, pack_def: Dictionary, coins: int) -> VBoxContainer:
	var outer := _UiUtil.make_vbox(int(_ref * 0.004))

	var row := _UiUtil.make_hbox(int(_vw * 0.008))

	var pack_name: String = str(pack_def.get("name", pack_id))
	var price: int = int(pack_def.get("price", 0))

	var info_lbl := _UiUtil.make_label("%s  — 3 cards" % pack_name, int(_ref * 0.022), Color.WHITE, HORIZONTAL_ALIGNMENT_LEFT, row)
	info_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var price_lbl := _UiUtil.make_label("%d coins" % price, int(_ref * 0.022), Color(1.0, 0.85, 0.1) if coins >= price else Color(0.9, 0.3, 0.3), HORIZONTAL_ALIGNMENT_LEFT, row)

	var buy_btn := _UiUtil.make_button("Buy", Vector2(_vw * 0.08, _ref * 0.065), int(_ref * 0.022), _on_buy_pack.bind(pack_id, price), row)
	buy_btn.disabled = coins < price

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
		pity_lbl.add_theme_font_size_override("font_size", int(_ref * 0.018))
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
	var row := _UiUtil.make_hbox(int(_vw * 0.008))

	var sm := SceneManager.save_manager
	var owned_count: int = int(sm.seeds.get(seed_id, 0))

	var info_lbl := _UiUtil.make_label("%s  —  own: %d" % [str(seed_data.get("display_name", seed_id)), owned_count], int(_ref * 0.022), Color.WHITE, HORIZONTAL_ALIGNMENT_LEFT, row)
	info_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var price_lbl := _UiUtil.make_label("%d coins" % SEED_PRICE, int(_ref * 0.022), Color(1.0, 0.85, 0.1) if coins >= SEED_PRICE else Color(0.9, 0.3, 0.3), HORIZONTAL_ALIGNMENT_LEFT, row)

	var buy_btn := _UiUtil.make_button("Buy", Vector2(_vw * 0.08, _ref * 0.065), int(_ref * 0.022), _on_buy_seed.bind(seed_id), row)
	buy_btn.disabled = coins < SEED_PRICE

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
