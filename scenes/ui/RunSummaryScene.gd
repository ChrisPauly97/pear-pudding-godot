extends Control

const CardRegistry = preload("res://autoloads/CardRegistry.gd")

# Set before adding to tree to show Spire-specific stats instead of session stats.
var spire_stats: Dictionary = {}

var _vh: float = 0.0
var _vw: float = 0.0
var _ref: float = 0.0

func _ready() -> void:
	_vh = get_viewport().get_visible_rect().size.y
	_vw = get_viewport().get_visible_rect().size.x
	_ref = minf(_vh, _vw)
	if not spire_stats.is_empty():
		_build_spire_ui()
	else:
		_build_ui()

func _build_ui() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.06, 0.06, 0.10, 1.0)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var panel_w: float = minf(_vw * 0.88, _vh * 0.70)
	var panel_h: float = _vh * 0.85

	var outer := PanelContainer.new()
	outer.custom_minimum_size = Vector2(panel_w, panel_h)
	outer.size = Vector2(panel_w, panel_h)
	outer.position = Vector2((_vw - panel_w) * 0.5, (_vh - panel_h) * 0.5)
	add_child(outer)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left",   int(_vw * 0.025))
	margin.add_theme_constant_override("margin_right",  int(_vw * 0.025))
	margin.add_theme_constant_override("margin_top",    int(_ref * 0.025))
	margin.add_theme_constant_override("margin_bottom", int(_ref * 0.025))
	outer.add_child(margin)

	var root_vbox := VBoxContainer.new()
	root_vbox.add_theme_constant_override("separation", int(_ref * 0.018))
	margin.add_child(root_vbox)

	# Title
	var title := Label.new()
	title.text = "Session Summary"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", int(_ref * 0.045))
	title.modulate = Color(1.0, 0.88, 0.4)
	root_vbox.add_child(title)

	# Separator
	var sep := HSeparator.new()
	root_vbox.add_child(sep)

	# Stats grid
	var stats: Dictionary = SceneManager.session_stats
	var elapsed_msec: int = Time.get_ticks_msec() - int(stats.get("session_start_msec", Time.get_ticks_msec()))
	var elapsed_sec: int = elapsed_msec / 1000
	var minutes: int = elapsed_sec / 60
	var seconds: int = elapsed_sec % 60

	var stat_rows: Array = [
		["Battles Won",    str(int(stats.get("battles_won", 0)))],
		["Battles Lost",   str(int(stats.get("battles_lost", 0)))],
		["Enemies Defeated", str(int(stats.get("enemies_defeated", 0)))],
		["Cards Earned",   str(int(stats.get("cards_earned", 0)))],
		["Coins Earned",   str(int(stats.get("coins_earned", 0)))],
		["Chests Opened",  str(int(stats.get("chests_opened", 0)))],
		["Time Played",    "%02d:%02d" % [minutes, seconds]],
	]

	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", int(_vw * 0.04))
	grid.add_theme_constant_override("v_separation", int(_ref * 0.012))
	root_vbox.add_child(grid)

	for row: Array in stat_rows:
		var key_lbl := Label.new()
		key_lbl.text = str(row[0])
		key_lbl.add_theme_font_size_override("font_size", int(_ref * 0.024))
		key_lbl.modulate = Color(0.75, 0.75, 0.75)
		grid.add_child(key_lbl)

		var val_lbl := Label.new()
		val_lbl.text = str(row[1])
		val_lbl.add_theme_font_size_override("font_size", int(_ref * 0.024))
		val_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		grid.add_child(val_lbl)

	# Separator
	var sep2 := HSeparator.new()
	root_vbox.add_child(sep2)

	# Spacer
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root_vbox.add_child(spacer)

	# Return to menu button
	var btn_wrap := CenterContainer.new()
	root_vbox.add_child(btn_wrap)

	var menu_btn := Button.new()
	menu_btn.text = "Return to Menu"
	menu_btn.custom_minimum_size = Vector2(_ref * 0.32, _ref * 0.07)
	menu_btn.add_theme_font_size_override("font_size", int(_ref * 0.028))
	menu_btn.pressed.connect(_on_menu)
	btn_wrap.add_child(menu_btn)

func _on_menu() -> void:
	SceneManager.go_to_menu_direct()

func _build_spire_ui() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.06, 0.04, 0.12, 1.0)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var panel_w: float = minf(_vw * 0.88, _vh * 0.72)
	var panel_h: float = _vh * 0.88

	var outer := PanelContainer.new()
	outer.custom_minimum_size = Vector2(panel_w, panel_h)
	outer.size = Vector2(panel_w, panel_h)
	outer.position = Vector2((_vw - panel_w) * 0.5, (_vh - panel_h) * 0.5)
	add_child(outer)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left",   int(_vw * 0.025))
	margin.add_theme_constant_override("margin_right",  int(_vw * 0.025))
	margin.add_theme_constant_override("margin_top",    int(_ref * 0.025))
	margin.add_theme_constant_override("margin_bottom", int(_ref * 0.025))
	outer.add_child(margin)

	var root_vbox := VBoxContainer.new()
	root_vbox.add_theme_constant_override("separation", int(_ref * 0.016))
	margin.add_child(root_vbox)

	var floors_cleared: int = int(spire_stats.get("floors_cleared", 0))

	# Title
	var title := Label.new()
	title.text = "Endless Spire"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", int(_ref * 0.048))
	title.modulate = Color(0.75, 0.5, 1.0)
	root_vbox.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "Floor %d" % floors_cleared if floors_cleared > 0 else "Fallen before the first floor"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", int(_ref * 0.028))
	subtitle.modulate = Color(0.85, 0.85, 0.85)
	root_vbox.add_child(subtitle)

	# New record badge
	if bool(spire_stats.get("is_new_record", false)) and floors_cleared > 0:
		var record_lbl := Label.new()
		record_lbl.text = "New Record!"
		record_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		record_lbl.add_theme_font_size_override("font_size", int(_ref * 0.026))
		record_lbl.modulate = Color(1.0, 0.85, 0.2)
		root_vbox.add_child(record_lbl)

	root_vbox.add_child(HSeparator.new())

	# Stats grid
	var coins_earned: int = int(spire_stats.get("coins_earned", 0))
	var stat_rows: Array = [
		["Floors Cleared",    str(floors_cleared)],
		["Enemies Defeated",  str(int(spire_stats.get("enemies_defeated", 0)))],
		["Cards Drafted",     str(int(spire_stats.get("cards_drafted", 0)))],
		["Coins Earned",      str(coins_earned)],
		["Best Floor",        str(int(spire_stats.get("best_floor", floors_cleared)))],
	]

	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", int(_vw * 0.04))
	grid.add_theme_constant_override("v_separation", int(_ref * 0.012))
	root_vbox.add_child(grid)

	for row: Array in stat_rows:
		var key_lbl := Label.new()
		key_lbl.text = str(row[0])
		key_lbl.add_theme_font_size_override("font_size", int(_ref * 0.024))
		key_lbl.modulate = Color(0.75, 0.75, 0.75)
		grid.add_child(key_lbl)

		var val_lbl := Label.new()
		val_lbl.text = str(row[1])
		val_lbl.add_theme_font_size_override("font_size", int(_ref * 0.024))
		val_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		grid.add_child(val_lbl)

	# Draft deck list (up to 8 cards)
	var draft_ids: Array = spire_stats.get("draft_deck_ids", [])
	if draft_ids.size() > 0:
		root_vbox.add_child(HSeparator.new())
		var deck_header := Label.new()
		deck_header.text = "Cards Drafted"
		deck_header.add_theme_font_size_override("font_size", int(_ref * 0.022))
		deck_header.modulate = Color(0.75, 0.75, 0.75)
		root_vbox.add_child(deck_header)

		var names_vbox := VBoxContainer.new()
		names_vbox.add_theme_constant_override("separation", int(_ref * 0.006))
		root_vbox.add_child(names_vbox)

		var show_count: int = mini(draft_ids.size(), 8)
		for i: int in range(show_count):
			var cid: String = str(draft_ids[i])
			var tmpl: Dictionary = CardRegistry.get_template(cid)
			var card_name: String = str(tmpl.get("name", cid)) if not tmpl.is_empty() else cid
			var card_lbl := Label.new()
			card_lbl.text = "  • %s" % card_name
			card_lbl.add_theme_font_size_override("font_size", int(_ref * 0.020))
			names_vbox.add_child(card_lbl)
		if draft_ids.size() > 8:
			var more_lbl := Label.new()
			more_lbl.text = "  + %d more" % (draft_ids.size() - 8)
			more_lbl.add_theme_font_size_override("font_size", int(_ref * 0.020))
			more_lbl.modulate = Color(0.65, 0.65, 0.65)
			names_vbox.add_child(more_lbl)

	root_vbox.add_child(HSeparator.new())

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root_vbox.add_child(spacer)

	var btn_wrap := CenterContainer.new()
	root_vbox.add_child(btn_wrap)

	var menu_btn := Button.new()
	menu_btn.text = "Return to Menu"
	menu_btn.custom_minimum_size = Vector2(_ref * 0.32, _ref * 0.07)
	menu_btn.add_theme_font_size_override("font_size", int(_ref * 0.028))
	menu_btn.pressed.connect(_on_menu)
	btn_wrap.add_child(menu_btn)
