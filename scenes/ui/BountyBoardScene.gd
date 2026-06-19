extends Control

signal closed

var _vh: float = 0.0
var _vw: float = 0.0
var _ref: float = 0.0
var _rows_container: VBoxContainer
var _row_nodes: Array[Control] = []

func _ready() -> void:
	mouse_filter = MOUSE_FILTER_STOP
	_vh = get_viewport().get_visible_rect().size.y
	_vw = get_viewport().get_visible_rect().size.x
	_ref = minf(_vh, _vw)
	_build_ui()

func _build_ui() -> void:
	# Dark backdrop — tap to close (mobile parity)
	var bg := ColorRect.new()
	bg.color = Color(0.0, 0.0, 0.0, 0.78)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.gui_input.connect(_on_backdrop_input)
	add_child(bg)

	var panel_w: float = minf(_vw * 0.88, _vh * 0.65)
	var panel_h: float = _vh * 0.72
	var outer := PanelContainer.new()
	outer.custom_minimum_size = Vector2(panel_w, panel_h)
	outer.size = outer.custom_minimum_size
	outer.position = Vector2((_vw - panel_w) * 0.5, (_vh - panel_h) * 0.5)
	add_child(outer)

	var margin := MarginContainer.new()
	var pad: int = int(_ref * 0.018)
	margin.add_theme_constant_override("margin_left",   pad)
	margin.add_theme_constant_override("margin_right",  pad)
	margin.add_theme_constant_override("margin_top",    pad)
	margin.add_theme_constant_override("margin_bottom", pad)
	outer.add_child(margin)

	var root_vbox := VBoxContainer.new()
	root_vbox.add_theme_constant_override("separation", int(_ref * 0.015))
	margin.add_child(root_vbox)

	# Header
	var title := Label.new()
	title.text = "Daily Bounties"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var title_font_size: int = int(_ref * 0.028)
	title.add_theme_font_size_override("font_size", title_font_size)
	root_vbox.add_child(title)

	# Separator
	var sep := HSeparator.new()
	root_vbox.add_child(sep)

	# Bounty rows
	_rows_container = VBoxContainer.new()
	_rows_container.add_theme_constant_override("separation", int(_ref * 0.012))
	root_vbox.add_child(_rows_container)

	_populate_rows()

	# Spacer
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root_vbox.add_child(spacer)

	# Close button
	var close_btn := Button.new()
	close_btn.text = "Close"
	close_btn.custom_minimum_size = Vector2(_ref * 0.12, _ref * 0.05)
	close_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	close_btn.pressed.connect(_close)
	root_vbox.add_child(close_btn)

func _populate_rows() -> void:
	for child in _rows_container.get_children():
		child.queue_free()
	_row_nodes.clear()

	var offered: Array[Dictionary] = SceneManager.save_manager.get_offered_bounties()
	var active: Array[Dictionary] = SceneManager.save_manager.get_active_bounties()

	# Build a lookup: bounty_id -> active entry
	var active_map: Dictionary = {}
	for ab: Dictionary in active:
		active_map[str(ab.get("id", ""))] = ab

	for b: Dictionary in offered:
		var bid: String = str(b.get("id", ""))
		var row := _build_row(b, active_map.get(bid, {}))
		_rows_container.add_child(row)
		_row_nodes.append(row)

	# Also show active bounties not in today's offered list (accepted from a prior day)
	for ab: Dictionary in active:
		if bool(ab.get("claimed", false)):
			continue
		var abid: String = str(ab.get("id", ""))
		var already_shown: bool = false
		for b: Dictionary in offered:
			if str(b.get("id", "")) == abid:
				already_shown = true
				break
		if not already_shown:
			var row := _build_row(ab, ab)
			_rows_container.add_child(row)
			_row_nodes.append(row)

func _build_row(bounty: Dictionary, active_entry: Dictionary) -> Control:
	var bid: String = str(bounty.get("id", ""))
	var btype: String = str(bounty.get("type", ""))
	var target: String = str(bounty.get("target", ""))
	var count: int = int(bounty.get("count", 1))
	var reward: int = int(bounty.get("reward", 0))

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", int(_ref * 0.01))

	# Description label
	var desc := Label.new()
	desc.text = _format_bounty_desc(btype, target, count)
	desc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	desc.add_theme_font_size_override("font_size", int(_ref * 0.022))
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hbox.add_child(desc)

	# Reward / progress in center
	var mid_vbox := VBoxContainer.new()
	mid_vbox.custom_minimum_size = Vector2(_ref * 0.10, 0.0)

	var reward_lbl := Label.new()
	reward_lbl.text = "+%d coins" % reward
	reward_lbl.add_theme_font_size_override("font_size", int(_ref * 0.020))
	reward_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mid_vbox.add_child(reward_lbl)

	hbox.add_child(mid_vbox)

	# Button area
	var btn_size := Vector2(_ref * 0.14, _ref * 0.05)
	var state: String = _get_state(bid, active_entry, count)

	match state:
		"not_accepted":
			var btn := Button.new()
			btn.text = "Accept"
			btn.custom_minimum_size = btn_size
			if SceneManager.save_manager.get_active_bounties().size() >= 3:
				btn.disabled = true
				btn.tooltip_text = "Max 3 active bounties"
			else:
				var _bid_cap := bid
				var _bounty_cap := bounty.duplicate()
				btn.pressed.connect(func() -> void: _on_accept_pressed(_bid_cap, _bounty_cap))
			hbox.add_child(btn)
		"in_progress":
			var progress: int = int(active_entry.get("progress", 0))
			var prog_lbl := Label.new()
			prog_lbl.text = "In Progress\n%d / %d" % [progress, count]
			prog_lbl.add_theme_font_size_override("font_size", int(_ref * 0.018))
			prog_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			prog_lbl.modulate = Color(0.7, 0.7, 0.7)
			prog_lbl.custom_minimum_size = btn_size
			hbox.add_child(prog_lbl)
		"complete_unclaimed":
			var btn := Button.new()
			btn.text = "Claim"
			btn.custom_minimum_size = btn_size
			var _bid_cap := bid
			var _reward_cap := reward
			btn.pressed.connect(func() -> void: _on_claim_pressed(_bid_cap, _reward_cap))
			hbox.add_child(btn)
		"claimed":
			var done_lbl := Label.new()
			done_lbl.text = "Claimed"
			done_lbl.add_theme_font_size_override("font_size", int(_ref * 0.018))
			done_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			done_lbl.modulate = Color(0.5, 0.5, 0.5)
			done_lbl.custom_minimum_size = btn_size
			hbox.add_child(done_lbl)

	return hbox

func _get_state(bounty_id: String, active_entry: Dictionary, count: int) -> String:
	if active_entry.is_empty():
		return "not_accepted"
	if bool(active_entry.get("claimed", false)):
		return "claimed"
	var progress: int = int(active_entry.get("progress", 0))
	if progress >= count:
		return "complete_unclaimed"
	return "in_progress"

func _format_bounty_desc(btype: String, target: String, count: int) -> String:
	match btype:
		"defeat_enemy_type":
			var display: String = target.replace("_", " ").capitalize()
			return "Defeat %d %s" % [count, display]
		"defeat_in_biome":
			var biome: String = target.capitalize()
			return "Defeat %d enemies in the %s" % [count, biome]
		"open_chests":
			return "Open %d chest%s" % [count, "s" if count > 1 else ""]
	return "Complete this contract"

func _on_accept_pressed(bounty_id: String, bounty: Dictionary) -> void:
	var ok: bool = SceneManager.save_manager.accept_bounty(bounty_id)
	if ok:
		var desc: String = _format_bounty_desc(str(bounty.get("type", "")),
			str(bounty.get("target", "")), int(bounty.get("count", 1)))
		SceneManager.show_toast("Bounty Accepted", desc)
	_populate_rows()

func _on_claim_pressed(bounty_id: String, reward: int) -> void:
	var paid: int = SceneManager.save_manager.claim_bounty(bounty_id)
	if paid > 0:
		SceneManager.show_toast("Bounty Complete!", "+%d coins" % paid)
	_populate_rows()

func _on_backdrop_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
		_close()

func _close() -> void:
	closed.emit()
