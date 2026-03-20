extends Node3D

const WorldMap = preload("res://game_logic/world/WorldMap.gd")

var _world_map: WorldMap
var _current_map_name: String = "main"
var _paint_mode: int = 0  # 0=grass, 1=wall, 2=hill, 3=enemy, 4=chest, 5=door, 6=spawn, 7=erase
var _paint_height: int = 1

@onready var _camera: Camera3D = $Camera3D
@onready var _hud: CanvasLayer = $HUD
@onready var _mode_label: Label = $HUD/ModeLabel
@onready var _map_name_label: Label = $HUD/MapNameLabel

var _tile_meshes: Node3D
var _entity_markers: Node3D
var _highlight_mesh: MeshInstance3D

func _ready() -> void:
	_tile_meshes = Node3D.new()
	add_child(_tile_meshes)
	_entity_markers = Node3D.new()
	add_child(_entity_markers)

	_create_highlight()
	_load_map(_current_map_name)
	_setup_camera()
	_update_hud()

func _setup_camera() -> void:
	_camera.position = Vector3(50, 80, 80)
	_camera.look_at(Vector3(50, 0, 50), Vector3.UP)

func _create_highlight() -> void:
	_highlight_mesh = MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(IsoConst.TILE_SIZE, IsoConst.TILE_SIZE)
	_highlight_mesh.mesh = plane
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1, 1, 0, 0.4)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_highlight_mesh.material_override = mat
	_highlight_mesh.position.y = 0.05
	add_child(_highlight_mesh)

func _load_map(name: String) -> void:
	_current_map_name = name
	_world_map = WorldMap.new(name)
	_rebuild_visuals()
	_update_hud()

func _rebuild_visuals() -> void:
	for c in _tile_meshes.get_children():
		c.queue_free()
	for c in _entity_markers.get_children():
		c.queue_free()

	var grass_mat := StandardMaterial3D.new()
	grass_mat.albedo_color = Color(0.3, 0.6, 0.2)
	var wall_mat := StandardMaterial3D.new()
	wall_mat.albedo_color = Color(0.5, 0.4, 0.35)
	var hill_mat := StandardMaterial3D.new()
	hill_mat.albedo_color = Color(0.5, 0.4, 0.2)

	for tz in range(WorldMap.MAP_HEIGHT):
		for tx in range(WorldMap.MAP_WIDTH):
			var tile := _world_map.get_tile(tx, tz)
			var mi := MeshInstance3D.new()
			var mesh: Mesh
			if tile == WorldMap.TILE_WALL:
				var h := _world_map.get_height(tx, tz)
				var box := BoxMesh.new()
				box.size = Vector3(IsoConst.TILE_SIZE * 0.95, h * 0.625, IsoConst.TILE_SIZE * 0.95)
				mesh = box
				mi.material_override = wall_mat
				mi.position = Vector3(
					tx * IsoConst.TILE_SIZE + IsoConst.TILE_SIZE * 0.5,
					h * 0.625 * 0.5,
					tz * IsoConst.TILE_SIZE + IsoConst.TILE_SIZE * 0.5
				)
			else:
				var plane := PlaneMesh.new()
				plane.size = Vector2(IsoConst.TILE_SIZE * 0.95, IsoConst.TILE_SIZE * 0.95)
				mesh = plane
				mi.material_override = hill_mat if tile == WorldMap.TILE_HILL else grass_mat
				mi.position = Vector3(
					tx * IsoConst.TILE_SIZE + IsoConst.TILE_SIZE * 0.5,
					0.01,
					tz * IsoConst.TILE_SIZE + IsoConst.TILE_SIZE * 0.5
				)
			mi.mesh = mesh
			_tile_meshes.add_child(mi)

	# Entity markers
	_add_entity_markers()

func _add_entity_markers() -> void:
	for e in _world_map.enemies:
		var m := _make_marker(Color.RED, Vector3(e["x"], 0.5, e["z"]))
		_entity_markers.add_child(m)
	for c in _world_map.chests:
		var m := _make_marker(Color(1, 0.8, 0), Vector3(c["x"], 0.3, c["z"]))
		_entity_markers.add_child(m)
	for d in _world_map.doors:
		var m := _make_marker(Color(0.5, 0.3, 0.1), Vector3(d["x"], 0.5, d["z"]))
		_entity_markers.add_child(m)
	if _world_map.has_player_spawn():
		var sx := _world_map.player_spawn_x * IsoConst.TILE_SIZE + IsoConst.TILE_SIZE * 0.5
		var sz := _world_map.player_spawn_z * IsoConst.TILE_SIZE + IsoConst.TILE_SIZE * 0.5
		var m := _make_marker(Color.CYAN, Vector3(sx, 0.5, sz))
		_entity_markers.add_child(m)

func _make_marker(color: Color, pos: Vector3) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.3
	mi.mesh = sphere
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mi.material_override = mat
	mi.position = pos
	return mi

func _update_hud() -> void:
	_map_name_label.text = "Map: %s" % _current_map_name
	var modes := ["Grass", "Wall", "Hill", "Enemy", "Chest", "Door", "Spawn", "Erase"]
	_mode_label.text = "Mode: %s  H:%d" % [modes[_paint_mode], _paint_height]

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_1: _paint_mode = 0
			KEY_2: _paint_mode = 1
			KEY_3: _paint_mode = 2
			KEY_4: _paint_mode = 3
			KEY_5: _paint_mode = 4
			KEY_6: _paint_mode = 5
			KEY_7: _paint_mode = 6
			KEY_8: _paint_mode = 7
			KEY_BRACKETRIGHT: _paint_height = min(_paint_height + 1, 4)
			KEY_BRACKETLEFT: _paint_height = max(_paint_height - 1, 1)
			KEY_S when event.ctrl_pressed: _save_map()
			KEY_N when event.ctrl_pressed: _new_map_dialog()
			KEY_O when event.ctrl_pressed: _show_map_list()
		_update_hud()

	if event is InputEventMouseButton and event.pressed:
		var tile := _screen_to_tile(event.position)
		if tile.x >= 0:
			if event.button_index == MOUSE_BUTTON_LEFT:
				_paint_tile(tile.x, tile.y)
			elif event.button_index == MOUSE_BUTTON_RIGHT:
				_erase_tile(tile.x, tile.y)

	if event is InputEventMouseMotion:
		var tile := _screen_to_tile(event.position)
		if tile.x >= 0:
			_highlight_mesh.position = Vector3(
				tile.x * IsoConst.TILE_SIZE + IsoConst.TILE_SIZE * 0.5,
				0.05,
				tile.y * IsoConst.TILE_SIZE + IsoConst.TILE_SIZE * 0.5
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

func _paint_tile(tx: int, tz: int) -> void:
	match _paint_mode:
		0:  # Grass
			_world_map.set_tile(tx, tz, WorldMap.TILE_GRASS)
			_world_map.set_height(tx, tz, 0)
		1:  # Wall
			_world_map.set_tile(tx, tz, WorldMap.TILE_WALL)
			_world_map.set_height(tx, tz, _paint_height)
		2:  # Hill
			_world_map.set_tile(tx, tz, WorldMap.TILE_HILL)
			_world_map.set_height(tx, tz, _paint_height)
		3:  # Enemy
			var wx := tx * IsoConst.TILE_SIZE + IsoConst.TILE_SIZE * 0.5
			var wz := tz * IsoConst.TILE_SIZE + IsoConst.TILE_SIZE * 0.5
			_world_map.enemies.append({
				"id": "enemy_%d" % Time.get_ticks_msec(),
				"x": wx, "z": wz, "alive": true, "tracking": true
			})
		4:  # Chest
			var wx := tx * IsoConst.TILE_SIZE + IsoConst.TILE_SIZE * 0.5
			var wz := tz * IsoConst.TILE_SIZE + IsoConst.TILE_SIZE * 0.5
			_world_map.chests.append({
				"id": "chest_%d" % Time.get_ticks_msec(),
				"x": wx, "z": wz, "card_ids": ["ghost"], "opened": false
			})
		5:  # Door
			var wx := tx * IsoConst.TILE_SIZE + IsoConst.TILE_SIZE * 0.5
			var wz := tz * IsoConst.TILE_SIZE + IsoConst.TILE_SIZE * 0.5
			_world_map.doors.append({
				"id": "door_%d" % Time.get_ticks_msec(),
				"x": wx, "z": wz, "target_map": "", "target_door_id": ""
			})
		6:  # Spawn
			_world_map.player_spawn_x = tx
			_world_map.player_spawn_z = tz
		7:  # Erase
			_erase_tile(tx, tz)
	_rebuild_visuals()

func _erase_tile(tx: int, tz: int) -> void:
	_world_map.set_tile(tx, tz, WorldMap.TILE_GRASS)
	_world_map.set_height(tx, tz, 0)
	var wx := tx * IsoConst.TILE_SIZE + IsoConst.TILE_SIZE * 0.5
	var wz := tz * IsoConst.TILE_SIZE + IsoConst.TILE_SIZE * 0.5
	_world_map.enemies = _world_map.enemies.filter(func(e): return abs(e["x"]-wx)>0.5 or abs(e["z"]-wz)>0.5)
	_world_map.chests = _world_map.chests.filter(func(c): return abs(c["x"]-wx)>0.5 or abs(c["z"]-wz)>0.5)
	_world_map.doors = _world_map.doors.filter(func(d): return abs(d["x"]-wx)>0.5 or abs(d["z"]-wz)>0.5)
	_rebuild_visuals()

func _save_map() -> void:
	var path := "user://maps/%s.txt" % _current_map_name
	_world_map.save_to_file(path)
	print("Saved: %s" % path)

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
			_world_map = WorldMap.new(name)
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
