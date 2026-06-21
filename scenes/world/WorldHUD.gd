extends Node

# Owns all dynamically-created HUD elements: buttons, labels, XP bar, bounty
# tracker, compass, ley indicator, dialogue/tip display.
# Created and owned by WorldScene; WorldScene keeps @onready tscn-defined nodes.

const CompassRibbon    = preload("res://scenes/ui/CompassRibbon.gd")
const ObjectiveTracker = preload("res://game_logic/ObjectiveTracker.gd")
const SaveManager      = preload("res://autoloads/SaveManager.gd")

var _hud: CanvasLayer
var _world_scene: Node3D
var _is_infinite: bool
var _map_name: String
var _interact_label: Label  # the @onready tscn node passed in from WorldScene

# HUD nodes owned here
var _dialogue_label: Label
var _tip_label: Label
var _coord_label: Label
var _level_label: Label
var _xp_bar: ProgressBar
var _xp_label: Label
var _ley_indicator: Label = null
var _mount_btn: Button = null
var _bounty_tracker: VBoxContainer = null
var _interact_btn: Button = null   # Android-only tap button
var _compass: Node = null

var _dialogue_id: int = 0
const DIALOGUE_DURATION: float = 4.0

var _tip_id: int = 0
const TIP_DURATION: float = 5.0

# ── Setup ──────────────────────────────────────────────────────────────────

func setup(hud: CanvasLayer, is_infinite: bool, map_name: String,
		interact_label: Label, world_scene: Node3D) -> void:
	_hud = hud
	_is_infinite = is_infinite
	_map_name = map_name
	_interact_label = interact_label
	_world_scene = world_scene

	var vp: Vector2 = hud.get_viewport().get_visible_rect().size
	var vh: float = vp.y
	var vw: float = vp.x
	var font_size: int = int(vh * 0.03)
	var btn_w: float = vh * 0.14
	var btn_h: float = vh * 0.07

	_create_nav_buttons(vh, vw, font_size, btn_w, btn_h)
	_create_cantrip_buttons(vh, font_size)
	_create_dialogue_label(vp, font_size)
	_create_tip_label(vp, font_size)
	_create_coord_label(vh, font_size)
	_create_xp_bar(vh)
	_create_ley_indicator(vh)
	_create_compass(map_name)

	if OS.has_feature("android"):
		_interact_btn = Button.new()
		_interact_btn.text = "USE"
		_interact_btn.custom_minimum_size = Vector2(vh * 0.18, vh * 0.08)
		_interact_btn.add_theme_font_size_override("font_size", int(vh * 0.032))
		_interact_btn.position = Vector2(vw * 0.5 - vh * 0.09, vh * 0.80)
		_interact_btn.pressed.connect(func() -> void: _world_scene.call("_handle_interact"))
		_interact_btn.hide()
		_hud.add_child(_interact_btn)

	GameBus.xp_changed.connect(_on_xp_changed)
	GameBus.mount_state_changed.connect(_on_mount_state_changed)
	GameBus.bounty_progress_changed.connect(func(_id, _p, _c): refresh_bounty_tracker())
	GameBus.bounty_completed.connect(func(_id): refresh_bounty_tracker())

func _create_nav_buttons(vh: float, vw: float, font_size: int,
		btn_w: float, btn_h: float) -> void:
	var menu_btn := Button.new()
	menu_btn.text = "Menu"
	menu_btn.custom_minimum_size = Vector2(btn_w, btn_h)
	menu_btn.position = Vector2(vh * 0.01, vh * 0.01)
	menu_btn.add_theme_font_size_override("font_size", font_size)
	menu_btn.pressed.connect(func() -> void: SceneManager.go_to_menu())
	_hud.add_child(menu_btn)

	var pause_btn := Button.new()
	pause_btn.text = "II"
	pause_btn.custom_minimum_size = Vector2(btn_h, btn_h)
	pause_btn.position = Vector2(vh * 0.01 + btn_w + vh * 0.005, vh * 0.01)
	pause_btn.add_theme_font_size_override("font_size", font_size)
	pause_btn.pressed.connect(func() -> void: _world_scene.call("_open_pause"))
	_hud.add_child(pause_btn)

	var minimap_bottom: float = vh * 0.01 + vh * 0.20 + vh * 0.01
	var btn_x: float = vw - btn_w * 1.3 - vh * 0.01

	var inv_btn := Button.new()
	inv_btn.text = "Inventory"
	inv_btn.custom_minimum_size = Vector2(btn_w * 1.3, btn_h)
	inv_btn.position = Vector2(btn_x, minimap_bottom)
	inv_btn.add_theme_font_size_override("font_size", font_size)
	inv_btn.pressed.connect(func() -> void: GameBus.inventory_requested.emit())
	_hud.add_child(inv_btn)

	var journal_btn := Button.new()
	journal_btn.text = "Journal"
	journal_btn.custom_minimum_size = Vector2(btn_w * 1.3, btn_h)
	journal_btn.position = Vector2(btn_x, minimap_bottom + btn_h + vh * 0.005)
	journal_btn.add_theme_font_size_override("font_size", font_size)
	journal_btn.pressed.connect(func() -> void: GameBus.journal_requested.emit())
	_hud.add_child(journal_btn)

	var char_btn := Button.new()
	char_btn.text = "Character"
	char_btn.custom_minimum_size = Vector2(btn_w * 1.3, btn_h)
	char_btn.position = Vector2(btn_x, minimap_bottom + (btn_h + vh * 0.005) * 2)
	char_btn.add_theme_font_size_override("font_size", font_size)
	char_btn.pressed.connect(func() -> void: GameBus.character_requested.emit())
	_hud.add_child(char_btn)

	var skill_btn := Button.new()
	skill_btn.text = "Skills"
	skill_btn.custom_minimum_size = Vector2(btn_w * 1.3, btn_h)
	skill_btn.position = Vector2(btn_x, minimap_bottom + (btn_h + vh * 0.005) * 3)
	skill_btn.add_theme_font_size_override("font_size", font_size)
	skill_btn.pressed.connect(func() -> void: GameBus.skill_tree_requested.emit())
	_hud.add_child(skill_btn)

	_mount_btn = Button.new()
	_mount_btn.text = "Mount"
	_mount_btn.custom_minimum_size = Vector2(btn_w * 1.3, btn_h)
	_mount_btn.position = Vector2(btn_x, minimap_bottom + (btn_h + vh * 0.005) * 4)
	_mount_btn.add_theme_font_size_override("font_size", font_size)
	_mount_btn.flat = true
	_mount_btn.pressed.connect(func() -> void: _world_scene.call("_toggle_mount"))
	_mount_btn.hide()
	_hud.add_child(_mount_btn)

func _create_cantrip_buttons(vh: float, font_size: int) -> void:
	var cantrip_btn_w: float = vh * 0.12
	var cantrip_btn_h: float = vh * 0.055
	var cantrip_x: float = vh * 0.01
	var cantrip_y: float = vh * 0.17

	var ghost_btn := Button.new()
	ghost_btn.text = "[G] Phase"
	ghost_btn.custom_minimum_size = Vector2(cantrip_btn_w, cantrip_btn_h)
	ghost_btn.add_theme_font_size_override("font_size", int(vh * 0.025))
	ghost_btn.position = Vector2(cantrip_x, cantrip_y)
	ghost_btn.pressed.connect(func() -> void: _world_scene.call("_activate_ghost_phase"))
	_hud.add_child(ghost_btn)

	var dig_btn := Button.new()
	dig_btn.text = "[D] Dig"
	dig_btn.custom_minimum_size = Vector2(cantrip_btn_w, cantrip_btn_h)
	dig_btn.add_theme_font_size_override("font_size", int(vh * 0.025))
	dig_btn.position = Vector2(cantrip_x, cantrip_y + cantrip_btn_h + vh * 0.005)
	dig_btn.pressed.connect(func() -> void: _world_scene.call("_activate_skeleton_dig"))
	_hud.add_child(dig_btn)

func _create_dialogue_label(vp: Vector2, font_size: int) -> void:
	_dialogue_label = Label.new()
	_dialogue_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_dialogue_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_dialogue_label.add_theme_font_size_override("font_size", font_size)
	_dialogue_label.add_theme_color_override("font_color", Color.WHITE)
	_dialogue_label.add_theme_color_override("font_shadow_color", Color.BLACK)
	_dialogue_label.add_theme_constant_override("shadow_offset_x", 2)
	_dialogue_label.add_theme_constant_override("shadow_offset_y", 2)
	_dialogue_label.size = Vector2(vp.x * 0.6, vp.y * 0.15)
	_dialogue_label.position = Vector2(vp.x * 0.2, vp.y * 0.78)
	_dialogue_label.hide()
	_hud.add_child(_dialogue_label)

func _create_tip_label(vp: Vector2, font_size: int) -> void:
	_tip_label = Label.new()
	_tip_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_tip_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_tip_label.add_theme_font_size_override("font_size", font_size)
	_tip_label.add_theme_color_override("font_color", Color(1.0, 1.0, 0.6))
	_tip_label.add_theme_color_override("font_shadow_color", Color.BLACK)
	_tip_label.add_theme_constant_override("shadow_offset_x", 2)
	_tip_label.add_theme_constant_override("shadow_offset_y", 2)
	_tip_label.size = Vector2(vp.x * 0.6, vp.y * 0.12)
	_tip_label.position = Vector2(vp.x * 0.2, vp.y * 0.14)
	_tip_label.hide()
	_hud.add_child(_tip_label)

func _create_coord_label(vh: float, font_size: int) -> void:
	_coord_label = Label.new()
	_coord_label.add_theme_font_size_override("font_size", font_size)
	_coord_label.add_theme_color_override("font_color", Color.WHITE)
	_coord_label.add_theme_color_override("font_shadow_color", Color.BLACK)
	_coord_label.add_theme_constant_override("shadow_offset_x", 1)
	_coord_label.add_theme_constant_override("shadow_offset_y", 1)
	_coord_label.position = Vector2(vh * 0.01, vh * 0.11)
	_hud.add_child(_coord_label)

func _create_xp_bar(vh: float) -> void:
	var xp_row := HBoxContainer.new()
	xp_row.position = Vector2(vh * 0.01, vh * 0.88)
	xp_row.add_theme_constant_override("separation", int(vh * 0.008))
	_hud.add_child(xp_row)

	_level_label = Label.new()
	_level_label.add_theme_font_size_override("font_size", int(vh * 0.028))
	_level_label.custom_minimum_size = Vector2(vh * 0.08, 0)
	xp_row.add_child(_level_label)

	_xp_bar = ProgressBar.new()
	_xp_bar.custom_minimum_size = Vector2(vh * 0.22, vh * 0.032)
	_xp_bar.show_percentage = false
	xp_row.add_child(_xp_bar)

	_xp_label = Label.new()
	_xp_label.add_theme_font_size_override("font_size", int(vh * 0.025))
	xp_row.add_child(_xp_label)

func _create_ley_indicator(vh: float) -> void:
	if not _is_infinite:
		return
	_ley_indicator = Label.new()
	_ley_indicator.text = "~ Attuned ~"
	_ley_indicator.add_theme_font_size_override("font_size", int(vh * 0.025))
	_ley_indicator.add_theme_color_override("font_color", Color(0.1, 0.95, 1.0))
	_ley_indicator.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_ley_indicator.set_anchor_and_offset(SIDE_LEFT, 0.5, -vh * 0.12)
	_ley_indicator.set_anchor_and_offset(SIDE_RIGHT, 0.5, vh * 0.12)
	_ley_indicator.set_anchor_and_offset(SIDE_TOP, 0.0, vh * 0.015)
	_ley_indicator.set_anchor_and_offset(SIDE_BOTTOM, 0.0, vh * 0.055)
	_ley_indicator.visible = false
	_hud.add_child(_ley_indicator)

func _create_compass(map_name: String) -> void:
	var cr := CompassRibbon.new()
	_hud.add_child(cr)
	_compass = cr
	cr.setup(_world_scene.get("_player") as Node3D)
	cr.set_current_map(map_name)
	var captured_map: String = map_name
	cr.add_marker("waypoint", Color(0.20, 0.80, 1.00), func():
		var wp: Dictionary = SceneManager.save_manager.waypoint
		if wp.is_empty() or str(wp.get("map", "")) != captured_map:
			return null
		var tx: int = int(wp.get("tx", 0))
		var tz: int = int(wp.get("tz", 0))
		return Vector3(float(tx) * IsoConst.TILE_SIZE, 0.0, float(tz) * IsoConst.TILE_SIZE)
	)
	cr.add_marker("objective", Color(1.0, 0.8, 0.0), func() -> Variant:
		var obj: Dictionary = ObjectiveTracker.current_objective(
			SceneManager.save_manager.story_flags)
		if obj.is_empty():
			return null
		var obj_map: String = str(obj.get("map", ""))
		var obj_tx: int = int(obj.get("tx", -1))
		var obj_tz: int = int(obj.get("tz", -1))
		if obj_map != captured_map:
			return null
		if obj_tx == -1 or obj_tz == -1:
			return null
		return Vector3(float(obj_tx) * IsoConst.TILE_SIZE, 0.0, float(obj_tz) * IsoConst.TILE_SIZE)
	)

# ── Public display API ─────────────────────────────────────────────────────

func show_dialogue(text: String) -> void:
	_dialogue_label.text = text
	_dialogue_label.show()
	GameBus.dialogue_state_changed.emit(true)
	_dialogue_id += 1
	var my_id := _dialogue_id
	get_tree().create_timer(DIALOGUE_DURATION, false).timeout.connect(
		func() -> void:
			if _dialogue_id == my_id:
				_dialogue_label.hide()
				GameBus.dialogue_state_changed.emit(false)
	)

func show_tip(text: String) -> void:
	_tip_label.text = text
	_tip_label.show()
	_tip_id += 1
	var my_id := _tip_id
	get_tree().create_timer(TIP_DURATION, false).timeout.connect(
		func() -> void:
			if _tip_id == my_id:
				_tip_label.hide()
	)

func update_coords(tx: int, tz: int) -> void:
	if _coord_label:
		_coord_label.text = "tile (%d, %d)" % [tx, tz]

func refresh_xp_bar() -> void:
	if _level_label == null or _xp_bar == null:
		return
	var sm := SceneManager.save_manager
	var lvl: int = sm.level
	var xp_prev: int = SaveManager.xp_for_level(lvl - 1)
	var xp_next: int = SaveManager.xp_for_level(lvl)
	_level_label.text = "Lv.%d" % lvl
	_xp_bar.max_value = xp_next - xp_prev
	_xp_bar.value = sm.xp - xp_prev

func update_xp_label() -> void:
	if _xp_label == null:
		return
	var sm := SceneManager.save_manager
	_xp_label.text = "%d / %d XP" % [
		sm.xp - SaveManager.xp_for_level(sm.level - 1),
		SaveManager.xp_for_level(sm.level) - SaveManager.xp_for_level(sm.level - 1)]

func set_ley_indicator_visible(v: bool) -> void:
	if _ley_indicator:
		_ley_indicator.visible = v

func show_interact_prompt(v: bool) -> void:
	if v:
		if _interact_btn != null:
			_interact_btn.show()
		else:
			_interact_label.show()
	else:
		_interact_label.hide()
		if _interact_btn != null:
			_interact_btn.hide()

func update_mount_btn() -> void:
	if _mount_btn == null:
		return
	var sm := SceneManager.save_manager
	var show: bool = sm.owned_mounts.size() > 0 and sm.current_map == "main"
	_mount_btn.visible = show
	_mount_btn.text = "Dismount" if sm.is_mounted else "Mount"

# ── Bounty tracker ─────────────────────────────────────────────────────────

func build_bounty_tracker() -> void:
	var vh: float = _hud.get_viewport().get_visible_rect().size.y
	_bounty_tracker = VBoxContainer.new()
	_bounty_tracker.position = Vector2(vh * 0.01, vh * 0.07)
	_hud.add_child(_bounty_tracker)
	refresh_bounty_tracker()

func refresh_bounty_tracker() -> void:
	if _bounty_tracker == null:
		return
	for child in _bounty_tracker.get_children():
		child.queue_free()
	var vh: float = _hud.get_viewport().get_visible_rect().size.y
	var font_size: int = int(vh * 0.02)
	var active: Array[Dictionary] = SceneManager.save_manager.get_active_bounties()
	for b: Dictionary in active:
		if bool(b.get("claimed", false)):
			continue
		var progress: int = int(b.get("progress", 0))
		var count: int = int(b.get("count", 1))
		var label := Label.new()
		label.add_theme_font_size_override("font_size", font_size)
		label.add_theme_color_override("font_shadow_color", Color.BLACK)
		label.add_theme_constant_override("shadow_offset_x", 1)
		label.add_theme_constant_override("shadow_offset_y", 1)
		var completed: bool = bool(b.get("completed", false)) or progress >= count
		if completed:
			label.add_theme_color_override("font_color", Color(0.4, 1.0, 0.4))
			label.text = "%s %d/%d (Claim at board)" % [_bounty_short_label(b), progress, count]
		else:
			label.add_theme_color_override("font_color", Color(1.0, 1.0, 0.7))
			label.text = "%s %d/%d" % [_bounty_short_label(b), progress, count]
		_bounty_tracker.add_child(label)

func _bounty_short_label(b: Dictionary) -> String:
	var btype: String = str(b.get("type", ""))
	var target: String = str(b.get("target", ""))
	match btype:
		"defeat_enemy_type":
			return target.replace("_", " ").capitalize()
		"defeat_in_biome":
			return target.capitalize() + " kills"
		"open_chests":
			return "Open chests"
	return "Bounty"

# ── Signal handlers ────────────────────────────────────────────────────────

func _on_xp_changed(_xp: int, _level: int) -> void:
	refresh_xp_bar()
	update_xp_label()

func _on_mount_state_changed(_mounted: bool, _mount_id: String) -> void:
	update_mount_btn()
