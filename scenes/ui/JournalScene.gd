extends "res://scenes/ui/BaseOverlay.gd"

const _EnemyRegistry = preload("res://autoloads/EnemyRegistry.gd")
const LandmarkNames  = preload("res://game_logic/world/LandmarkNames.gd")
const _QuestLog = preload("res://game_logic/quests/QuestLog.gd")
const _StoryQuests = preload("res://game_logic/quests/StoryQuests.gd")
const _Tales = preload("res://game_logic/quests/Tales.gd")

var hub_mode: bool = false

var _selected_id: String = ""
var _active_tab: String = "quests"
var _quest_selected_id: String = ""
var _bestiary_selected_id: String = ""

var _scroll_list: VBoxContainer
var _title_label: Label
var _lore_label: RichTextLabel
var _replay_btn: Button
var _header_label: Label
var _treasure_label: Label
var _tab_quests_btn: Button
var _tab_scrolls_btn: Button
var _track_btn: Button
var _tab_bestiary_btn: Button
var _tab_discoveries_btn: Button

func _ready() -> void:
	super._ready()
	_build_ui()
	_on_tab_selected(_active_tab)
	_refresh_treasure_panel()

func _build_ui() -> void:
	var is_portrait: bool = _vw < _vh
	var root_vbox: VBoxContainer
	if hub_mode:
		var m: int = int(_ref * 0.015)
		var margin := _UiUtil.make_margin(m, m, m, m, self)
		# _and_offsets_: the plain preset sets anchors but leaves the offsets, so the
		# margin stays at its minimum size instead of filling the hub content area.
		margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		root_vbox = _UiUtil.make_vbox(int(_ref * 0.01), margin)
	else:
		_build_backdrop(0.78)
		var panel_w: float = _vw * 0.95 if is_portrait else _vw * 0.86
		var panel_h: float = _vh * 0.92 if is_portrait else _vh * 0.86
		var outer := _build_centered_panel(panel_w, panel_h)
		root_vbox = _build_margin_vbox(outer, 0.015, 0.01)

	# ── Header row ────────────────────────────────────────────────────────────
	var header_row := _UiUtil.make_hbox(0, root_vbox)

	_header_label = Label.new()
	_header_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_header_label.add_theme_font_size_override("font_size", int(_vh * 0.035))
	header_row.add_child(_header_label)

	if not hub_mode:
		var close_btn := _UiUtil.make_button("X", Vector2(_vh * 0.055, _vh * 0.055), int(_vh * 0.028), _close,
				header_row)

	# ── Tab bar ───────────────────────────────────────────────────────────────
	var tab_bar := _UiUtil.make_hbox(0, root_vbox)

	_tab_quests_btn = _UiUtil.make_button("Quests", Vector2(0, _vh * 0.05), int(_vh * 0.022),
			_on_tab_selected.bind("quests"), tab_bar)
	_tab_quests_btn.flat = true
	_tab_quests_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	_tab_scrolls_btn = _UiUtil.make_button("Scrolls", Vector2(0, _vh * 0.05), int(_vh * 0.022),
			_on_tab_selected.bind("scrolls"), tab_bar)
	_tab_scrolls_btn.flat = true
	_tab_scrolls_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	_tab_bestiary_btn = _UiUtil.make_button("Bestiary", Vector2(0, _vh * 0.05), int(_vh * 0.022),
			_on_tab_selected.bind("bestiary"), tab_bar)
	_tab_bestiary_btn.flat = true
	_tab_bestiary_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	_tab_discoveries_btn = _UiUtil.make_button("Discoveries", Vector2(0, _vh * 0.05), int(_vh * 0.022),
			_on_tab_selected.bind("discoveries"), tab_bar)
	_tab_discoveries_btn.flat = true
	_tab_discoveries_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	# GID-153: the secret Pear Pudding legend — the tab only exists once a tale is heard.
	if not _Tales.heard(SaveManager.story_flags).is_empty():
		var tales_btn := _UiUtil.make_button("Old Tales", Vector2(0, _vh * 0.05), int(_vh * 0.022),
				_on_tab_selected.bind("tales"), tab_bar)
		tales_btn.flat = true
		tales_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL

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

	_scroll_list = _UiUtil.make_vbox(int(_vh * 0.008), left_scroll)
	_scroll_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	# Right panel — detail view
	var right_panel := PanelContainer.new()
	right_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panels_box.add_child(right_panel)

	var right_margin := _UiUtil.make_margin(int(_vw * 0.015), int(_vh * 0.015), int(_vw * 0.015), int(_vh * 0.015),
			right_panel)

	var detail_vbox := _UiUtil.make_vbox(int(_vh * 0.012), right_margin)

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

	_replay_btn = _UiUtil.make_button("Replay Narration", Vector2(_vw * 0.18, _vh * 0.06), int(_vh * 0.025),
			_on_replay_pressed)
	_replay_btn.hide()
	detail_vbox.add_child(_replay_btn)

	_track_btn = _UiUtil.make_button("Track", Vector2(_vw * 0.18, _vh * 0.06), int(_vh * 0.025),
			_on_track_pressed)
	_track_btn.hide()
	detail_vbox.add_child(_track_btn)

	_show_empty_state()

func _refresh_treasure_panel() -> void:
	if _treasure_label == null:
		return
	var sm := SaveManager
	var at: Dictionary = sm.active_treasure
	if not at.is_empty() and bool(at.get("completed", false)):
		_treasure_label.text = "Treasure: Excavated!"
	elif not at.is_empty():
		_treasure_label.text = "Treasure: Active dig site at (%d, %d)" % [int(at.get("site_x", 0)),
				int(at.get("site_z", 0))]
	elif sm.treasure_fragments > 0:
		_treasure_label.text = "Map Fragments: %d / 3" % sm.treasure_fragments
	else:
		_treasure_label.text = "Map Fragments: 0 / 3 — Collect 3 to form a treasure map."

func _show_empty_state() -> void:
	if _track_btn != null:
		_track_btn.hide()
	if _active_tab == "quests":
		_header_label.text = "Quests"
		_title_label.text = "Select a quest"
	elif _active_tab == "bestiary":
		_update_bestiary_header()
		_title_label.text = "Select an entry"
	elif _active_tab == "tales":
		_header_label.text = "Old Tales — %d / %d Heard" % [_Tales.heard(SaveManager.story_flags).size(),
				_Tales.TALES.size()]
		_title_label.text = "Select a tale"
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
		var btn := _UiUtil.make_button(scroll["title"], Vector2(_vw * 0.22, _vh * 0.06), int(_vh * 0.022),
				_on_scroll_selected.bind(sid), _scroll_list)
		btn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	if not any_found:
		var empty_lbl := _UiUtil.make_label("No lore scrolls found yet.", int(_vh * 0.022), Color.WHITE,
				HORIZONTAL_ALIGNMENT_LEFT, _scroll_list)
		empty_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

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
	if tab == "quests":
		_populate_quest_list()
	elif tab == "scrolls":
		_populate_scroll_list()
	elif tab == "bestiary":
		_populate_bestiary_list()
	elif tab == "tales":
		_populate_tales_list()
	else:
		_populate_discoveries_list()

# ── Quests tab (GID-140) ──────────────────────────────────────────────────────

func _quests() -> Array[Dictionary]:
	return SaveManager.active_quests()

func _populate_quest_list() -> void:
	for child in _scroll_list.get_children():
		child.queue_free()
	var tracked_id: String = str(SaveManager.tracked_quest_data().get("id", ""))
	for q: Dictionary in _quests():
		var qid: String = str(q.get("id", ""))
		var mark: String = "★ " if qid == tracked_id else ""
		var btn := _UiUtil.make_button(mark + str(q.get("label", "")), Vector2(_vw * 0.22, _vh * 0.06),
				int(_vh * 0.020), _on_quest_selected.bind(qid), _scroll_list)
		btn.flat = true
		btn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		btn.add_theme_color_override("font_color", _QuestLog.kind_color(str(q.get("kind", ""))))
	var done: Array[Dictionary] = _StoryQuests.completed_steps(SaveManager.story_flags)
	if done.is_empty():
		return
	_UiUtil.make_label("Story so far", int(_vh * 0.022), Color(0.85, 0.85, 0.85), HORIZONTAL_ALIGNMENT_LEFT,
			_scroll_list)
	var chapter: int = 0
	for step: Dictionary in done:
		if int(step["chapter"]) != chapter:
			chapter = int(step["chapter"])
			_UiUtil.make_label(_StoryQuests.chapter_title(chapter), int(_vh * 0.018), Color(0.9, 0.8, 0.5),
					HORIZONTAL_ALIGNMENT_LEFT, _scroll_list)
		var sbtn := _UiUtil.make_button("✓ " + str(step["label"]), Vector2(_vw * 0.22, _vh * 0.05),
				int(_vh * 0.018), _on_story_step_selected.bind(step), _scroll_list)
		sbtn.flat = true
		sbtn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		sbtn.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))

func _on_quest_selected(quest_id: String) -> void:
	_quest_selected_id = quest_id
	var q: Dictionary = _QuestLog.tracked(_quests(), quest_id)
	if str(q.get("id", "")) != quest_id:
		_show_empty_state()
		return
	_title_label.text = str(q.get("title", ""))
	_title_label.modulate = _QuestLog.kind_color(str(q.get("kind", "")))
	var text: String = "[b]%s[/b]" % str(q.get("label", ""))
	if str(q.get("giver", "")) != "":
		text += "\n[color=gray]From: %s[/color]" % str(q.get("giver", ""))
	text += "\n\n" + str(q.get("summary", ""))
	if str(q.get("progress", "")) != "":
		text += "\n\nProgress: " + str(q.get("progress", ""))
	_lore_label.text = text
	_replay_btn.hide()
	var tracked: bool = str(SaveManager.tracked_quest_data().get("id", "")) == quest_id
	var has_place: bool = _QuestLog.has_target(q)
	_track_btn.text = "Tracking" if tracked else ("Track" if has_place else "No marker")
	_track_btn.disabled = tracked or not has_place
	_track_btn.show()

func _on_story_step_selected(step: Dictionary) -> void:
	_quest_selected_id = ""
	_title_label.text = _StoryQuests.chapter_title(int(step["chapter"]))
	_title_label.modulate = Color(0.75, 0.75, 0.75)
	_lore_label.text = "[b]✓ %s[/b]\n[color=gray]From: %s[/color]\n\n%s" % [str(step["label"]),
			str(step.get("giver", "")), str(step.get("summary", ""))]
	_replay_btn.hide()
	_track_btn.hide()

func _on_track_pressed() -> void:
	if _quest_selected_id == "":
		return
	SaveManager.set_tracked_quest(_quest_selected_id)
	_populate_quest_list()
	_on_quest_selected(_quest_selected_id)

# ── Old Tales tab (GID-153) ──────────────────────────────────────────────────

func _populate_tales_list() -> void:
	for child in _scroll_list.get_children():
		child.queue_free()
	for t: Dictionary in _Tales.heard(SaveManager.story_flags):
		var solved: bool = _Tales.is_solved(t, SaveManager.story_flags)
		var btn := _UiUtil.make_button(("✓ " if solved else "") + str(t["title"]), Vector2(_vw * 0.22, _vh * 0.06),
				int(_vh * 0.020), _on_tale_selected.bind(str(t["id"])), _scroll_list)
		btn.flat = true
		btn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		btn.add_theme_color_override("font_color", Color(1.0, 0.8, 0.35))

func _on_tale_selected(tale_id: String) -> void:
	var t: Dictionary = _Tales.def(tale_id)
	_title_label.text = str(t.get("title", ""))
	_title_label.modulate = Color(1.0, 0.85, 0.4)
	var solved: bool = _Tales.is_solved(t, SaveManager.story_flags)
	_lore_label.text = "[color=gray]Heard from %s[/color]\n\n[i]\"%s\"[/i]\n\n[b]%s[/b]%s" % [
		str(t.get("npc_name", "")), str(t.get("lines", "")), str(t.get("riddle", "")),
		"\n\n[color=#9c6]Solved.[/color]" if solved else ""]
	_replay_btn.hide()

func _populate_discoveries_list() -> void:
	for child in _scroll_list.get_children():
		child.queue_free()
	var discovered: Array[String] = SaveManager.discovered_landmarks
	if discovered.is_empty():
		var empty_lbl := _UiUtil.make_label(
				"No landmarks discovered yet.\nExplore the world to find ancient colossi and ruins.", int(_vh * 0.022),
				Color.WHITE, HORIZONTAL_ALIGNMENT_LEFT, _scroll_list)
		empty_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		return
	var world_seed: int = SaveManager.world_seed
	for lid: String in discovered:
		var display_name: String = LandmarkNames.name_from_id(lid, world_seed)
		var btn := _UiUtil.make_button(display_name, Vector2(_vw * 0.22, _vh * 0.06), int(_vh * 0.020))
		btn.flat = true
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
	_lore_label.text = ("[color=gray]Biome:[/color] %s\n\n[i]A great ruin of an ancient age, standing witness to the "
			+ "passage of time.[/i]") % biome_name
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
			_lore_label.text = ("Deck size: %d cards\nDifficulty: %d / 4\nReward: %d coins\n\n[Defeat %d more time(s) "
					+ "to reveal lore]") % [deck.size(), diff, coins, remaining]
		2:
			_title_label.text = _EnemyRegistry.get_display_name(type_id)
			_title_label.modulate = Color(1, 1, 1)
			var deck2: Array[String] = _EnemyRegistry.get_deck(type_id)
			var diff2: int = _EnemyRegistry.get_difficulty_tier(type_id)
			var coins2: int = _EnemyRegistry.get_coin_reward(type_id)
			var lore: String = _EnemyRegistry.get_lore_text(type_id)
			_lore_label.text = "Deck size: %d cards\nDifficulty: %d / 4\nReward: %d coins\n\n%s" % [deck2.size(), diff2,
					coins2, lore]

func _input(event: InputEvent) -> void:
	if hub_mode:
		return
	super._input(event)

func _close() -> void:
	if hub_mode:
		return
	closed.emit()
	queue_free()
