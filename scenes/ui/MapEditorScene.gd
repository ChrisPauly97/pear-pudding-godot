extends Node3D

const WorldMap = preload("res://game_logic/world/WorldMap.gd")

var _world_map: WorldMap
var _current_map_name: String = "main"
var _paint_mode: int = 0  # 0=grass, 1=wall, 2=hill, 3=enemy, 4=chest, 5=door, 6=spawn, 7=erase
var _paint_height: int = 1
var _last_painted_tile: Vector2i = Vector2i(-1, -1)

@onready var _camera: Camera3D = $Camera3D
@onready var _hud: CanvasLayer = $HUD
@onready var _mode_label: Label = $HUD/ModeLabel
@onready var _map_name_label: Label = $HUD/MapNameLabel

# Two MultiMeshInstance3D nodes replace 10,000 individual MeshInstance3D nodes.
# _flat_mm: all grass + hill tiles (per-instance color distinguishes them)
# _wall_mm: all wall tiles (per-instance transform encodes height via Y scale)
var _flat_mm_inst: MultiMeshInstance3D
var _wall_mm_inst: MultiMeshInstance3D
var _entity_markers: Node3D
var _highlight_mesh: MeshInstance3D

# Persistent GPU resources — created once in _ready(), reused on every rebuild.
# No MultiMesh/mesh/material allocations happen during paint.
var _flat_mm: MultiMesh
var _wall_mm: MultiMesh
var _marker_mesh: SphereMesh
var _mat_enemy: StandardMaterial3D
var _mat_chest: StandardMaterial3D
var _mat_door: StandardMaterial3D
var _mat_spawn: StandardMaterial3D

# Mobile toolbar
var _toolbar: Control
var _mode_buttons: Array[Button] = []
var _btn_normal_styles: Array[StyleBoxFlat] = []
var _btn_active_styles: Array[StyleBoxFlat] = []
var _height_label: Label

var _mode_colors: Array[Color] = [
	Color(0.15, 0.5, 0.1),   # grass
	Color(0.4, 0.32, 0.22),  # wall
	Color(0.48, 0.38, 0.12), # hill
	Color(0.7, 0.12, 0.12),  # enemy
	Color(0.75, 0.6, 0.04),  # chest
	Color(0.38, 0.22, 0.06), # door
	Color(0.04, 0.55, 0.75), # spawn
	Color(0.5, 0.06, 0.06),  # erase
]

func _ready() -> void:
	# --- Flat MultiMesh (grass + hill tiles) ---
	_flat_mm = MultiMesh.new()
	_flat_mm.transform_format = MultiMesh.TRANSFORM_3D
	_flat_mm.use_colors = true
	var plane := PlaneMesh.new()
	plane.size = Vector2(IsoConst.TILE_SIZE * 0.95, IsoConst.TILE_SIZE * 0.95)
	plane.subdivide_width = 0
	plane.subdivide_depth = 0
	var flat_mat := StandardMaterial3D.new()
	flat_mat.vertex_color_use_as_albedo = true
	plane.material = flat_mat
	_flat_mm.mesh = plane
	_flat_mm_inst = MultiMeshInstance3D.new()
	_flat_mm_inst.multimesh = _flat_mm
	add_child(_flat_mm_inst)

	# --- Wall MultiMesh ---
	_wall_mm = MultiMesh.new()
	_wall_mm.transform_format = MultiMesh.TRANSFORM_3D
	var box := BoxMesh.new()
	box.size = Vector3(IsoConst.TILE_SIZE * 0.95, 1.0, IsoConst.TILE_SIZE * 0.95)
	var wall_mat := StandardMaterial3D.new()
	wall_mat.albedo_color = Color(0.5, 0.4, 0.35)
	box.material = wall_mat
	_wall_mm.mesh = box
	_wall_mm_inst = MultiMeshInstance3D.new()
	_wall_mm_inst.multimesh = _wall_mm
	add_child(_wall_mm_inst)

	# --- Shared entity marker resources ---
	_marker_mesh = SphereMesh.new()
	_marker_mesh.radius = 0.3
	_mat_enemy = StandardMaterial3D.new()
	_mat_enemy.albedo_color = Color.RED
	_mat_chest = StandardMaterial3D.new()
	_mat_chest.albedo_color = Color(1, 0.8, 0)
	_mat_door = StandardMaterial3D.new()
	_mat_door.albedo_color = Color(0.5, 0.3, 0.1)
	_mat_spawn = StandardMaterial3D.new()
	_mat_spawn.albedo_color = Color.CYAN

	_entity_markers = Node3D.new()
	add_child(_entity_markers)

	_create_highlight()
	_load_map(_current_map_name)
	_setup_camera()
	_build_mobile_toolbar()
	_update_hud()

func _setup_camera() -> void:
	_camera.position = Vector3(50, 80, 80)
	_camera.look_at(Vector3(50, 0, 50), Vector3.UP)

func _create_highlight() -> void:
	_highlight_mesh = MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(IsoConst.TILE_SIZE, IsoConst.TILE_SIZE)
	plane.subdivide_width = 0
	plane.subdivide_depth = 0
	_highlight_mesh.mesh = plane
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1, 1, 0, 0.4)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_highlight_mesh.material_override = mat
	_highlight_mesh.position.y = 0.05
	add_child(_highlight_mesh)

# --- MultiMesh tile rendering ---

# update_flat / update_walls let callers skip whichever half didn't change,
# avoiding a full GPU buffer rewrite on every stroke.
func _rebuild_tile_multimeshes(update_flat: bool = true, update_walls: bool = true) -> void:
	var flat_positions: Array[Vector3] = []
	var flat_colors: Array[Color] = []
	var wall_positions: Array[Vector3] = []
	var wall_scale_ys: Array[float] = []

	for tz in range(WorldMap.MAP_HEIGHT):
		for tx in range(WorldMap.MAP_WIDTH):
			var tile: int = _world_map.get_tile(tx, tz)
			var wx: float = tx * IsoConst.TILE_SIZE + IsoConst.TILE_SIZE * 0.5
			var wz: float = tz * IsoConst.TILE_SIZE + IsoConst.TILE_SIZE * 0.5
			if tile == WorldMap.TILE_WALL:
				if update_walls:
					var h: int = _world_map.get_height(tx, tz)
					var scale_y: float = h * IsoConst.WALL_FACE_H
					wall_positions.append(Vector3(wx, scale_y * 0.5, wz))
					wall_scale_ys.append(scale_y)
			else:
				if update_flat:
					flat_positions.append(Vector3(wx, 0.01, wz))
					flat_colors.append(Color(0.3, 0.6, 0.2) if tile == WorldMap.TILE_GRASS else Color(0.5, 0.4, 0.2))

	if update_flat:
		_flat_mm.instance_count = flat_positions.size()
		for i in flat_positions.size():
			_flat_mm.set_instance_transform(i, Transform3D(Basis(), flat_positions[i]))
			_flat_mm.set_instance_color(i, flat_colors[i])

	if update_walls:
		_wall_mm.instance_count = wall_positions.size()
		for i in wall_positions.size():
			var basis := Basis().scaled(Vector3(1.0, wall_scale_ys[i], 1.0))
			_wall_mm.set_instance_transform(i, Transform3D(basis, wall_positions[i]))

# --- Visual update and map management ---

func _rebuild_visuals() -> void:
	_rebuild_tile_multimeshes()
	_refresh_entity_markers()

func _refresh_entity_markers() -> void:
	for c in _entity_markers.get_children():
		c.queue_free()
	_add_entity_markers()

func _add_entity_markers() -> void:
	for e in _world_map.enemies:
		_entity_markers.add_child(_make_marker(_mat_enemy, Vector3(e["x"], 0.5, e["z"])))
	for c in _world_map.chests:
		_entity_markers.add_child(_make_marker(_mat_chest, Vector3(c["x"], 0.3, c["z"])))
	for d in _world_map.doors:
		_entity_markers.add_child(_make_marker(_mat_door, Vector3(d["x"], 0.5, d["z"])))
	if _world_map.has_player_spawn():
		var sx := _world_map.player_spawn_x * IsoConst.TILE_SIZE + IsoConst.TILE_SIZE * 0.5
		var sz := _world_map.player_spawn_z * IsoConst.TILE_SIZE + IsoConst.TILE_SIZE * 0.5
		_entity_markers.add_child(_make_marker(_mat_spawn, Vector3(sx, 0.5, sz)))

func _make_marker(mat: StandardMaterial3D, pos: Vector3) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = _marker_mesh
	mi.material_override = mat
	mi.position = pos
	return mi

# --- Mobile toolbar ---

func _make_style(color: Color, border: bool) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = color
	s.set_corner_radius_all(8)
	s.content_margin_top = 6.0
	s.content_margin_bottom = 6.0
	s.content_margin_left = 4.0
	s.content_margin_right = 4.0
	if border:
		s.border_width_top = 3
		s.border_width_bottom = 3
		s.border_width_left = 3
		s.border_width_right = 3
		s.border_color = Color.WHITE
	return s

func _build_mobile_toolbar() -> void:
	_toolbar = PanelContainer.new()
	_toolbar.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_toolbar.grow_vertical = Control.GROW_DIRECTION_BEGIN

	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.1, 0.1, 0.1, 0.88)
	_toolbar.add_theme_stylebox_override("panel", panel_style)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	_toolbar.add_child(vbox)

	var mode_names: Array[String] = ["Grass", "Wall", "Hill", "Enemy", "Chest", "Door", "Spawn", "Erase"]

	var mode_row := HBoxContainer.new()
	mode_row.add_theme_constant_override("separation", 5)
	vbox.add_child(mode_row)

	var vh: float = get_viewport().get_visible_rect().size.y
	var btn_h: float  = vh * 0.06
	var sq_w: float   = vh * 0.07
	var wide_w: float = vh * 0.09
	var lbl_w: float  = vh * 0.045


	for i in mode_names.size():
		var col: Color = _mode_colors[i]
		var normal_style := _make_style(col.darkened(0.45), false)
		var active_style := _make_style(col.lightened(0.15), true)
		_btn_normal_styles.append(normal_style)
		_btn_active_styles.append(active_style)

		var btn := Button.new()
		btn.text = mode_names[i]
		btn.custom_minimum_size = Vector2(wide_w, btn_h)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.add_theme_stylebox_override("normal", normal_style)
		btn.add_theme_stylebox_override("hover", _make_style(col, false))
		btn.add_theme_stylebox_override("pressed", active_style)
		btn.add_theme_color_override("font_color", Color.WHITE)
		btn.add_theme_font_size_override("font_size", 15)
		var idx := i
		btn.pressed.connect(func(): _set_mode(idx))
		_mode_buttons.append(btn)
		mode_row.add_child(btn)

	var ctrl_row := HBoxContainer.new()
	ctrl_row.add_theme_constant_override("separation", 5)
	vbox.add_child(ctrl_row)

	var h_minus := Button.new()
	h_minus.text = "H-"
	h_minus.custom_minimum_size = Vector2(sq_w, btn_h)
	h_minus.pressed.connect(_height_down)
	ctrl_row.add_child(h_minus)

	_height_label = Label.new()
	_height_label.text = "H:1"
	_height_label.custom_minimum_size = Vector2(lbl_w, btn_h)
	_height_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_height_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_height_label.add_theme_color_override("font_color", Color.WHITE)
	_height_label.add_theme_font_size_override("font_size", 18)
	ctrl_row.add_child(_height_label)

	var h_plus := Button.new()
	h_plus.text = "H+"
	h_plus.custom_minimum_size = Vector2(sq_w, btn_h)
	h_plus.pressed.connect(_height_up)
	ctrl_row.add_child(h_plus)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ctrl_row.add_child(spacer)

	var save_btn := Button.new()
	save_btn.text = "Save"
	save_btn.custom_minimum_size = Vector2(wide_w, btn_h)
	save_btn.pressed.connect(_save_map)
	ctrl_row.add_child(save_btn)

	var new_btn := Button.new()
	new_btn.text = "New"
	new_btn.custom_minimum_size = Vector2(wide_w, btn_h)
	new_btn.pressed.connect(_new_map_dialog)
	ctrl_row.add_child(new_btn)

	var open_btn := Button.new()
	open_btn.text = "Open"
	open_btn.custom_minimum_size = Vector2(wide_w, btn_h)
	open_btn.pressed.connect(_show_map_list)
	ctrl_row.add_child(open_btn)

	_hud.add_child(_toolbar)
	_refresh_mode_buttons()

func _set_mode(mode: int) -> void:
	_paint_mode = mode
	_refresh_mode_buttons()
	_update_hud()

func _refresh_mode_buttons() -> void:
	for i in _mode_buttons.size():
		_mode_buttons[i].add_theme_stylebox_override(
			"normal",
			_btn_active_styles[i] if i == _paint_mode else _btn_normal_styles[i]
		)

func _height_up() -> void:
	_paint_height = min(_paint_height + 1, 4)
	_height_label.text = "H:%d" % _paint_height
	_update_hud()

func _height_down() -> void:
	_paint_height = max(_paint_height - 1, 1)
	_height_label.text = "H:%d" % _paint_height
	_update_hud()

func _load_map(name: String) -> void:
	_current_map_name = name
	_world_map = WorldMap.new(name)
	_rebuild_visuals()
	_update_hud()

func _update_hud() -> void:
	_map_name_label.text = "Map: %s" % _current_map_name
	var modes := ["Grass", "Wall", "Hill", "Enemy", "Chest", "Door", "Spawn", "Erase"]
	_mode_label.text = "Mode: %s  H:%d" % [modes[_paint_mode], _paint_height]

# --- Input ---

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_1: _set_mode(0)
			KEY_2: _set_mode(1)
			KEY_3: _set_mode(2)
			KEY_4: _set_mode(3)
			KEY_5: _set_mode(4)
			KEY_6: _set_mode(5)
			KEY_7: _set_mode(6)
			KEY_8: _set_mode(7)
			KEY_BRACKETRIGHT: _height_up()
			KEY_BRACKETLEFT: _height_down()
			KEY_S when event.ctrl_pressed: _save_map()
			KEY_N when event.ctrl_pressed: _new_map_dialog()
			KEY_O when event.ctrl_pressed: _show_map_list()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		var tile := _screen_to_tile(event.position)
		if tile.x >= 0:
			if event.button_index == MOUSE_BUTTON_LEFT:
				_last_painted_tile = Vector2i(-1, -1)
				_paint_tile(tile.x, tile.y)
			elif event.button_index == MOUSE_BUTTON_RIGHT:
				_erase_tile(tile.x, tile.y)

	if event is InputEventMouseMotion:
		var tile := _screen_to_tile(event.position)
		if tile.x >= 0:
			_move_highlight(tile.x, tile.y)

	if event is InputEventScreenTouch:
		if event.pressed:
			_last_painted_tile = Vector2i(-1, -1)
			var tile := _screen_to_tile(event.position)
			if tile.x >= 0:
				_paint_tile(tile.x, tile.y)
		else:
			_last_painted_tile = Vector2i(-1, -1)

	if event is InputEventScreenDrag:
		var tile := _screen_to_tile(event.position)
		if tile.x >= 0:
			_move_highlight(tile.x, tile.y)
			if tile != _last_painted_tile:
				_paint_tile(tile.x, tile.y)

func _move_highlight(tx: int, tz: int) -> void:
	_highlight_mesh.position = Vector3(
		tx * IsoConst.TILE_SIZE + IsoConst.TILE_SIZE * 0.5,
		0.05,
		tz * IsoConst.TILE_SIZE + IsoConst.TILE_SIZE * 0.5
	)

func _screen_to_tile(screen_pos: Vector2) -> Vector2i:
	var from := _camera.project_ray_origin(screen_pos)
	var dir := _camera.project_ray_normal(screen_pos)
	if abs(dir.y) < 0.001:
		return Vector2i(-1, -1)
	var t := -from.y / dir.y
	var hit := from + dir * t
	var tx := int(hit.x / IsoConst.TILE_SIZE)
	var tz := int(hit.z / IsoConst.TILE_SIZE)
	if tx < 0 or tx >= WorldMap.MAP_WIDTH or tz < 0 or tz >= WorldMap.MAP_HEIGHT:
		return Vector2i(-1, -1)
	return Vector2i(tx, tz)

# --- Painting ---

func _paint_tile(tx: int, tz: int) -> void:
	_last_painted_tile = Vector2i(tx, tz)
	match _paint_mode:
		0:  # Grass — only flat tiles change; walls change only if this tile was a wall
			var was_wall := _world_map.get_tile(tx, tz) == WorldMap.TILE_WALL
			_world_map.set_tile(tx, tz, WorldMap.TILE_GRASS)
			_world_map.set_height(tx, tz, 0)
			_rebuild_tile_multimeshes(true, was_wall)
		1:  # Wall — only walls change; flat changes only if this tile was flat
			var was_flat := _world_map.get_tile(tx, tz) != WorldMap.TILE_WALL
			_world_map.set_tile(tx, tz, WorldMap.TILE_WALL)
			_world_map.set_height(tx, tz, _paint_height)
			_rebuild_tile_multimeshes(was_flat, true)
		2:  # Hill — only flat tiles change; walls change only if this tile was a wall
			var was_wall := _world_map.get_tile(tx, tz) == WorldMap.TILE_WALL
			_world_map.set_tile(tx, tz, WorldMap.TILE_HILL)
			_world_map.set_height(tx, tz, _paint_height)
			_rebuild_tile_multimeshes(true, was_wall)
		3:  # Enemy — no tile geometry change
			var wx := tx * IsoConst.TILE_SIZE + IsoConst.TILE_SIZE * 0.5
			var wz := tz * IsoConst.TILE_SIZE + IsoConst.TILE_SIZE * 0.5
			_world_map.enemies.append({"id": "enemy_%d" % Time.get_ticks_msec(), "x": wx, "z": wz, "alive": true, "tracking": true})
			_refresh_entity_markers()
		4:  # Chest — no tile geometry change
			var wx := tx * IsoConst.TILE_SIZE + IsoConst.TILE_SIZE * 0.5
			var wz := tz * IsoConst.TILE_SIZE + IsoConst.TILE_SIZE * 0.5
			_world_map.chests.append({"id": "chest_%d" % Time.get_ticks_msec(), "x": wx, "z": wz, "card_ids": ["ghost"], "opened": false})
			_refresh_entity_markers()
		5:  # Door — no tile geometry change
			var wx := tx * IsoConst.TILE_SIZE + IsoConst.TILE_SIZE * 0.5
			var wz := tz * IsoConst.TILE_SIZE + IsoConst.TILE_SIZE * 0.5
			_world_map.doors.append({"id": "door_%d" % Time.get_ticks_msec(), "x": wx, "z": wz, "target_map": "", "target_door_id": ""})
			_refresh_entity_markers()
		6:  # Spawn — no tile geometry change
			_world_map.player_spawn_x = tx
			_world_map.player_spawn_z = tz
			_refresh_entity_markers()
		7:  # Erase
			_erase_tile(tx, tz)

func _erase_tile(tx: int, tz: int) -> void:
	var was_wall := _world_map.get_tile(tx, tz) == WorldMap.TILE_WALL
	_world_map.set_tile(tx, tz, WorldMap.TILE_GRASS)
	_world_map.set_height(tx, tz, 0)
	var wx := tx * IsoConst.TILE_SIZE + IsoConst.TILE_SIZE * 0.5
	var wz := tz * IsoConst.TILE_SIZE + IsoConst.TILE_SIZE * 0.5
	_world_map.enemies = _world_map.enemies.filter(func(e): return abs(e["x"]-wx)>0.5 or abs(e["z"]-wz)>0.5)
	_world_map.chests = _world_map.chests.filter(func(c): return abs(c["x"]-wx)>0.5 or abs(c["z"]-wz)>0.5)
	_world_map.doors = _world_map.doors.filter(func(d): return abs(d["x"]-wx)>0.5 or abs(d["z"]-wz)>0.5)
	_rebuild_tile_multimeshes(true, was_wall)
	_refresh_entity_markers()

# --- Map management ---

func _save_map() -> void:
	_world_map.save_to_file(_current_map_name)
	print("Saved: user://maps/%s.tres" % _current_map_name)

func _new_map_dialog() -> void:
	var dialog := AcceptDialog.new()
	dialog.title = "New Map"
	var edit := LineEdit.new()
	edit.placeholder_text = "Map name"
	dialog.add_child(edit)
	add_child(dialog)
	dialog.popup_centered()
	dialog.confirmed.connect(func():
		var name := edit.text.strip_edges()
		if not name.is_empty():
			_current_map_name = name
			# p_skip_load=true: create blank slate without MapRegistry lookup.
			# Then populate with the default layout (walls, enemies, chests).
			_world_map = WorldMap.new(name, true)
			_world_map._build_default_map()
			_rebuild_visuals()
			_update_hud()
		dialog.queue_free()
	)

func _show_map_list() -> void:
	var names := WorldMap.list_map_names()
	var dialog := AcceptDialog.new()
	dialog.title = "Load Map"
	var vbox := VBoxContainer.new()
	for n in names:
		var btn := Button.new()
		btn.text = n
		btn.pressed.connect(func():
			_load_map(n)
			dialog.queue_free()
		)
		vbox.add_child(btn)
	dialog.add_child(vbox)
	add_child(dialog)
	dialog.popup_centered_ratio(0.3)
