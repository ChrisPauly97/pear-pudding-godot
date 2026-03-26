extends Control

signal closed

const CardRegistry = preload("res://autoloads/CardRegistry.gd")
const MAX_DECK: int = 20

var _vh: float = 0.0
var _vw: float = 0.0
var _working_deck: Array[String] = []

var _collection_list: VBoxContainer
var _deck_list: VBoxContainer
var _deck_count_label: Label
var _coin_label: Label

func _ready() -> void:
	mouse_filter = MOUSE_FILTER_STOP
	_vh = get_viewport().get_visible_rect().size.y
	_vw = get_viewport().get_visible_rect().size.x
	_working_deck.assign(SceneManager.save_manager.player_deck)
	_build_ui()
	_refresh()

func _build_ui() -> void:
	# Dark backdrop
	var bg := ColorRect.new()
	bg.color = Color(0.0, 0.0, 0.0, 0.78)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	# Outer container centred in viewport
	var outer := PanelContainer.new()
	var panel_w: float = _vw * 0.86
	var panel_h: float = _vh * 0.86
	outer.custom_minimum_size = Vector2(panel_w, panel_h)
	outer.position = Vector2((_vw - panel_w) * 0.5, (_vh - panel_h) * 0.5)
	add_child(outer)

	var outer_margin := MarginContainer.new()
	outer_margin.add_theme_constant_override("margin_left",   int(_vw * 0.015))
	outer_margin.add_theme_constant_override("margin_right",  int(_vw * 0.015))
	outer_margin.add_theme_constant_override("margin_top",    int(_vh * 0.015))
	outer_margin.add_theme_constant_override("margin_bottom", int(_vh * 0.015))
	outer.add_child(outer_margin)

	var root_hbox := HBoxContainer.new()
	root_hbox.add_theme_constant_override("separation", int(_vw * 0.012))
	outer_margin.add_child(root_hbox)

	# ---- Left column: collection ----------------------------------------
	var left_vbox := VBoxContainer.new()
	left_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_vbox.size_flags_stretch_ratio = 1.0
	root_hbox.add_child(left_vbox)

	var col_title := Label.new()
	col_title.text = "Collection"
	col_title.add_theme_font_size_override("font_size", int(_vh * 0.026))
	col_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	left_vbox.add_child(col_title)

	_coin_label = Label.new()
	_coin_label.add_theme_font_size_override("font_size", int(_vh * 0.022))
	_coin_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_coin_label.modulate = Color(1.0, 0.85, 0.1)
	left_vbox.add_child(_coin_label)

	var left_scroll := ScrollContainer.new()
	left_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left_vbox.add_child(left_scroll)

	_collection_list = VBoxContainer.new()
	_collection_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_collection_list.add_theme_constant_override("separation", int(_vh * 0.008))
	left_scroll.add_child(_collection_list)

	# ---- Separator -------------------------------------------------------
	var sep := VSeparator.new()
	root_hbox.add_child(sep)

	# ---- Right column: deck ----------------------------------------------
	var right_vbox := VBoxContainer.new()
	right_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_vbox.size_flags_stretch_ratio = 1.0
	root_hbox.add_child(right_vbox)

	_deck_count_label = Label.new()
	_deck_count_label.add_theme_font_size_override("font_size", int(_vh * 0.026))
	_deck_count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	right_vbox.add_child(_deck_count_label)

	var right_scroll := ScrollContainer.new()
	right_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right_vbox.add_child(right_scroll)

	_deck_list = VBoxContainer.new()
	_deck_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_deck_list.add_theme_constant_override("separation", int(_vh * 0.008))
	right_scroll.add_child(_deck_list)

	# ---- Button sidebar --------------------------------------------------
	var btn_vbox := VBoxContainer.new()
	btn_vbox.add_theme_constant_override("separation", int(_vh * 0.012))
	btn_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	root_hbox.add_child(btn_vbox)

	var save_btn := Button.new()
	save_btn.text = "Save Deck"
	save_btn.custom_minimum_size = Vector2(_vw * 0.1, _vh * 0.055)
	save_btn.add_theme_font_size_override("font_size", int(_vh * 0.02))
	save_btn.pressed.connect(_on_save)
	btn_vbox.add_child(save_btn)

	var close_btn := Button.new()
	close_btn.text = "Close  [I]"
	close_btn.custom_minimum_size = Vector2(_vw * 0.1, _vh * 0.055)
	close_btn.add_theme_font_size_override("font_size", int(_vh * 0.02))
	close_btn.pressed.connect(_on_close)
	btn_vbox.add_child(close_btn)

# -------------------------------------------------------------------------
# Refresh — rebuilds both panels from current working state
# -------------------------------------------------------------------------

func _refresh() -> void:
	# Clear both lists
	for child in _collection_list.get_children():
		child.queue_free()
	for child in _deck_list.get_children():
		child.queue_free()

	_coin_label.text = "Coins: %d" % SceneManager.save_manager.coins

	var owned: Dictionary = SceneManager.save_manager.get_owned_counts()

	# Count cards currently in the working deck
	var deck_counts: Dictionary = {}
	for cid in _working_deck:
		var id: String = str(cid)
		deck_counts[id] = int(deck_counts.get(id, 0)) + 1

	# Collection panel — one row per unique owned card
	for id in CardRegistry.get_all_ids():
		var owned_n: int = int(owned.get(id, 0))
		if owned_n == 0:
			continue
		var tmpl: Dictionary = CardRegistry.get_template(id)
		if tmpl.is_empty():
			continue
		var deck_n: int = int(deck_counts.get(id, 0))
		var avail: int = owned_n - deck_n
		var row := _make_collection_row(id, tmpl, owned_n, deck_n, avail)
		_collection_list.add_child(row)

	# Deck panel — one row per card slot (duplicates appear multiple times)
	for i in _working_deck.size():
		var id: String = _working_deck[i]
		var tmpl: Dictionary = CardRegistry.get_template(id)
		var row := _make_deck_row(id, tmpl, i)
		_deck_list.add_child(row)

	_deck_count_label.text = "Deck  (%d / %d)" % [_working_deck.size(), MAX_DECK]

# -------------------------------------------------------------------------
# Row builders
# -------------------------------------------------------------------------

func _make_collection_row(id: String, tmpl: Dictionary, owned_n: int, deck_n: int, avail: int) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", int(_vw * 0.008))

	# Colour swatch
	var swatch := ColorRect.new()
	var card_color: Color = tmpl.get("color", Color(0.3, 0.3, 0.35))
	swatch.color = card_color
	swatch.custom_minimum_size = Vector2(_vh * 0.03, _vh * 0.03)
	row.add_child(swatch)

	# Card name + count
	var name_lbl := Label.new()
	var name_str: String = tmpl.get("name", id)
	name_lbl.text = "%s  ×%d" % [name_str, owned_n]
	name_lbl.add_theme_font_size_override("font_size", int(_vh * 0.019))
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(name_lbl)

	# Stats: cost / atk / hp
	var cost: int = tmpl.get("cost", 0)
	var atk: int  = tmpl.get("attack", 0)
	var hp: int   = tmpl.get("health", 0)
	var stats_lbl := Label.new()
	stats_lbl.text = "cost %d  %d/%d" % [cost, atk, hp]
	stats_lbl.add_theme_font_size_override("font_size", int(_vh * 0.016))
	row.add_child(stats_lbl)

	# In-deck indicator
	if deck_n > 0:
		var in_deck_lbl := Label.new()
		in_deck_lbl.text = "(in deck: %d)" % deck_n
		in_deck_lbl.add_theme_font_size_override("font_size", int(_vh * 0.015))
		in_deck_lbl.modulate = Color(0.8, 0.85, 1.0)
		row.add_child(in_deck_lbl)

	# Add button
	var add_btn := Button.new()
	add_btn.text = "+"
	add_btn.custom_minimum_size = Vector2(_vh * 0.042, _vh * 0.042)
	add_btn.add_theme_font_size_override("font_size", int(_vh * 0.022))
	add_btn.disabled = (avail <= 0 or _working_deck.size() >= MAX_DECK)
	add_btn.pressed.connect(_on_add.bind(id))
	row.add_child(add_btn)

	return row

func _make_deck_row(id: String, tmpl: Dictionary, index: int) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", int(_vw * 0.008))

	# Colour swatch
	var swatch := ColorRect.new()
	var card_color: Color = tmpl.get("color", Color(0.3, 0.3, 0.35))
	swatch.color = card_color
	swatch.custom_minimum_size = Vector2(_vh * 0.03, _vh * 0.03)
	row.add_child(swatch)

	# Card name
	var name_lbl := Label.new()
	var name_str: String = tmpl.get("name", id)
	name_lbl.text = name_str
	name_lbl.add_theme_font_size_override("font_size", int(_vh * 0.019))
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(name_lbl)

	# Stats
	var cost: int = tmpl.get("cost", 0)
	var atk: int  = tmpl.get("attack", 0)
	var hp: int   = tmpl.get("health", 0)
	var stats_lbl := Label.new()
	stats_lbl.text = "cost %d  %d/%d" % [cost, atk, hp]
	stats_lbl.add_theme_font_size_override("font_size", int(_vh * 0.016))
	row.add_child(stats_lbl)

	# Remove button
	var rm_btn := Button.new()
	rm_btn.text = "−"
	rm_btn.custom_minimum_size = Vector2(_vh * 0.042, _vh * 0.042)
	rm_btn.add_theme_font_size_override("font_size", int(_vh * 0.022))
	rm_btn.pressed.connect(_on_remove.bind(index))
	row.add_child(rm_btn)

	return row

# -------------------------------------------------------------------------
# Actions
# -------------------------------------------------------------------------

func _on_add(id: String) -> void:
	if _working_deck.size() >= MAX_DECK:
		return
	var owned: Dictionary = SceneManager.save_manager.get_owned_counts()
	var deck_counts: Dictionary = {}
	for cid in _working_deck:
		var s: String = str(cid)
		deck_counts[s] = int(deck_counts.get(s, 0)) + 1
	var owned_n: int = int(owned.get(id, 0))
	var deck_n: int  = int(deck_counts.get(id, 0))
	if deck_n >= owned_n:
		return
	_working_deck.append(id)
	_refresh()

func _on_remove(index: int) -> void:
	if index < 0 or index >= _working_deck.size():
		return
	_working_deck.remove_at(index)
	_refresh()

func _on_save() -> void:
	SceneManager.save_manager.set_active_deck(_working_deck)
	closed.emit()

func _on_close() -> void:
	closed.emit()

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("inventory") or event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_on_close()
