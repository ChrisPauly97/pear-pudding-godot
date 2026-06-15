# scenes/ui/MapViewOverlay.gd
# Full-map view overlay toggled by the M key when in a named map.
# Shows the 100×100 tile grid as a color-coded image with entity dots on top.
extends CanvasLayer

signal closed

# Tile color palette
const _COL_GRASS := Color(0.28, 0.55, 0.22)
const _COL_WALL  := Color(0.30, 0.25, 0.20)
const _COL_HILL  := Color(0.55, 0.42, 0.22)
const _COL_PATH  := Color(0.62, 0.52, 0.35)
const _COL_UNK   := Color(0.10, 0.10, 0.10)

# Entity dot colours
const _DOT_PLAYER   := Color(1.00, 1.00, 1.00)
const _DOT_ENEMY    := Color(0.95, 0.20, 0.20)
const _DOT_CHEST    := Color(1.00, 0.85, 0.10)
const _DOT_DOOR     := Color(0.55, 0.75, 1.00)
const _DOT_NPC      := Color(0.30, 0.95, 0.45)
const _DOT_MERCHANT := Color(0.20, 0.90, 0.90)
const _DOT_REST     := Color(0.35, 0.85, 0.65)   # teal-green: rest site
const _DOT_EVENT    := Color(0.95, 0.60, 0.15)   # amber: event room
const _DOT_DIGSITE  := Color(1.00, 0.65, 0.15)   # gold: active treasure dig site
const _DOT_WAYSTONE  := Color(0.40, 0.90, 1.00)   # cyan: waystone (dormant or active)
const _DOT_WAYPOINT  := Color(0.20, 0.80, 1.00)   # bright cyan: custom player waypoint

var _player: CharacterBody3D
var _npc_nodes: Dictionary
var _npc_data: Dictionary
var _enemy_nodes: Dictionary
var _chest_nodes: Dictionary
var _door_nodes: Dictionary
var _waystone_nodes: Dictionary

var _panel_pos: Vector2
var _panel_size: float
var _dot_layer: _DotLayer
var _travel_panel: ScrollContainer
var _map_name: String = ""

# Long-press state (mobile waypoint placement)
var _lp_active: bool = false
var _lp_pos: Vector2 = Vector2.ZERO
var _lp_elapsed: float = 0.0
const _LP_THRESHOLD: float = 0.5
const _LP_SLOP_PX: float = 12.0


const _Transforms = preload("res://scenes/ui/MapViewTransforms.gd")
const _ObjectiveTracker = preload("res://game_logic/ObjectiveTracker.gd")

# ── Inner dot-drawing layer ───────────────────────────────────────────────────
class _DotLayer extends Control:
	var overlay  # untyped — inner class cannot reference outer by name

	func _ready() -> void:
		mouse_filter = MOUSE_FILTER_IGNORE

	func _draw() -> void:
		if overlay:
			overlay._on_draw(self)


# ─────────────────────────────────────────────────────────────────────────────

func _is_in_panel(pos: Vector2) -> bool:
	return Rect2(_panel_pos, Vector2(_panel_size, _panel_size)).has_point(pos)


func setup(world_map, map_name: String, player: CharacterBody3D,
		npc_nodes: Dictionary, npc_data: Dictionary,
		enemy_nodes: Dictionary, chest_nodes: Dictionary,
		door_nodes: Dictionary, waystone_nodes: Dictionary = {}) -> void:
	_map_name       = map_name
	_player         = player
	_npc_nodes      = npc_nodes
	_npc_data       = npc_data
	_enemy_nodes    = enemy_nodes
	_chest_nodes    = chest_nodes
	_door_nodes     = door_nodes
	_waystone_nodes = waystone_nodes

	var vp: Vector2 = get_viewport().get_visible_rect().size
	var vh: float = vp.y
	var vw: float = vp.x
	_panel_size = minf(vw, vh) * 0.80
	_panel_pos = Vector2((vw - _panel_size) * 0.5, (vh - _panel_size) * 0.5)

	# ── Dim background ────────────────────────────────────────────────────────
	var bg := ColorRect.new()
	bg.color = Color(0.0, 0.0, 0.0, 0.70)
	bg.size = vp
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	# ── Panel ─────────────────────────────────────────────────────────────────
	var panel := ColorRect.new()
	panel.color = Color(0.08, 0.08, 0.10, 1.0)
	panel.size = Vector2(_panel_size, _panel_size)
	panel.position = _panel_pos
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(panel)

	# ── Tile grid image ───────────────────────────────────────────────────────
	var tex: ImageTexture = _build_map_texture(world_map)
	var tex_rect := TextureRect.new()
	tex_rect.texture = tex
	tex_rect.size = Vector2(_panel_size, _panel_size)
	tex_rect.position = _panel_pos
	tex_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tex_rect.stretch_mode = TextureRect.STRETCH_SCALE
	tex_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(tex_rect)

	# ── Entity dot layer ──────────────────────────────────────────────────────
	_dot_layer = _DotLayer.new()
	_dot_layer.overlay = self
	_dot_layer.size = vp
	_dot_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_dot_layer)

	# ── Title label ───────────────────────────────────────────────────────────
	var font_size: int = int(vh * 0.025)
	var title := Label.new()
	title.text = map_name.capitalize().replace("_", " ")
	title.add_theme_font_size_override("font_size", font_size)
	title.add_theme_color_override("font_color", Color.WHITE)
	title.add_theme_color_override("font_shadow_color", Color.BLACK)
	title.add_theme_constant_override("shadow_offset_x", 1)
	title.add_theme_constant_override("shadow_offset_y", 1)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.size = Vector2(_panel_size, font_size * 1.6)
	title.position = Vector2(_panel_pos.x, _panel_pos.y - font_size * 1.8)
	add_child(title)

	# ── Close hint ────────────────────────────────────────────────────────────
	var hint := Label.new()
	hint.text = "Tap minimap to close" if OS.has_feature("android") else "[M] or [Esc] to close"
	hint.add_theme_font_size_override("font_size", int(vh * 0.020))
	hint.add_theme_color_override("font_color", Color(0.75, 0.75, 0.75))
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.size = Vector2(_panel_size, int(vh * 0.030))
	hint.position = Vector2(_panel_pos.x, _panel_pos.y + _panel_size + int(vh * 0.008))
	add_child(hint)

	# ── Objective label ───────────────────────────────────────────────────────
	var obj: Dictionary = _ObjectiveTracker.current_objective(
		SceneManager.save_manager.story_flags)
	if not obj.is_empty():
		var obj_label := Label.new()
		obj_label.text = "Objective: " + str(obj.get("label", ""))
		obj_label.add_theme_font_size_override("font_size", int(vh * 0.020))
		obj_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
		obj_label.add_theme_color_override("font_shadow_color", Color.BLACK)
		obj_label.add_theme_constant_override("shadow_offset_x", 1)
		obj_label.add_theme_constant_override("shadow_offset_y", 1)
		obj_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		obj_label.size = Vector2(_panel_size, int(vh * 0.030))
		obj_label.position = Vector2(_panel_pos.x,
			_panel_pos.y + _panel_size - int(vh * 0.030))
		add_child(obj_label)

	# ── Clear-waypoint button ─────────────────────────────────────────────────
	var clr_btn := Button.new()
	clr_btn.text = "Clear Waypoint"
	clr_btn.custom_minimum_size = Vector2(vh * 0.16, vh * 0.05)
	clr_btn.add_theme_font_size_override("font_size", int(vh * 0.020))
	clr_btn.position = Vector2(_panel_pos.x + _panel_size - vh * 0.17,
		_panel_pos.y + _panel_size + int(vh * 0.008))
	clr_btn.pressed.connect(_clear_waypoint)
	add_child(clr_btn)

	# ── Fast travel panel ─────────────────────────────────────────────────────
	_build_fast_travel_panel(vp, vh)


func _build_map_texture(world_map) -> ImageTexture:
	var img := Image.create(100, 100, false, Image.FORMAT_RGB8)
	for tz in range(100):
		for tx in range(100):
			var tile: int = world_map.get_tile(tx, tz)
			img.set_pixel(tx, tz, _tile_color(tile))
	return ImageTexture.create_from_image(img)


func _tile_color(tile: int) -> Color:
	match tile:
		IsoConst.TILE_GRASS: return _COL_GRASS
		IsoConst.TILE_WALL:  return _COL_WALL
		IsoConst.TILE_HILL:  return _COL_HILL
		IsoConst.TILE_PATH:  return _COL_PATH
		_:                   return _COL_UNK


# Called by _DotLayer._draw()
func _on_draw(canvas: Control) -> void:
	# Entity nodes carry world positions; convert to tile coords then panel pixels.
	_draw_group(canvas, _enemy_nodes,   _DOT_ENEMY,    4.0, false)
	_draw_group(canvas, _chest_nodes,   _DOT_CHEST,    4.0, false)
	_draw_group(canvas, _door_nodes,    _DOT_DOOR,     4.0, false)
	_draw_group(canvas, _waystone_nodes, _DOT_WAYSTONE, 5.0, false)
	_draw_npcs(canvas)
	_draw_digsite(canvas)
	_draw_waypoint(canvas)
	# Player last so it's on top
	if is_instance_valid(_player):
		var tp: Vector2 = _world_to_panel(_player.position.x, _player.position.z)
		canvas.draw_circle(tp, 6.0, _DOT_PLAYER)


func _draw_digsite(canvas: Control) -> void:
	var at: Dictionary = SceneManager.save_manager.active_treasure
	if at.is_empty() or bool(at.get("completed", false)):
		return
	var wx: float = float(int(at.get("site_x", 0))) * IsoConst.TILE_SIZE + IsoConst.TILE_SIZE * 0.5
	var wz: float = float(int(at.get("site_z", 0))) * IsoConst.TILE_SIZE + IsoConst.TILE_SIZE * 0.5
	var tp: Vector2 = _world_to_panel(wx, wz)
	canvas.draw_arc(tp, 8.0, 0.0, TAU, 16, _DOT_DIGSITE, 2.0)
	canvas.draw_line(tp + Vector2(-6.0, -6.0), tp + Vector2(6.0, 6.0), _DOT_DIGSITE, 2.0)
	canvas.draw_line(tp + Vector2(6.0, -6.0),  tp + Vector2(-6.0, 6.0), _DOT_DIGSITE, 2.0)


func _draw_waypoint(canvas: Control) -> void:
	var wp: Dictionary = SceneManager.save_manager.waypoint
	if wp.is_empty() or str(wp.get("map", "")) != _map_name:
		return
	var tx: int = int(wp.get("tx", 0))
	var tz: int = int(wp.get("tz", 0))
	var wx: float = float(tx) * IsoConst.TILE_SIZE + IsoConst.TILE_SIZE * 0.5
	var wz: float = float(tz) * IsoConst.TILE_SIZE + IsoConst.TILE_SIZE * 0.5
	var tp: Vector2 = _world_to_panel(wx, wz)
	# Filled circle + crosshair lines for a pin-style marker
	canvas.draw_circle(tp, 7.0, _DOT_WAYPOINT)
	canvas.draw_line(tp + Vector2(0.0, -9.0), tp + Vector2(0.0, 9.0), _DOT_WAYPOINT, 1.5)
	canvas.draw_line(tp + Vector2(-9.0, 0.0), tp + Vector2(9.0, 0.0), _DOT_WAYPOINT, 1.5)


func _set_waypoint_at(screen_pos: Vector2) -> void:
	var world_pos: Vector3 = _Transforms.panel_to_world_coords(
		screen_pos.x, screen_pos.y,
		_panel_pos.x, _panel_pos.y, _panel_size, IsoConst.TILE_SIZE)
	var tx: int = clampi(int(world_pos.x / IsoConst.TILE_SIZE), 0, 99)
	var tz: int = clampi(int(world_pos.z / IsoConst.TILE_SIZE), 0, 99)
	SceneManager.save_manager.set_waypoint({"map": _map_name, "tx": tx, "tz": tz})
	_dot_layer.queue_redraw()


func _clear_waypoint() -> void:
	SceneManager.save_manager.set_waypoint({})
	_dot_layer.queue_redraw()


func _draw_group(canvas: Control, nodes: Dictionary, color: Color,
		radius: float, _unused: bool) -> void:
	for id in nodes:
		var n: Node3D = nodes[id]
		if not is_instance_valid(n):
			continue
		var tp: Vector2 = _world_to_panel(n.position.x, n.position.z)
		canvas.draw_circle(tp, radius, color)


func _draw_npcs(canvas: Control) -> void:
	for id in _npc_nodes:
		var n: Node3D = _npc_nodes[id]
		if not is_instance_valid(n):
			continue
		var data: Dictionary = _npc_data.get(id, {})
		var npc_type: String = str(data.get("npc_type", ""))
		var col: Color
		match npc_type:
			"merchant":  col = _DOT_MERCHANT
			"rest_site": col = _DOT_REST
			"event_room": col = _DOT_EVENT
			_:           col = _DOT_NPC
		var tp: Vector2 = _world_to_panel(n.position.x, n.position.z)
		canvas.draw_circle(tp, 4.0, col)


func _world_to_panel(wx: float, wz: float) -> Vector2:
	var tx: float = wx / IsoConst.TILE_SIZE
	var tz: float = wz / IsoConst.TILE_SIZE
	var px: float = _panel_pos.x + (tx / 100.0) * _panel_size
	var pz: float = _panel_pos.y + (tz / 100.0) * _panel_size
	return Vector2(px, pz)


func _build_fast_travel_panel(vp: Vector2, vh: float) -> void:
	var panel_w: float = vh * 0.22
	var panel_h: float = _panel_size
	var px: float = _panel_pos.x + _panel_size + vh * 0.02
	var py: float = _panel_pos.y

	var bg := ColorRect.new()
	bg.color = Color(0.05, 0.05, 0.08, 0.90)
	bg.size = Vector2(panel_w, panel_h)
	bg.position = Vector2(px, py)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	var font_size: int = int(vh * 0.022)
	var title_lbl := Label.new()
	title_lbl.text = "Fast Travel"
	title_lbl.add_theme_font_size_override("font_size", int(vh * 0.025))
	title_lbl.add_theme_color_override("font_color", Color(0.4, 0.9, 1.0))
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_lbl.size = Vector2(panel_w, int(vh * 0.038))
	title_lbl.position = Vector2(px, py + vh * 0.01)
	add_child(title_lbl)

	var is_blocked: bool = SceneManager._state != SceneManager.State.WORLD or \
		SceneManager.current_map.begins_with("dungeon_")

	_travel_panel = ScrollContainer.new()
	_travel_panel.size = Vector2(panel_w - vh * 0.02, panel_h - vh * 0.055)
	_travel_panel.position = Vector2(px + vh * 0.01, py + vh * 0.048)
	add_child(_travel_panel)

	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_travel_panel.add_child(vbox)

	var activated: Array[String] = SceneManager.save_manager.activated_waystones
	if activated.is_empty():
		var empty_lbl := Label.new()
		empty_lbl.text = "No waystones activated yet."
		empty_lbl.add_theme_font_size_override("font_size", font_size)
		empty_lbl.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
		empty_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		empty_lbl.custom_minimum_size = Vector2(panel_w - vh * 0.04, 0)
		vbox.add_child(empty_lbl)
	else:
		var btn_h: float = vh * 0.055
		var btn_w: float = panel_w - vh * 0.04
		for wid: String in activated:
			var label: String = _friendly_label(wid)
			var btn := Button.new()
			btn.text = label
			btn.custom_minimum_size = Vector2(btn_w, btn_h)
			btn.add_theme_font_size_override("font_size", font_size)
			if is_blocked:
				btn.disabled = true
				btn.modulate = Color(0.5, 0.5, 0.5)
			else:
				var captured_id: String = wid
				btn.pressed.connect(func() -> void: _teleport_to_waystone(captured_id))
			vbox.add_child(btn)

	if is_blocked:
		var block_lbl := Label.new()
		block_lbl.text = "Travel unavailable\nduring battles\nor in dungeons."
		block_lbl.add_theme_font_size_override("font_size", int(vh * 0.019))
		block_lbl.add_theme_color_override("font_color", Color(1.0, 0.4, 0.4))
		block_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		block_lbl.position = Vector2(px, py + panel_h - vh * 0.09)
		block_lbl.size = Vector2(panel_w, vh * 0.09)
		add_child(block_lbl)


func _friendly_label(waystone_id: String) -> String:
	if waystone_id.begins_with("map:"):
		var map_name_part: String = waystone_id.substr(4)
		return map_name_part.capitalize().replace("_", " ")
	elif waystone_id.begins_with("world:"):
		var parts: PackedStringArray = waystone_id.split(":")
		if parts.size() >= 3:
			return "Waystone (%s, %s)" % [parts[1], parts[2]]
	return waystone_id


func _teleport_to_waystone(waystone_id: String) -> void:
	closed.emit()
	queue_free()
	SceneManager.teleport_to_waystone(waystone_id)


func _process(delta: float) -> void:
	if _lp_active:
		_lp_elapsed += delta
		if _lp_elapsed >= _LP_THRESHOLD:
			_lp_active = false
			_set_waypoint_at(_lp_pos)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("map_view") or event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		closed.emit()
		queue_free()
		return

	# Right-click (desktop): immediate waypoint set
	if event is InputEventMouseButton:
		var e := event as InputEventMouseButton
		if e.button_index == MOUSE_BUTTON_RIGHT and e.pressed and _is_in_panel(e.position):
			_set_waypoint_at(e.position)
			get_viewport().set_input_as_handled()
			return

	# Long-press (mobile): track touch, fire after threshold
	if event is InputEventScreenTouch:
		var e := event as InputEventScreenTouch
		if e.pressed:
			if _is_in_panel(e.position):
				_lp_active = true
				_lp_elapsed = 0.0
				_lp_pos = e.position
		else:
			_lp_active = false

	if event is InputEventScreenDrag:
		var e := event as InputEventScreenDrag
		if _lp_active and e.position.distance_to(_lp_pos) > _LP_SLOP_PX:
			_lp_active = false
