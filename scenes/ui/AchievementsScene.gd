extends "res://scenes/ui/BaseOverlay.gd"

const AchievementRegistry = preload("res://game_logic/AchievementRegistry.gd")

func _ready() -> void:
	super._ready()
	_build_ui()

func _build_ui() -> void:
	_build_backdrop(0.82)

	var panel_w: float = minf(_vw * 0.92, _vh * 0.75)
	var panel_h: float = _vh * 0.88

	var outer := _build_centered_panel(panel_w, panel_h)

	var root_vbox := _build_margin_vbox(outer, 0.015, 0.012)

	# Title + close row
	var header_row := _UiUtil.make_hbox(0, root_vbox)

	var title := _UiUtil.make_label("Achievements", int(_vh * 0.038), Color.WHITE, HORIZONTAL_ALIGNMENT_LEFT, header_row)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var close_btn := _UiUtil.make_button("X", Vector2(_vh * 0.065, _vh * 0.065), int(_vh * 0.024), _close, header_row)

	# Scrollable list
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root_vbox.add_child(scroll)
	attach_drag_scroll(scroll)

	var list := _UiUtil.make_vbox(int(_vh * 0.010), scroll)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var unlocked: Array[String] = SceneManager.save_manager.unlocked_achievements
	var progress: Dictionary = SceneManager.save_manager.achievement_progress

	for a: Dictionary in AchievementRegistry.get_all():
		var aid: String = str(a["id"])
		var is_unlocked: bool = unlocked.has(aid)
		var row := _make_row(a, is_unlocked, int(progress.get(aid, 0)))
		list.add_child(row)

func _make_row(a: Dictionary, is_unlocked: bool, current: int) -> Control:
	var row := PanelContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var inner := _UiUtil.make_margin(int(_vw * 0.01), int(_vh * 0.008), int(_vw * 0.01), int(_vh * 0.008), row)

	var hbox := _UiUtil.make_hbox(int(_vw * 0.010), inner)

	# Lock / check icon
	var icon := _UiUtil.make_label("[OK]" if is_unlocked else "[  ]", int(_vh * 0.022), Color(0.3, 1.0, 0.3) if is_unlocked else Color(0.5, 0.5, 0.5), HORIZONTAL_ALIGNMENT_LEFT, hbox)

	var text_vbox := _UiUtil.make_vbox(int(_vh * 0.003), hbox)
	text_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var name_lbl := _UiUtil.make_label(str(a.get("name", "")), int(_vh * 0.022))
	if not is_unlocked:
		name_lbl.modulate = Color(0.55, 0.55, 0.55)
	text_vbox.add_child(name_lbl)

	var desc_lbl := _UiUtil.make_label(str(a.get("description", "")), int(_vh * 0.022), Color(0.65, 0.65, 0.65), HORIZONTAL_ALIGNMENT_LEFT, text_vbox)
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	# Progress
	var target: int = int(a.get("target_value", 1))
	if target > 1 and not is_unlocked:
		var prog_lbl := _UiUtil.make_label("%d / %d" % [mini(current, target), target], int(_vh * 0.022), Color(0.7, 0.85, 1.0), HORIZONTAL_ALIGNMENT_LEFT, text_vbox)

	# Reward indicator
	var reward_id: String = str(a.get("reward_card_id", ""))
	if reward_id != "":
		var reward_lbl := _UiUtil.make_label("Reward: Legendary card", int(_vh * 0.022), Color(1.0, 0.8, 0.2) if is_unlocked else Color(0.5, 0.4, 0.1), HORIZONTAL_ALIGNMENT_LEFT, text_vbox)

	return row

