## Tap / click to move (see docs/agent/tap-to-move.md): turns a tap, click or
## drag into an A* path for the player, draws the pulsing destination ring and
## the red "can't go there" flash, and auto-interacts on arrival when the tap
## was aimed at something interactable (TID-461).
##
## WorldScene forwards pointer events here from _unhandled_input and ticks
## `tick()` every frame. The joystick reference is set by _build_player_hud.
extends Node

const Pathfinder = preload("res://game_logic/Pathfinder.gd")

const DRAG_THRESHOLD: float = 30.0   # screen pixels; beyond this is a drag, not a tap
const MAX_PATH_NODES: int = 64
const _NO_TOUCH: int = -2            # no tracked tap (-1 is reserved for mouse)
const _NO_TILE := Vector2i(-9999, -9999)
const _MARKER_Y: float = 0.08        # just above the tile surface
const _DEST_TINT := Color(0.25, 1.0, 0.55)
const _REJECT_TINT := Color(1.0, 0.25, 0.2)
const _WALKABLE: Array[int] = [IsoConst.TILE_GRASS, IsoConst.TILE_HILL, IsoConst.TILE_PATH]

var joystick: Node = null
var _world: Node = null

var _dest_marker: Node3D = null
var _dest_tween: Tween = null
## Set when a tap resolves near an interactable; consumed by on_path_arrived().
var _pending_interact: bool = false
var _tap_start_screen: Vector2 = Vector2.ZERO
var _tap_touch_index: int = _NO_TOUCH
var _drag_last_tile: Vector2i = _NO_TILE    # throttles drag-steer re-pathing

## Handles a pointer event. Returns true when it consumed the event.
func handle_input(event: InputEvent) -> bool:
	if event is InputEventScreenTouch:
		return _on_screen_touch(event as InputEventScreenTouch)
	if event is InputEventScreenDrag:
		_on_screen_drag(event as InputEventScreenDrag)
	elif event is InputEventMouseButton:
		var mb: InputEventMouseButton = event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
			_drag_last_tile = _NO_TILE
			handle_tap(mb.position)
			return true
	elif event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		return _steer_to((event as InputEventMouseMotion).position)
	return false

func _on_screen_touch(touch: InputEventScreenTouch) -> bool:
	if touch.pressed:
		_on_touch_down(touch)
		return false
	return _on_touch_up(touch)

## Starts tracking a finger — unless one is already tracked, or the touch is on
## the virtual joystick or a visible HUD button (those aren't moves).
func _on_touch_down(touch: InputEventScreenTouch) -> void:
	if _tap_touch_index != _NO_TOUCH or _on_joystick(touch.position):
		return
	if _world._world_hud != null and _world._world_hud.is_touch_on_hud_button(touch.position):
		return
	_tap_start_screen = touch.position
	_tap_touch_index = touch.index
	_drag_last_tile = _NO_TILE

## A tracked finger lifting without having dragged is a tap.
func _on_touch_up(touch: InputEventScreenTouch) -> bool:
	if touch.index != _tap_touch_index:
		return false
	_tap_touch_index = _NO_TOUCH
	if touch.position.distance_to(_tap_start_screen) >= DRAG_THRESHOLD:
		return false
	handle_tap(touch.position)
	return true

func _on_screen_drag(drag: InputEventScreenDrag) -> void:
	if drag.index != _tap_touch_index:
		return
	# A drag that wanders onto the joystick belongs to the joystick.
	if _on_joystick(drag.position):
		_tap_touch_index = _NO_TOUCH
		return
	# Past the threshold, steer the move target continuously.
	if drag.position.distance_to(_tap_start_screen) >= DRAG_THRESHOLD:
		_steer_to(drag.position)

## Re-paths toward `screen_pos` only when it lands on a new tile.
func _steer_to(screen_pos: Vector2) -> bool:
	if _world._camera == null:
		return false
	var tile: Vector2i = screen_to_tile(screen_pos)
	if tile == _drag_last_tile:
		return false
	_drag_last_tile = tile
	handle_tap(screen_pos)
	return true

func _on_joystick(pos: Vector2) -> bool:
	return joystick != null and joystick.has_method("is_touch_in_control_area") \
		and joystick.call("is_touch_in_control_area", pos)

## Paths the player to the tile under `screen_pos`, or flashes a reject marker.
func handle_tap(screen_pos: Vector2) -> void:
	var player: CharacterBody3D = _world._player
	if player == null or _world._camera == null:
		return
	# GID-101 (TID-365): ping mode intercepts taps and creates a world-space ping.
	if _world._ping_mode_active and _world._coop_active:
		_world.coop_social._handle_ping_tap(screen_pos)
		return
	var tile: Vector2i = screen_to_tile(screen_pos)
	if not _WALKABLE.has(_world.get_tile_global(tile.x, tile.y)):
		_reject(tile, "Can't go there")
		return
	var player_tile: Vector2i = IsoConst.world_to_tile(player.position.x, player.position.z)
	var path: Array[Vector2i] = Pathfinder.find_path(
		Callable(_world, "get_tile_global"), player_tile, tile, MAX_PATH_NODES)
	if path.is_empty():
		_reject(tile, "Can't reach that tile")
		return
	# TID-461: a tap aimed at an interactable auto-interacts on natural arrival.
	var centre: Vector3 = _tile_centre(tile)
	_pending_interact = _world._interact_prompt_label(centre.x, centre.z) != ""
	_place_dest_marker(centre)
	if player.has_method("set_destination_path"):
		player.call("set_destination_path", path)

func _reject(tile: Vector2i, tip: String) -> void:
	_world._show_tip(tip)
	_show_reject_marker(_tile_centre(tile))

## Connected to Player.path_arrived (TID-461). Fires the normal interact
## dispatch once, as if E/USE were pressed on arrival — only when the tap was
## aimed at an interactable and nothing (overlay, downed state) blocks it.
func on_path_arrived() -> void:
	var should_interact: bool = _pending_interact and not _world._coop_downed \
		and not SceneManager.has_open_overlay()
	_pending_interact = false
	if should_interact:
		_world._handle_interact()

## Per frame: hide the destination ring once the player's path is done.
func tick() -> void:
	if _dest_marker == null or not _dest_marker.visible:
		return
	var player: CharacterBody3D = _world._player
	if player != null and player.has_method("cancel_path") and not player.get("_has_active_path"):
		_stop_dest_pulse()
		_dest_marker.hide()

## Cancels any walk in progress and hides the ring (menus, battles, map view).
func clear() -> void:
	_stop_dest_pulse()
	if is_instance_valid(_dest_marker):
		_dest_marker.hide()
	var player: CharacterBody3D = _world._player
	if player != null and player.has_method("cancel_path"):
		player.call("cancel_path")
	_pending_interact = false

## The tile under a screen position, by analytic ray–plane intersection with
## the y=0 tile plane.
func screen_to_tile(screen_pos: Vector2) -> Vector2i:
	var cam: Camera3D = _world._camera
	var ray_origin: Vector3 = cam.project_ray_origin(screen_pos)
	var ray_dir: Vector3 = cam.project_ray_normal(screen_pos)
	if absf(ray_dir.y) < 0.0001:
		return IsoConst.world_to_tile(_world._player.position.x, _world._player.position.z)
	var hit: Vector3 = ray_origin + (-ray_origin.y / ray_dir.y) * ray_dir
	return IsoConst.world_to_tile(hit.x, hit.z)

static func _tile_centre(tile: Vector2i) -> Vector3:
	return Vector3((float(tile.x) + 0.5) * IsoConst.TILE_SIZE, _MARKER_Y,
		(float(tile.y) + 0.5) * IsoConst.TILE_SIZE)

func _place_dest_marker(pos: Vector3) -> void:
	if not is_instance_valid(_dest_marker):
		_dest_marker = _make_marker("DestMarker", _DEST_TINT)
		_world.add_child(_dest_marker)
	_dest_marker.position = pos
	_dest_marker.show()
	_stop_dest_pulse()
	_dest_tween = _world.create_tween().set_loops()
	_dest_tween.tween_property(_dest_marker, "scale", Vector3(1.2, 1.0, 1.2), 0.45).set_trans(Tween.TRANS_SINE)
	_dest_tween.tween_property(_dest_marker, "scale", Vector3(0.85, 1.0, 0.85), 0.45).set_trans(Tween.TRANS_SINE)

func _stop_dest_pulse() -> void:
	if _dest_tween != null and _dest_tween.is_valid():
		_dest_tween.kill()
	_dest_tween = null

## TID-462: brief red flash at a tapped tile that resolved to a wall or an
## unreachable destination. Independent of the destination ring, so a rejected
## tap never cancels a path in progress. Node3D has no modulate, so the fade
## runs on the material's albedo alpha.
func _show_reject_marker(pos: Vector3) -> void:
	var marker: Node3D = _make_marker("RejectMarker", _REJECT_TINT)
	marker.position = pos
	_world.add_child(marker)
	var mat: StandardMaterial3D = (marker.get_child(0) as MeshInstance3D).material_override
	var tw: Tween = marker.create_tween()
	tw.set_parallel(true)
	tw.tween_property(marker, "scale", Vector3(1.4, 1.0, 1.4), 0.4).set_trans(Tween.TRANS_SINE)
	tw.tween_property(mat, "albedo_color:a", 0.0, 0.4).set_trans(Tween.TRANS_SINE)
	tw.set_parallel(false)
	tw.tween_callback(marker.queue_free)

## The glowing ring dropped on a tapped tile. The material is built per call on
## purpose: the reject flash fades its alpha, and a shared material would fade
## every marker on screen.
static func _make_marker(node_name: String, tint: Color) -> Node3D:
	var root := Node3D.new()
	root.name = node_name
	var torus := TorusMesh.new()
	torus.inner_radius = 0.50
	torus.outer_radius = 0.72
	torus.rings = 12
	torus.ring_segments = 16
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(tint.r, tint.g, tint.b, 0.90)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.emission_enabled = true
	mat.emission = tint
	mat.emission_energy_multiplier = 1.8
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	var mesh_inst := MeshInstance3D.new()
	mesh_inst.mesh = torus
	mesh_inst.material_override = mat
	root.add_child(mesh_inst)
	return root
