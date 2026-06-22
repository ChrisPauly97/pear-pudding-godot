extends "res://scenes/ui/BaseOverlay.gd"

const _EnemyRegistry = preload("res://autoloads/EnemyRegistry.gd")
const LandmarkNames  = preload("res://game_logic/world/LandmarkNames.gd")

var hub_mode: bool = false

var _selected_id: String = ""
var _active_tab: String = "scrolls"
var _bestiary_selected_id: String = ""

var _scroll_list: VBoxContainer
var _title_label: Label
var _lore_label: RichTextLabel
var _replay_btn: Button
var _header_label: Label
var _treasure_label: Label
var _tab_scrolls_btn: Button
var _tab_bestiary_btn: Button
var _tab_discoveries_btn: Button

func _ready() -> void:
	super._ready()
	_build_ui()
	_populate_scroll_list()
	_refresh_treasure_panel()

func _build_ui() -> void:
	var is_portrait: bool = _vw < _vh
	var root_vbox: VBoxContainer
	if hub_mode:
		var margin := MarginContainer.new()
		margin.set_anchors_preset(Control.PRESET_FULL_RECT)
		var m: int = int(_ref * 0.015)
		margin.add_theme_constant_override("margin_left", m)
		margin.add_theme_constant_override("margin_right", m)
		margin.add_theme_constant_override("margin_top", m)
		margin.add_theme_constant_override("margin_bottom", m)
		add_child(margin)
		root_vbox = VBoxContainer.new()
		root_vbox.add_theme_constant_override("separation", int(_ref * 0.01))
		margin.add_child(root_vbox)
	else:
		_build_backdrop(0.78)
		var panel_w: float = _vw * 0.95 if is_portrait else _vw * 0.86
		var panel_h: float = _vh * 0.92 if is_portrait else _vh * 0.86
		var outer := _build_centered_panel(panel_w, panel_h)
		root_vbox = _build_margin_vbox(outer, 0.015, 0.01)

	# ── Header row ────────────────────────────────────────────────────────────
	var header_row := HBoxContainer.new()
	root_vbox.add_child(header_row)

	_header_label = Label.new()
	_header_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_header_label.add_theme_font_size_override("font_size", int(_vh * 0.035))
	header_row.add_child(_header_label)

	if not hub_mode:
		var close_btn := Button.new()
		close_btn.text = "X"
		close_btn.custom_minimum_size = Vector2(_vh * 0.055, _vh * 0.055)
		close_btn.add_theme_font_size_override("font_size", int(_vh * 0.028))
		close_btn.pressed.connect(_close)
		header_row.add_child(close_btn)

	# ── Tab bar ───────────────────────────────────────────────────────────────
	var tab_bar := HBoxContainer.new()
	tab_bar.add_theme_constant_override("separation", 0)
	root_vbox.add_child(tab_bar)

	_tab_scrolls_btn = Button.new()
	_tab_scrolls_btn.text = "Scrolls"
	_tab_scrolls_btn.flat = true
	_tab_scrolls_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_tab_scrolls_btn.custom_minimum_size = Vector2(0, _vh * 0.05)
	_tab_scrolls_btn.add_theme_font_size_override("font_size", int(_vh * 0.022))
	_tab_scrolls_btn.pressed.connect(_on_tab_selected.bind("scrolls"))
	tab_bar.add_child(_tab_scrolls_btn)

	_tab_bestiary_btn = Button.new()
	_tab_bestiary_btn.text = "Bestiary"
	_tab_bestiary_btn.flat = true
	_tab_bestiary_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_tab_bestiary_btn.custom_minimum_size = Vector2(0, _vh * 0.05)
	_tab_bestiary_btn.add_theme_font_size_override("font_size", int(_vh * 0.022))
	_tab_bestiary_btn.pressed.connect(_on_tab_selected.bind("bestiary"))
	tab_bar.add_child(_tab_bestiary_btn)

	_tab_discoveries_btn = Button.new()
	_tab_discoveries_btn.text = "Discoveries"
	_tab_discoveries_btn.flat = true
	_tab_discoveries_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_tab_discoveries_btn.custom_minimum_size = Vector2(0, _vh * 0.05)
	_tab_discoveries_btn.add_theme_font_size_override("font_size", int(_vh * 0.022))
	_tab_discoveries_btn.pressed.connect(_on_tab_selected.bind("discoveries"))
	tab_bar.add_child(_tab_discoveries_btn)

	# ── Treasure status row ───────────────────────────────────────────────────
	_treasure_label = Label.new()
	_treasure_label.add_theme_font_size_override("font_size", int(_vh * 0.025))
	_treasure_label.add_theme_color_override("font_color", Color(1.0, 0.82, 0.35))
	_treasure_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	root_vbox.add_child(_treasure_label)

	# ── Two-panel row ─────────────────────────────────────────────────────────
	var panels_box: BoxContainer
	if is_portrait:
		panels_box = VBoxContainer.new()
	else:
		panels_box = HBoxContainer.new()
	panels_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panels_box.add_theme_constant_override("separation", int(_vw * 0.012))
	root_vbox.add_child(panels_box)

	# Left panel — scroll list
	var left_panel := PanelContainer.new()
	var left_w: float = _vw * 0.25 if not is_portrait else _vw * 0.85
	left_panel.custom_minimum_size = Vector2(left_w, 0.0)
	left_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panels_box.add_child(left_panel)

	var left_scroll := ScrollContainer.new()
	left_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left_panel.add_child(left_scroll)
	attach_drag_scroll(left_scroll)

	_scroll_list = VBoxContainer.new()
	_scroll_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll_list.add_theme_constant_override("separation", int(_vh * 0.008))
	left_scroll.add_child(_scroll_list)

	# Right panel — detail view
	var right_panel := PanelContainer.new()
	right_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panels_box.add_child(right_panel)

	var right_margin := MarginContainer.new()
	right_margin.add_theme_constant_override("margin_left",   int(_vw * 0.015))
	right_margin.add_theme_constant_override("margin_right",  int(_vw * 0.015))
	right_margin.add_theme_constant_override("margin_top",    int(_vh * 0.015))
	right_margin.add_theme_constant_override("margin_bottom", int(_vh * 0.015))
	right_panel.add_child(right_margin)

	var detail_vbox := VBoxContainer.new()
	detail_vbox.add_theme_constant_override("separation", int(_vh * 0.012))
	right_margin.add_child(detail_vbox)

	_title_label = Label.new()
	_title_label.add_theme_font_size_override("font_size", int(_vh * 0.035))
	_title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail_vbox.add_child(_title_label)

	_lore_label = RichTextLabel.new()
	_lore_label.bbcode_enabled = true
	_lore_label.scroll_following = true
	_lore_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	_lore_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_lore_label.add_theme_font_size_override("normal_font_size", int(_vh * 0.022))
	detail_vbox.add_child(_lore_label)

	_replay_btn = Button.new()
	_replay_btn.text = "Replay Narration"
	_replay_btn.custom_minimum_size = Vector2(_vw * 0.18, _vh * 0.06)
	_replay_btn.add_theme_font_size_override("font_size", int(_vh * 0.025))
	_replay_btn.pressed.connect(_on_replay_pressed)
	_replay_btn.hide()
	detail_vbox.add_child(_replay_btn)

	_show_empty_state()

func _refresh_treasure_panel() -> void:
	if _treasure_label == null:
		return
	var sm := SaveManager
	var at: Dictionary = sm.active_treasure
	if not at.is_empty() and bool(at.get("completed", false)):
		_treasure_label.text = "Treasure: Excavated!"
	elif not at.is_empty():
		_treasure_label.text = "Treasure: Active dig site at (%d, %d)" % [int(at.get("site_x", 0)), int(at.get("site_z", 0))]
	elif sm.treasure_fragments > 0:
		_treasure_label.text = "Map Fragments: %d / 3" % sm.treasure_fragments
	else:
		_treasure_label.text = "Map Fragments: 0 / 3 — Collect 3 to form a treasure map."

func _show_empty_state() -> void:
	if _active_tab == "bestiary":
		_update_bestiary_header()
		_title_label.text = "Select an entry"
	elif _active_tab == "discoveries":
		var found: int = SaveManager.discovered_landmarks.size()
		_header_label.text = "Discoveries — %d Landmarks Found" % found
		_title_label.text = "Select a landmark"
	else:
		var found: int = SaveManager.collected_scrolls.size()
		_header_label.text = "Journal — %d / %d Scrolls" % [found, ScrollRegistry.SCROLL_COUNT]
		_title_label.text = "No scroll selected"
	_title_label.modulate = Color(1, 1, 1)
	_lore_label.text = ""
	_replay_btn.hide()

func _populate_scroll_list() -> void:
	for child in _scroll_list.get_children():
		child.queue_free()

	var all: Array[Dictionary] = ScrollRegistry.get_all_scrolls()
	var any_found: bool = false
	for scroll in all:
		var sid: String = scroll["id"]
		if not SaveManager.is_scroll_collected(sid):
			continue
		any_found = true
		var btn := Button.new()
		btn.text = scroll["title"]
		btn.custom_minimum_size = Vector2(_vw * 0.22, _vh * 0.06)
		btn.add_theme_font_size_override("font_size", int(_vh * 0.022))
		btn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		btn.pressed.connect(_on_scroll_selected.bind(sid))
		_scroll_list.add_child(btn)

	if not any_found:
		var empty_lbl := Label.new()
		empty_lbl.text = "No lore scrolls found yet."
		empty_lbl.add_theme_font_size_override("font_size", int(_vh * 0.022))
		empty_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_scroll_list.add_child(empty_lbl)

func _on_scroll_selected(scroll_id: String) -> void:
	_selected_id = scroll_id
	var scroll: Dictionary = ScrollRegistry.get_scroll(scroll_id)
	if scroll.is_empty():
		return
	var found: int = SaveManager.collected_scrolls.size()
	_header_label.text = "Journal — %d / %d Scrolls" % [found, ScrollRegistry.SCROLL_COUNT]
	_title_label.text = scroll.get("title", "")
	_lore_label.text = scroll.get("lore_text", "")
	_replay_btn.show()

func _on_replay_pressed() -> void:
	if _selected_id != "":
		AudioManager.play_narration(_selected_id)

func _on_tab_selected(tab: String) -> void:
	_active_tab = tab
	_show_empty_state()
	if tab == "scrolls":
		_populate_scroll_list()
	elif tab == "bestiary":
		_populate_bestiary_list()
	else:
		_populate_discoveries_list()

func _populate_discoveries_list() -> void:
	for child in _scroll_list.get_children():
		child.queue_free()
	var discovered: Array[String] = SaveManager.discovered_landmarks
	if discovered.is_empty():
		var empty_lbl := Label.new()
		empty_lbl.text = "No landmarks discovered yet.\nExplore the world to find ancient colossi and ruins."
		empty_lbl.add_theme_font_size_override("font_size", int(_vh * 0.022))
		empty_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_scroll_list.add_child(empty_lbl)
		return
	var world_seed: int = SaveManager.world_seed
	for lid: String in discovered:
		var display_name: String = LandmarkNames.name_from_id(lid, world_seed)
		var btn := Button.new()
		btn.text = display_name
		btn.flat = true
		btn.custom_minimum_size = Vector2(_vw * 0.22, _vh * 0.06)
		btn.add_theme_font_size_override("font_size", int(_vh * 0.020))
		btn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		btn.add_theme_color_override("font_color", Color(0.9, 0.8, 0.5))
		btn.pressed.connect(_on_discovery_selected.bind(lid))
		_scroll_list.add_child(btn)

func _on_discovery_selected(landmark_id: String) -> void:
	var world_seed: int = SaveManager.world_seed
	var display_name: String = LandmarkNames.name_from_id(landmark_id, world_seed)
	var parts: PackedStringArray = landmark_id.split("_")
	var biome_name: String = ""
	if parts.size() >= 3:
		var cx: int = int(parts[1])
		var cz: int = int(parts[2])
		const InfiniteWorldGen = preload("res://game_logic/world/InfiniteWorldGen.gd")
		const BiomeDef = preload("res://game_logic/world/BiomeDef.gd")
		var l_data: Dictionary = InfiniteWorldGen.landmark_for_chunk(cx, cz, world_seed)
		var biome: int = int(l_data.get("biome", 0))
		var biome_names: Array[String] = ["Grasslands", "Forest", "Desert", "Scorched", "Mountains"]
		biome_name = biome_names[biome % biome_names.size()]
	_title_label.text = display_name
	_title_label.modulate = Color(1.0, 0.85, 0.4)
	_lore_label.text = "[color=gray]Biome:[/color] %s\n\n[i]A great ruin of an ancient age, standing witness to the passage of time.[/i]" % biome_name
	_replay_btn.hide()

func _get_bestiary_tier(type_id: String) -> int:
	var entry: Dictionary = SaveManager.get_bestiary_entry(type_id)
	var seen: int = int(entry.get("seen", 0))
	var defeated: int = int(entry.get("defeated", 0))
	if seen == 0:
		return 0
	if defeated >= 3:
		return 2
	return 1

func _update_bestiary_header() -> void:
	var all_ids: Array[String] = _EnemyRegistry.get_all_enemy_ids()
	var total: int = all_ids.size()
	var revealed: int = 0
	for tid: String in all_ids:
		if _get_bestiary_tier(tid) >= 1:
			revealed += 1
	var complete_banner: String = ""
	if SaveManager.bestiary_complete_rewarded:
		complete_banner = "  ★ All enemies defeated!"
	_header_label.text = "Bestiary — %d / %d Revealed%s" % [revealed, total, complete_banner]

func _populate_bestiary_list() -> void:
	for child in _scroll_list.get_children():
		child.queue_free()
	var all_ids: Array[String] = _EnemyRegistry.get_all_enemy_ids()
	for type_id: String in all_ids:
		var tier: int = _get_bestiary_tier(type_id)
		var btn := Button.new()
		btn.flat = true
		btn.custom_minimum_size = Vector2(_vw * 0.22, _vh * 0.055)
		btn.add_theme_font_size_override("font_size", int(_vh * 0.020))
		btn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		match tier:
			0:
				btn.text = "???"
				btn.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
			1:
				btn.text = _EnemyRegistry.get_display_name(type_id)
			2:
				btn.text = _EnemyRegistry.get_display_name(type_id)
				btn.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
		btn.pressed.connect(_on_bestiary_enemy_selected.bind(type_id))
		_scroll_list.add_child(btn)

func _on_bestiary_enemy_selected(type_id: String) -> void:
	_bestiary_selected_id = type_id
	_show_bestiary_detail(type_id)

func _show_bestiary_detail(type_id: String) -> void:
	var tier: int = _get_bestiary_tier(type_id)
	_replay_btn.hide()
	match tier:
		0:
			_title_label.text = "???"
			_title_label.modulate = Color(0.4, 0.4, 0.4)
			_lore_label.text = "Encounter this enemy to reveal more."
		1:
			_title_label.text = _EnemyRegistry.get_display_name(type_id)
			_title_label.modulate = Color(1, 1, 1)
			var entry: Dictionary = SaveManager.get_bestiary_entry(type_id)
			var defeated: int = int(entry.get("defeated", 0))
			var deck: Array[String] = _EnemyRegistry.get_deck(type_id)
			var diff: int = _EnemyRegistry.get_difficulty_tier(type_id)
			var coins: int = _EnemyRegistry.get_coin_reward(type_id)
			var remaining: int = max(0, 3 - defeated)
			_lore_label.text = "Deck size: %d cards\nDifficulty: %d / 4\nReward: %d coins\n\n[Defeat %d more time(s) to reveal lore]" % [deck.size(), diff, coins, remaining]
		2:
			_title_label.text = _EnemyRegistry.get_display_name(type_id)
			_title_label.modulate = Color(1, 1, 1)
			var deck2: Array[String] = _EnemyRegistry.get_deck(type_id)
			var diff2: int = _EnemyRegistry.get_difficulty_tier(type_id)
			var coins2: int = _EnemyRegistry.get_coin_reward(type_id)
			var lore: String = _EnemyRegistry.get_lore_text(type_id)
			_lore_label.text = "Deck size: %d cards\nDifficulty: %d / 4\nReward: %d coins\n\n%s" % [deck2.size(), diff2, coins2, lore]

func _input(event: InputEvent) -> void:
	if hub_mode:
		return
	super._input(event)

func _close() -> void:
	if hub_mode:
		return
	closed.emit()
	queue_free()
